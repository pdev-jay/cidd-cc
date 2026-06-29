---
name: plan-friction-loop
description: 구현 plan을 여러 lens(서브에이전트)로 병렬 검토하고, lens 간 마찰을 추출해 plan을 수정하기를 마찰이 사라질 때까지 반복한 뒤, 사각지대를 비평한다. "이 plan 집단지성으로 검토/마찰 검토/다각도 검토 후 수정" 류 요청에 사용. Workflow 도구 없이 Agent 도구로 동작.
---

# plan-friction-loop

메인 에이전트(너)가 이 절차를 따라 서브에이전트들을 지휘한다. Workflow 도구를 쓰지 않는다 — `Agent` 도구로 직접 서브에이전트를 띄운다.

## 입력
- **plan**: 검토할 구현 계획 (텍스트 또는 파일 경로). 없으면 사용자에게 받아라.
- **repo (선택)**: 대상 코드베이스 경로. 주어지면 ground-truth 검증이 켜진다 — 서브에이전트 프롬프트에 repo 경로를 넘겨, 가정을 코드로 확인하게 하라.

## 단계 상태 (lifecycle 척추)
이 스킬은 plan 단계다(앞에 `direction-explore`가 올 수 있음). 완료 시 대상 repo의 `.cidd/state.md`에 work item을 등록/갱신한다(스키마는 README "단계 상태"): `active: <slug>`, `target_repo`, `plan: done → .cidd/plans/<slug>.md`, `stage: build`(다음이 *열림* — 강제 아님), `handoff.plan→build`(scope · 미해결/검증필요 항목). 같은 slug 재실행이면 기존 항목 갱신. ⚠️ **plan이 마음에 안 들면**: 재실행(같은 방향 다듬기) / explore로 **back**(방향 자체가 틀렸을 때 — `explorations` 메뉴서 다른 후보) / **abandon**. **끝나면 `AskUserQuestion`으로 결정 메뉴(accept/refine/back/pause/abandon)를 띄우고 고른 전이를 자동 적용한다**(README "단계 끝 = 결정 메뉴") — 강제 전진 아님. ⚠️ **단 `auto`가 구동 중이면 이 끝-메뉴를 생략하고 전이 신호(수렴 done / 미해소 fork)만 반환하라** — auto가 전이를 소유하고 메뉴는 fork·done에서만 띄운다. (`updated` 날짜는 세션이 박는다.)

## 상태
- `plan` = 현재 plan
- `seen` = 지금까지 본 충돌 description 목록 (dedup용)
- `addressed` = 이미 반영한 high-severity finding description 목록 (dedup용)
- `dryRounds` = 연속으로 "새 충돌 0 AND 새 high-severity finding 0" 인 라운드 수
- `history` = 라운드별 충돌/반영 기록
- 안전 상한: 최대 5라운드

## 규모 적응 (먼저 — fan-out 전에)
이 단계는 *심의*다. 작은 작업에 풀 루프(5렌즈×loop-until-dry)는 과하니 폭·라운드를 규모에 맞춘다.
- **규모는 state.md에서 먼저 읽어라(요청 표현보다 우선)**: `handoff.explore→plan`의 `갈린 가정` 수/깊이가 *방향 불확실성*의 grounded 신호다(갈림 많고 깊음 = 심의 더). 요약이 모호하면 explore 산출물(`.cidd/explorations/<slug>.md`)을 읽어 정련 — handoff는 포인터, 산출물이 본문. profile 라벨이 있으면 출발점으로 쓰되 이 증거로 정련. handoff/profile 다 없으면(explore 없이 직접 호출) 자가 판정: ① 방향 뻔한가 ② 틀리면 위험한가 ③ 관련 테스트 있나 — 요청 형용사보다 얕은 repo scan 우선(서브에이전트 X).
- **심의 폭은 *방향 불확실성*으로**(범위 아님): 방향 뻔함 → lens 1·라운드 0(인라인 1문단 plan으로 종료) / 한 가지 합리적 길 → lens 1~2·1라운드 / 진짜 갈림 → 풀 loop-until-dry.
- ⚠️ **오라클 약하면(관련 테스트 부재) 줄이지 마라** — 심의가 유일한 안전망. 차라리 plan에 "특성 테스트 먼저"를 넣어라.
- ⚠️ **오류비용 큰 표면**(auth·schema·결제·동시성·외부 I/O·BLE/프로토콜 등)이면 규모 작아도 관련 lens(security 등) 유지, 최소 standard.
- **번복**: 진행 중 영향이 커지면 폭 올림(내림은 보수적). 고른 profile 한 줄 명시("규모: small — lens 2·1라운드").

