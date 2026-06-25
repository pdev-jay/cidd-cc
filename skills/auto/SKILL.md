---
name: auto
description: 한 목표를 받아 explore→plan→build→review→done을 자동 주행한다. 전진 신호는 *오라클*(build green+conformance, review gate pass) — 오라클 red·진짜 갈림길·첫 코드쓰기 전에만 사람에게 멈춘다. "알아서 해줘 / 끝까지 / 자동으로 진행 / 한 번에 다 / autopilot / end-to-end" 류 요청에. 단계 기계는 각자 그대로 재사용(한 기계로 뭉개지 않음).
---

# auto (오토모드 — opt-in)

한 목표를 받아 lifecycle을 **자율 주행**한다. 차별점: **전진 신호가 자기 평가가 아니라 오라클이다.** (오토모드는 opt-in.)

## 경계 (먼저 — 이거 아닌 경우)
- 사람이 **단계별로 직접 몰고** 있으면 auto 아님 — 해당 스킬(`direction-explore`/`plan-friction-loop`/`build-oracle-loop`/`review-oracle-first`) 직접.
- **목표가 없으면** 추측하지 말고 물어라.
- 순수 질문/조사면 auto 아님.

## 절대 규칙
- **단계 기계를 뭉개지 마라.** 각 단계는 *그 단계의 스킬/기계*를 그대로 쓴다 — explore=발산+judge, plan=lens 마찰, build=gen-verify-repair, review=oracle-first. auto는 이들을 *잇기만* 한다. 한 루프로 동질화하면 오라클 비대칭(원칙 1)을 깨는 것이다.
- **전진 신호 = 오라클/명확 신호.** build은 `oracle-runner` green + 모든 unit conformance 통과여야 다음. review는 gate(하드 오라클 pass + adequacy) pass여야 done. **red면 전진하지 말고 멈춘다.** "에이전트가 됐다고 함"은 신호 아님.
- **오라클 미배선이면 자율 못 한다.** build/review를 검증 없이 자동 통과시키지 마라 — `oracle-runner`가 오라클 없음을 보고하면 멈추고 사람에게 알린다("검증 안 된 코드를 자동 진행할 수 없음").

## 사람에게 멈추는 지점 (여기서만 — 그 외는 자동 전이)
1. **시작 1회**: "explore→…→review까지 자율 진행할까?" 동의를 받는다(`AskUserQuestion`). build이 코드를 쓰므로 이 1회 동의가 "코드쓰기 실행은 별개 go"를 흡수한다. 동의 없으면 단계별 모드로.
2. **진짜 갈림길(DECISION NEEDED)**: explore 승자 불명·judge 갈림 / plan 미해소 high 충돌 / build conformance가 repair 캡 소진 후도 fail / review gate FAIL. → 멈추고 단계-끝 결정 메뉴(accept/refine/back/pause/abandon)를 띄운다.
3. **오라클 red·미배선**(위 절대 규칙).

## 규모 triage (시작 1회 + 번복) — 어느 단계를 얼마나
auto는 전역 오케스트레이터라 *단계 선택*까지 정한다. 시작에 메인(너)이 값싸게 판정(서브에이전트 X) — 요청 + 얕은 repo scan으로 ① 방향 뻔한가(심의) ② 틀리면 위험한가(검증) ③ 관련 테스트 있나(오라클 강도). profile 하나로 압축해 한 줄 명시하고 state.md에 박아 각 단계에 넘긴다(각 단계 재판정 방지):

| profile | 언제 | 단계 선택 | 폭 |
|---|---|---|---|
| **micro** | 기계적·국소(로직 불변 또는 단일 함수, 파일 수 무관)·되돌리기 쉬움·오라클 있음 | explore·plan 생략 → build(편집+오라클)·review(오라클만) | 심의 0 |
| **small** | 작음·방향 거의 정함 | explore 생략, plan 인라인/1렌즈, build 단일, review 오라클+0~1 | 최소 |
| **standard** | 모듈 규모·약간 불확실 | plan 2렌즈 1라운드, build+conformance, review 오라클+2~3 | 중 |
| **high-risk** | 교차절단·방향 포크 OR 오류비용 큼 | 풀: explore(포크면)·loop-until-dry·judge·critic | 최대 |

- ⚠️ **위험 표면이면 규모 작아도 최소 standard로 승격**: auth·permission·schema/persistence·public API·dependency/build config·concurrency·crypto·billing·external I/O·device/BLE/protocol·보안 로깅. (작은 diff ≠ 작은 영향.)
- ⚠️ **오라클 약하면(테스트 부재) 심의 내리지 마라** — micro/small이라도 plan/review **단계를 생략하지 마라**(profile 라벨보다 *단계 유지*가 핵심) 또는 "특성 테스트 먼저". green이 거짓 안심 되는 자리.
- **번복은 state 증거로**: 각 단계 경계의 handoff가 규모 신호다 — `갈린 가정`(explore→plan)·`미해결·검증필요`(plan→build)·`adequacy 미측정·conformance 우려`(build→review). 다음 단계 profile을 *요청이 아니라 이 handoff*로 재도출(올림 자유·내림 보수). 진행 중 실제 영향 드러나면 escalation 점검.
- 분류는 길게 설명 말고 "profile · 이유 1줄 · 유지할 게이트"만.

## 절차
0. **목표 + 상태 확인 + 규모 triage.** 대상 repo `.cidd/state.md`를 읽어 진행 중이면 그 지점부터 재개. `oracle-runner`로 툴체인 탐지(없으면 build/review 자율 불가 경고). **위 규모 triage로 profile을 정해 state.md에 박아 각 단계에 넘긴다.**
1. **시작 동의 1회**(위 1). 범위·멈춤 조건을 한 줄로 알리고 시작.
2. **루프(현재 stage부터)**:
   - 단계 스킬 실행 → 산출물 `.cidd/`에 기록 → state 전이.
   - **평가**: explore/plan = 갈림/미해소 충돌 있나 / build·review = 오라클 신호.
   - green & 명확 → 다음 stage 자동 전이. fork/red → 멈춤(위 2·3).
3. **review gate pass → `stage: done`** + history + 최종 리포트(어떤 단계가 어떻게, 멈춘 적 있으면 왜).

## 상태·캡 (폭주 방지 — 문자 그대로 지켜라)
- 재시도는 각 스킬 내부 캡(builder repair 3 등)에 맡긴다. auto는 **단계당 1회 진행**.
- 같은 단계가 **2회 연속 fork**면 자동 멈춤(사람 필요).
- 전체 라운드 상한을 둔다(무한 explore↔plan 왕복 방지).

## 정직성
- 자율이라도 멈춘 지점·이유를 항상 명시. "다 됐다"는 review gate pass(오라클)로만 말한다 — 자기 선언 금지.
- **인라인은 결과물 우선**(과정 raw는 단계 파일로). 각 단계 기계가 자기 결과물을 그 형태로 내고, auto 자신의 출력(멈춤 메시지·최종 리포트)도 동일 — 멈춤이면 결정 포인트(무엇이 막나 + 선택지), 최종이면 결과물=마지막 단계 산출물 + 거쳐온 단계 한 줄 요약(과정 raw 아님).
- 날짜는 세션이 박는다.
