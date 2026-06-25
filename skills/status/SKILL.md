---
name: status
description: 대상 repo의 `.cidd/state.md`를 읽어 현재 stage·status, 다음 가능한 전이, 막힌 이유, active slug, handoff 집중점, history를 한 화면으로 보여준다. 읽기 전용 — 아무것도 바꾸지 않는다. "지금 상태 뭐야 / 어디까지 갔어 / 왜 막혔어 / 다음 뭐 해 / cidd status" 류 요청에.
---

# status (읽기 전용 상태 리포트)

`.cidd/state.md`를 읽어 CIDD lifecycle의 현재 위치를 한 화면으로 보여준다. **아무것도 바꾸지 않는다** — 상태를 *바꾸려는* 요청은 다른 스킬 몫이다(닫기→done, 폐기→`abort`, 새 작업→해당 단계 스킬, 자율→`auto`).

## 경계
- 상태만 보고 싶을 때. 전이·실행은 안 한다.
- `.cidd/state.md`가 없으면 "아직 CIDD 상태 없음 — explore나 plan부터 시작"이라고 알린다.

## 보여주는 것 (state.md에서)
- **active slug** + **stage**(explore/plan/build/review/done) + **status**(active/paused/abandoned).
- **다음 가능한 전이**: 전이 가드 기준(예: `plan: done`이면 build 가능 / `build: done`이면 review). 단계 끝이면 결정 메뉴 옵션(accept/refine/back/pause/abandon)을 안내.
- **왜 막혔나**: paused면 `unblock`(재개 조건), 가드 미충족이면 그 이유(예: "build은 plan:done 전제인데 plan 진행 중").
- **handoff 집중점**: `handoff.plan→build`(scope·검증필요) / `handoff.build→review`(adequacy 미측정·conformance 우려).
- **rejected**(되풀이 방지 로그), **history**(최근 전이/abandon).
- 산출물 경로: `.cidd/{explorations,plans,builds,reviews}/<slug>.md` 중 존재하는 것.

## 출력
간결한 한 화면. 추정 금지 — state.md에 있는 것만. 비면 비었다고. 끝에 "다음 자연스러운 한 수"를 한 줄(가드/상태 기반, 강요 아님 — 예: "plan:done → `/cidd:build-oracle-loop` 또는 `/cidd:auto`").