## lens 선택 (도출 — 매 run, 나열 아님)
fan-out 전에 라이브러리에서 이 plan에 맞는 lens **3~5개만** 고른다. 축:
1. **task-relevance** — 변경/목표가 *실제로 닿는* 관심사만. `lens-security`는 auth/입력/권한, `lens-cost`는 성능 민감, `lens-operability`는 배포 영향 있을 때만.
2. **diversity (탈상관 — 지배 규칙)** — 서로 저상관인 것만; 겹치면 *지배하는* 쪽만 남기고 드롭. 측정된 지배쌍:
   - `lens-structure` 선택 시 → `lens-scope`는 *미달(요청 핵심 누락, under-scoping)* 위험일 때만 추가. **과설계 쪽은 structure가 담는다**(charter상 '벌지 않은 seam'). [측정 검증됨]
   - 근거: 결함은 다면적이라 한 결함이 여러 lens에 투영된다(disjoint 불가). 라이브러리엔 상관 lens를 *두되* run마다 지배되는 쪽을 드롭 — 일부 겹침은 고-severity corroboration용으로 의도적으로 남긴다.
   - ⚠️ 과거 `lens-feature`(failure가 지배)는 *삭제됨* — 측정 4 task에서 고유 finding 0(completeness→scope, robustness→failure가 다 흡수), feasibility는 lens 아니라 오라클/build 몫. failure가 "무엇이 빠지거나 깨지나"를 포괄.
3. **oracle-subtraction** — 기존 코드/타입으로 *이미 결정적으로* 답나는 건 lens에서 빼라(plan은 오라클 빈곤이라 적게 걸림).

누락은 `completeness-critic`이 가리키면 다음 run에 적응적으로 추가. ⚠️ lens가 *실제로* 새 finding을 내는지 run으로 검증하라 — armchair로 한계 커버리지 단정 금지.

### 라이브러리 (plan)
- **상시 후보**: `lens-structure`, `lens-failure`(데이터/상태-heavy plan의 주력 — run4 확인), `lens-scope`
- **삭제됨**:
  - `lens-flow` (data/control/state) — 측정 2회(auth·sync) 모두 *고유 finding 0*(failure·structure에 흡수). data/control/state는 *비평(critique)* lens가 아니라 *이해(comprehension)* 도구 — 그 가치는 맨 위 layer 다이어그램(메인이 직접 그림)으로 산다. agent 파일 삭제.
  - `lens-feature` (기능 완결성) — 측정 4 task 모두 *고유 finding 0*: completeness는 scope(미달)가, robustness(엣지·에러)는 failure가, feasibility(구현 가능)는 lens 아니라 오라클/build가 담는다. distinct lens 일감이 없음. agent 파일 삭제.
- **task-gated**: `lens-testability`(side-effect·시간·IO·전역·주입 장애물이 *미해결*로 닿을 때 — 장애물 없거나 explore가 선해결하면 고유 finding 0, 미해결일 때만 관측-seam 같은 고유값 [측정 3 task]), `lens-security`(auth/입력), `lens-operability`(배포), `lens-cost`(성능)

## 절차

각 라운드:

