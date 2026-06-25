---
name: build-oracle-loop
description: 승인된 plan을 구현할 때, layer 다이어그램에서 work-unit을 도출해 (foundation 먼저, 독립분만 병렬) 서브에이전트로 구현하고 각 unit을 오라클(test/type/build) green이 될 때까지 repair한 뒤, plan 일치 + 옳은 이유로 green인지 adversarial conformance 게이트로 검증한다. "이 plan 구현해줘 / 만들어줘 / build" 류 요청에 사용. Workflow 도구 없이 Agent 도구로 동작.
---

# build-oracle-loop

build은 plan·review와 **다르다 — 오라클이 셋 중 최대**다. 코드를 짜는 즉시 test/type/build를 그 산출물에 돌릴 수 있다. 그래서 build은 *심의(deliberation)* 문제가 아니라 **generate → verify → repair** 문제다. (배경: `GOAL.md` 원칙 1)

## 절대 규칙
- **plan의 lens-friction을 build에 얹지 마라.** 코드는 오라클이 판정한다. 마찰은 *plan*이 아니라 *구현*에 대해서만 건다(conformance 게이트 / judge-panel). plan에 대한 lens-fan-out을 여기서 반복하면 오라클이 제일 센 단계에서 오라클-비대칭 실수를 되풀이하는 것이다.
- **오라클이 엔진.** 서브에이전트가 "다 됐다"고 말하는 건 증거가 아니다 — Bash 실행 출력이 증거다.
- **green ≠ 완료.** conformance 게이트(plan 일치 + 옳은 이유로 green)를 통과해야 unit이 done이다.

## 입력
- **plan**: `.cidd/plans/<slug>.md`(plan-stage 산출물). 없으면 사용자 plan. **다이어그램이 있으면 그게 분해도**다.
- **repo**: 대상 코드베이스(필수 — 오라클 실행·worktree). git이면 worktree 격리, 아니면 순차 진행.

## 단계 상태 (lifecycle 척추)
**진입 시** 대상 repo의 `.cidd/state.md`에서 `plan: done`인 active slug와 plan 경로를 읽어 입력으로 쓴다(스키마는 README "단계 상태"). **전이 가드**: `plan: done`이 없으면 build을 시작하지 말고 plan 단계 먼저(사용자에게 알림) — 메인 LLM이 plan 없이 자유 구현하지 않는다. **완료 시** 갱신: `build: done → .cidd/builds/<slug>.md`(diff ref 포함), `stage: review`, `handoff.build→review`(adequacy 미측정 unit · conformance 우려 = review가 집중할 곳). **끝나면 `AskUserQuestion` 결정 메뉴(accept/refine/back/pause/abandon)로 고른 전이를 자동 적용**(README "단계 끝 = 결정 메뉴"); accept해도 review 실행은 별개 go. (`updated`는 세션이 박음.)

## 상태
- `units` = 도출한 work-unit + 의존(foundation / 독립 / 통합)
- `done` = conformance 게이트까지 통과한 unit
- `oracleCmd` = 탐지한 test/type/lint/build 명령
- 안전 상한: unit당 repair 최대 3회, 전체 unit 수 캡

## 절차

### 0. 오라클 탐지 + work-unit 도출
- repo에서 오라클 명령을 찾는다(`package.json` scripts / `pubspec.yaml` / `Makefile` / `pyproject` 등). **없으면** "⚠️ 오라클 미배선 — build이 verify를 못 함, '검증 안 된 코드 생성'일 뿐"을 맨 위에 박고 사용자 확인 후에만 진행.
- plan(다이어그램 우선)에서 work-unit을 도출한다. ⚠️ **layer hop ≠ 독립 unit.** layer를 가로지르는 흐름은 공유 타입·스키마·계약·공유 모듈을 거친다. hop마다 무작정 병렬 builder를 띄우면 false-independence → 머지 충돌·통합 붕괴. **이게 build 최대 실패모드다.**
  - **공유 artifact(타입/스키마/인터페이스/계약/공유 유틸) = foundation unit → 먼저 순차.**
  - 그 위에 **파일·타입이 안 겹치는 진짜 독립 unit만 병렬.**
  - 의존 그래프: foundation → 독립 병렬 → 통합.

### 1. Foundation 먼저 (순차)
공유 타입/스키마/계약을 구현하고 오라클(컴파일/type)이 green인지 확인. **여기가 깨지면 하위가 전부 깨지니 멈추고 고친다.** foundation green 전엔 병렬 단계로 가지 마라.

