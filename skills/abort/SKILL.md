---
name: abort
description: 진행 중인 CIDD 작업(work-item)을 *완료하지 않고* 폐기한다 — `.cidd/state.md`에서 status:abandoned 표시, history에 이유와 함께 기록, active 레인 비움(아티팩트는 .cidd/에 남김). "이 작업 버려 / 방향 폐기 / 그만하고 다른 거 / 이 plan 죽었어 / abort" 류 요청에. 코드는 건드리지 않는다.
---

# abort (lifecycle 관리)

CIDD work-item을 **완료 없이 폐기**하고 레인을 비운다. plan/build/review 같은 *단계*가 아니라 lifecycle 조작이다 — abandon을 수동 state 편집 대신 한 동작으로(빠뜨림 방지). **이건 단계 끝 결정 메뉴의 `abandon` 핸들러**이기도 하다 — 메뉴에서 abandon을 고르면 이게 자동 실행되고, 메뉴 밖에서 "버려"라고 직접 불러도 동일.

## 경계 (먼저 — 헷갈리지 마라)
- 작업이 **끝났으면** abort 아님 — done으로 닫아라(닫기 ≠ 폐기).
- 방향/plan이 틀렸지만 **계속 갈 거면** abort 아님 — re-plan 하면 된다(README "단계 상태").
- 그냥 상태만 보고 싶으면 abort 아님 — `state.md`를 읽어라.
- abort는 *버릴* 때만: 방향이 죽음 / 작업 드롭 / 급한 다른 일에 레인 필요.

## 입력
- **slug** (기본: state.md의 `active`)
- **reason** (한 줄 — 왜 버리나)

## 절차
1. **확인 (조건부).** 사용자가 단계 끝 결정에서 abandon을 *이미 명시적으로 선택*했으면 그게 확인이다 — 재확인 없이 바로 진행. abandon intent가 새로 나왔거나 어느 slug인지 모호할 때만 한 줄 확인.
2. `.cidd/state.md`의 해당 slug를 `status: abandoned`로.
3. history에 `- <slug> ABANDONED (<날짜>) — <reason>` 추가.
4. `active`가 이 slug면 비운다(레인 free — 다음 작업 가능).
5. 아티팩트(`.cidd/{plans,builds,reviews}/<slug>.md`)는 **지우지 마라** — 남겨서 나중에 참고/되살리기 가능. 삭제는 사용자가 명시할 때만.

## ⚠️ 코드는 건드리지 않는다
build이 이미 코드를 썼더라도 abort는 **그 diff를 되돌리지 않는다.** CIDD work-item 폐기 ≠ 코드 revert다. 코드를 되돌릴지는 git으로 따로 결정하라 — abort 후 "build이 만든 코드 변경은 repo에 그대로 남아있다"고 사용자에게 알려라.

## 날짜
`<날짜>`는 모델이 못 만든다 — 세션이 박는다.