1. **Fan-out (병렬).** 위에서 도출한 lens들을 한 메시지에서 동시 `Agent` 호출(각 프롬프트에 현재 `plan` + 있으면 repo 경로). lens 집합은 매 run 달라질 수 있다 — *나열이 아니라 도출*.

2. **두 종류의 작업거리를 뽑는다.**
   - a. **충돌(conflict)** — 두 결과 + `seen`을 `friction-extractor`에게 넘긴다. *새* 충돌만 반환(이미 본 건 제외).
   - b. **high-severity findings** — lens 결과에서 `severity: high`인 finding을 전부 모으고, `addressed`에 이미 있는 것과 실질 동일한 건 제외한다(= 새 high finding). ⚠️ **이게 결함 #3 수정의 핵심**이다: 둘 다 high로 동의한 finding(예: "검증 중앙화")은 *충돌이 아니라서* 예전엔 영영 누락됐다. 이제 충돌과 별개로 반영한다. (합의든 단독이든 high면 대상. medium/low는 자동 반영 안 함 — 과잉설계 방지.)

3. **수렴 판정 (loop-until-dry + dedup).**
   - 새 충돌 0 **AND** 새 high finding 0 이면 → `dryRounds += 1`. `dryRounds >= 2`면 **수렴, 루프 종료.**
   - 둘 중 하나라도 있으면 → `dryRounds = 0`. 새 충돌 description을 `seen`에, 새 high finding description을 `addressed`에 추가.
   - ⚠️ dedup은 **`seen`/`addressed` 기준**(반영했다고 친 것 기준, 해소 확인 기준 아님). 안 그러면 같은 항목이 매 라운드 되살아나 수렴 안 한다.

4. **Revise.** 새 충돌이나 새 high finding이 있으면 `plan-reviser`에게 `plan` + 새 충돌 + 새 high findings를 넘겨 수정본을 받는다. `plan`을 수정본으로 교체하고 `changes`를 `history`에 기록한다.
   - reviser가 "검증 필요"로 표시한 항목은 repo 있으면 Read/Grep으로 확인, 없으면 사용자에게 알려라. **추측으로 닫지 마라.**

5. 5라운드 도달 시 종료하고 "상한 도달 — 미수렴"을 기록한다.

## 수렴 후

6. **Completeness critic.** `completeness-critic`에게 최종 `plan` + 사용한 lens 목록을 넘겨 사각지대를 받는다.