### 2. 병렬 구현 (독립 unit)
독립 unit들을 한 메시지에서 동시 `Agent` 호출(`builder`). **git이면 `isolation: "worktree"`로 각 builder를 격리**(동시 편집 충돌 방지). worktree는 *쓰기 충돌*뿐 아니라 step 3 conformance의 *per-unit scope 귀속*에도 필요하다 — 공유 트리에 병렬 빌드하면 `git status`가 형제 unit의 파일을 본다(실측 run6). **파일이 disjoint해 쓰기 충돌이 없으면 worktree를 생략해도 되지만, 그 경우 conformance는 전역 git status가 아니라 unit의 선언 file-list로 scope를 판정해야 한다**(builder의 `changed_files` 반환을 넘겨라). 각 builder에 넘긴다: unit slice(plan+다이어그램 해당 부분) + repo 경로 + `oracleCmd`. builder는 구현 → 오라클 실행 → green까지 repair(캡 3회, 도달 시 "미green" 보고). 반환: 변경 파일 / 실제 오라클 출력 / scope 이탈 여부.

### 3. unit별 conformance 게이트 (adversarial — CIDD 차별점)
완료된 unit마다 별도 `build-conformance` 스켑틱을 띄운다. 두 축을 *적대적으로* 검증:
- **(a) plan 일치** — 구현이 배정 plan/다이어그램에서 이탈했나? scope 초과(요청 안 한 것 추가) / 누락(plan에 있는데 안 함) / drift(다르게 함).
- **(b) 옳은 이유로 green인가** — 변경 라인 coverage 실행, mutation 도구 있으면 핵심 변경에 돌려 "테스트가 진짜 잡는지" 확인. 없으면 "adequacy 미측정" 명시.
- 스켑틱 디폴트는 회의 — 증거 없으면 PASS 주지 마라. **fail이면 repair로 되돌린다**(builder에 구체 지시).

### 4. 어렵거나 모호한 unit → judge-panel (선택)
접근이 갈리거나 high-stakes인 unit은 `builder`를 N회(서로 다른 접근으로) 띄워 N개 구현 후보를 만들고 `build-judge`로 판정한다. **오라클 통과가 1차 필터(못 통과 = 탈락), 통과한 것들만 품질 lens로 점수.** 이건 *plan*에 대한 lens가 아니라 *구현들*에 대한 토너먼트다.

### 5. 통합
worktree를 머지하고 **전체 오라클**(unit별이 아니라 repo 전체 test/type/build)을 돌린다. 충돌·회귀가 나오면 repair. 전체 green + 모든 unit conformance 통과여야 build 완료.

### 6. review로 handoff
consolidated diff + build 리포트를 만들어 `review-oracle-first`의 입력으로 넘긴다. **build이 통과해도 review는 돈다**(아래 경계 참조).

## 출력 — `.cidd/builds/<slug>.md` + 실제 코드
- 코드 변경은 repo에.
- 리포트(파일): unit별 [무엇 구현 / 오라클 결과 / conformance 판정 / judge 결정] + 전체 오라클 결과 + diff 요약 + 남은 갭. → review 입력.
- 인라인(대화): **layer 다이어그램에 unit별 상태 오버레이**(✅ green+conformance통과 / 🔧 repair중·미green / ⚠️ 오라클 없음) + 리포트 경로.

## build-conformance vs review 경계 (중복 금지)
- **build-conformance**: *mid-build · per-unit · plan 대비* — "계획한 걸 만들었나 + 이 unit의 green이 믿을 만한가"(plan-conformance + local adequacy). **필요조건이지 충분조건 아님.**
- **review-oracle-first**: *post-build · 전체 diff · 정합성·안전·유지보수* — 완성품 판정. build 게이트를 통과해도 review는 별도로 돈다.

## 비용·정직성
- `builder`는 **코드 생성**이라 haiku로는 약하다 → 모델을 기본(세션) 상속(필요시 sonnet). 반면 `build-conformance`·`build-judge`는 **판정**이라 haiku로 충분(오라클이 무거운 일을 한다). repair 캡으로 폭주 방지.
- 제어흐름은 코드가 아니라 네가 따르는 지시다 → **foundation-first, repair 캡, 전체-오라클-통합**을 문자 그대로 지켜라. 독립 판단으로 병렬부터 띄우지 마라.
- 오라클 미배선이면 build 산출물은 "검증 안 된 코드"일 뿐 — 리포트 맨 위에 경고.