7. **출력 — 결과물과 과정 로그를 분리한다.** "써먹을 plan"(다운스트림 구현용)과 "어떻게 나왔나 기록"(감사·dogfooding)은 소비자가 다르다. 한 파일에 섞지 마라. `<slug>` = plan 제목 기반 또는 사용자 지정, 없으면 `<날짜>-<n>`.

   **다이어그램(필수) = layer 통과 flow.** 결과물(a)과 인라인(c) 둘 다 **맨 위에**, 노드 그래프가 아니라 **핵심 요청/데이터가 계층(layer)을 가로질러 내려가는 경로**를 ASCII로 그려라(네가 직접 — 서브에이전트 아님). origin→consumers 관점. 표기:
   - **왼쪽 축 = layer 라벨**(이 plan에 해당하는 것만): `[Client] [Middleware] [Route] [Service] [Infra/Adapter] [External] [Worker]` 등.
   - flow는 위→아래로 layer를 **가로지르며** 내려간다. 각 화살표에 *무엇이* 넘어가는지 라벨(데이터·호출·상태전이).
   - 분기 `├ … ▼`. **비동기/프로세스 경계**는 가로 구분선(`═══ 프로세스 경계 ═══`)이나 `╎`으로 명시 — 동기 요청 경로와 워커/백그라운드 경로를 한 stack으로 섞지 마라.
   - 흐름이 여러 개면(예: POST·GET) 각각 따로 그린다. state machine이 있으면 작은 전이도 한 블록.
   - plan이 *새로 만들거나 바꾸는* 노드는 `*`. **단 plan이 거의 전부 신규면 `*` 생략**(전부 붙으면 신호 죽음). data/control/state는 *무엇이 흐르나* 라벨로만 — 조직 축은 layer다.
   - ⚠️ data/control/state의 *비평*이 아니라 *이해* 가치가 사는 자리(그래서 lens가 아니라 다이어그램). plan을 충실히 그려라 — layer를 건너뛰거나 빠진 layer(예: Service 부재)는 그림에 *드러나게* 두면 구조 결함이 보인다.
   - 예)
     ```
     [Client]      ──img(multipart)──┐
     [Middleware]  authMiddleware(JWT) ──req.user──┐
     [Route]       POST /uploads* ── 검증 + 직접 오케스트레이션 ──┐
        (※ Service layer 없음 — 권고됐으나 미반영)
     [Infra/Ext]   ├─ S3.put 원본* ─▶ S3*
                   └─ Queue.enqueue 동기3회* ─▶ Redis* ── 성공→202 / 실패→롤백+500
                              ╎ 비동기 handoff: job{id}
     ═══════ 프로세스 경계 ═══════
     [Worker]      Worker* ─consume─▶ sharp 3종 ─▶ S3*/DB.update(멱등재시도→DLQ)
     ```
   - **a. 결과물 → `.cidd/plans/<slug>.md`.** 맨 위에 위 다이어그램, 그 아래 최종 plan 본문 — 깔끔하게, 구현에 바로 먹일 수 있게. 끝에 `## 미해결·검증 필요` 절: reviser/critic이 `검증 필요`로 단 항목 + plan에 영향 주는 미해결 사각지대. 이게 사용자가 실제로 쓰는 파일이다.
   - **b. 과정 로그 → `.cidd/runs/<날짜>-<n>.md`.** 라운드별 history(충돌 수·변경·트레이드오프), 수렴 여부(dry/상한), 사용한 lens 집합, critic 전체 출력. plan 본문은 **`.cidd/plans/<slug>.md`를 가리키기만** 하고 중복 저장하지 않는다(단일 소스 — drift 방지).
   - **c. 인라인(대화) — 결과물 우선, 과정은 파일로.** 순서: 리드(1줄, 전문용어 0) → **결과물 = 결론 plan**(다이어그램 맨 위 + plan 핵심: 무엇을 어떤 순서로 빌드 + 핵심 설계 결정 ≤4, 길면 spine만) → 결정 포인트(lens 마찰에 *진짜 fork/트레이드오프* 남았을 때만: 얻는 것/치르는 것/비대칭/방어 + ask) → 미해결(critic 사각지대 중 plan 영향) → 파일 포인터 둘. ⚠️ **라운드별 마찰 상세는 인라인에 쏟지 말고 runs 파일로 강등**(→ 경로 한 줄). 게이트: 리드·결정의 내부용어는 ≤6단어로 풀고, ★류 장식기호·과압축 금지, 빈 섹션 생략.

## 비용·정직성 규칙
- 서브에이전트 모델은 정의에 박혀 있다: **판단 lens(`lens-structure`·`lens-scope`·`lens-testability`·`lens-security`)와 `plan-reviser`는 `sonnet`**(오라클 없는 판단이라 약한 모델이 off-lens로 드리프트), **enumeration·추출(`lens-failure`·`lens-cost`·`lens-operability`·`friction-extractor`·`completeness-critic`)은 `haiku`**. 라운드·lens 수를 작게 유지해 사용량을 아껴라.
- 이 루프의 제어흐름은 **코드가 아니라 네가 따르는 지시**다 (Workflow의 결정론적 보장과 다름). 그래서 위 종료조건/ dedup을 **문자 그대로** 지켜라 — 임의로 일찍 끝내거나 라운드를 건너뛰지 마라.
- 충돌 해소는 결국 LLM 판단이다. repo가 있으면 가정을 코드로 검증하고, 없으면 "미검증 가정"임을 출력에 명시하라.
