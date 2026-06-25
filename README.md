# CIDD — Collective-Intelligence-Driven Development

여러 관점(lens)이 **마찰**로 수렴하는 변증법적 심의를 개발의 plan·review 단계에 끼워 넣는 Claude Code 플러그인. 단일 LLM 의견의 누락·편향을 줄이되, **결정적 신호(오라클: test/type/compile/run)가 있는 곳에선 lens가 그 위에 군림하지 않게** 한다.

전체 설계·원칙·안티골은 [`GOAL.md`](./GOAL.md).

## 개념 (오해 금지)
- 집단지성 = wisdom-of-crowds(독립 추정 *집계*)가 **아니다.** 같은 수준 에이전트가 lens별로 검토 → 충돌 → 수정으로 수렴하는 **dialectic deliberation**. 엔진은 투표가 아니라 *반박*.
- 단일 모델 다각도 = *누락형* 오류를 잡는다. *편향형*(공유 사각)은 오라클/cross-model/사람이 맡는다.

## 네 스킬 (단계마다 오라클 가용성이 다르면 오케스트레이션 모양도 다르다)
| 스킬 | 단계 | 오라클 | 엔진 | 게이트 |
|---|---|---|---|---|
| `/cidd:direction-explore` | explore (0) | **없음**(초안조차) | 발산 생성 → judge-panel 종합 | — |
| `/cidd:plan-friction-loop` | plan | 빈곤 | lens **마찰**(심의) | — |
| `/cidd:build-oracle-loop` | build | **최대** | **gen-verify-repair** | unit별 오라클 green + conformance |
| `/cidd:review-oracle-first` | review | 풍부(완성품) | 하드 오라클, lens advisory | 하드 오라클 pass + adequacy |

- **direction-explore** (stage 0, plan이 *없을* 때): 서로 다른 stance로 접근안 독립 발산(anchoring 회피) → judge-panel 비교·종합 → **초안 plan**. 그 초안이 plan-friction-loop 입력. 넓고 갈리는 결정에만(좁으면 과잉 — 바로 초안 잡아 friction-loop).
- **plan-friction-loop**: lens fan-out → 충돌 + high-severity findings 추출 → revise → 마찰 없을 때까지(loop-until-dry + dedup) → completeness-critic.
- **build-oracle-loop**: layer 다이어그램 → work-unit 도출(공유 artifact=foundation 먼저 순차, 진짜 독립만 병렬 — *layer hop ≠ 독립 unit*) → builder 병렬 구현(worktree) → green까지 repair → unit별 **adversarial conformance**(plan 일치 + 옳은 이유로 green) → hard unit judge-panel → 전체 오라클 통합 → review handoff. **plan의 lens-friction을 여기 얹지 않는다**(오라클이 엔진).
- **review-oracle-first**: ① 하드 오라클 실행(test/type/lint) → ② oracle-extension(coverage/mutation) → ③ review-lens는 ①②가 *구조적으로 못 보는 것만* advisory. **lens는 절대 머지 게이트가 아니다.**
- plan·build·review 출력은 **맨 위에 layer 통과 flow ASCII 다이어그램** — layer(Route/Service/Infra/External/Worker…)를 왼쪽 축으로, 요청·데이터가 계층을 가로지르며 내려가는 경로. plan은 설계 흐름(+빠진 layer가 드러남), review는 변경 blast radius + layer별 오라클 커버리지(✅/⚠️). (강등된 `lens-flow`의 *이해* 가치가 여기서 시각화로 재사용됨.)
- 그 외 **`/cidd:abort`** — 진행 중 작업 폐기(lifecycle 관리, stage 아님; state·history 정리, 코드 미변경).

## 에이전트 (lens 라이브러리 + 기계)
- **plan lens (9)**: 상시 `lens-structure` `lens-feature` `lens-failure` `lens-testability` `lens-scope` + task-gated `lens-security` `lens-operability` `lens-cost` + `lens-flow`(data/control/state — 검증 2회 고유 0, 기본 선택 제외·수동 전용)
- **review lens (7)**: `rlens-maintainability` `rlens-convention` `rlens-failure-mode` `rlens-abstraction-fit` `rlens-security-logic` `rlens-readability` `rlens-simplicity`(우발적 복잡도/리팩토링 — 메트릭이 카운트, lens는 essential/accidental 판정)
- **explore 기계**: `approach-generator`(stance별 독립 발산), `approach-judge`(judge-panel 비교·종합)
- **plan 기계**: `friction-extractor`, `plan-reviser`, `completeness-critic`
- **build 기계**: `builder`(unit 구현+repair, 코드 생성이라 capable 모델 상속), `build-conformance`(adversarial plan-일치+green-적정성, haiku), `build-judge`(judge-panel, haiku)
- **오라클 기계**: `oracle-runner`(test/type/lint/build + coverage/mutation/complexity/duplication을 detect→실행→파싱→구조화; 없는 도구는 "미측정"; **sonnet 고정** — haiku는 없는 도구 metric을 *환각*, opus는 하드케이스서 우위 불확인[실측]). build·review가 호출해 게이트·`rlens-simplicity` 입력에 먹임.
- lens는 *나열*이 아니라 매 run 3~5개 *도출*(oracle-subtraction · task-relevance · diversity).

## 단계 상태 (lifecycle 척추)
세 단계를 *파이프라인*으로 잇는 최소 상태 파일 — 대상 repo의 `.cidd/state.md`. 단계가 **다른 세션에서 독립 호출**돼도(예: build만 새 세션) 이전 단계 산출물을 찾고, plan→build→review→done 전이를 추적한다.

```
active: <slug>
## <slug>
status:  active | paused | abandoned
target_repo: <path>
stage:  explore | plan | build | review | done   # = 여기까지 *승인*됨(다음이 열림). 강제 아님 — ratchet 아니다.
explore: done → .cidd/explorations/<slug>.md  |  -
plan:   done → .cidd/plans/<slug>.md   |  -
build:  in-progress | done → .cidd/builds/<slug>.md (diff: <ref>)  |  -
review: done → .cidd/reviews/<slug>.md (gate: pass|fail)  |  -
rejected:                  # 되풀이 방지 — 재실행이 이걸 피한다 (friction-loop의 seen 원리)
  explore: <버린 방향/후보> — <이유>
  plan:    <버린 초안> — <이유>
unblock: <조건>            # status=paused일 때만 — 무엇이 풀리면 재개
handoff:
  explore→plan: 선택한 방향 · 갈린 가정 → friction 압박점
  plan→build:   scope · 미해결/검증필요 항목
  build→review: adequacy 미측정 unit · conformance 우려  → review 집중점
updated: <date>        # 모델은 날짜를 못 만듦 — 세션이 박는다
## history
- <slug> done (<date>) — commit <ref>
```

- **전이 가드는 건너뛰기 방지지 강제 전진이 아니다**: build은 `plan: done` 없으면 plan 먼저(skip 금지). 하지만 `stage`는 "여기까지 됐다 = 다음이 *열림*"이지 "다음으로 가라"가 아니다.
- **단계 끝 = 결정 메뉴(고르면 자동 처리).** 각 스킬은 산출물을 낸 뒤 `AskUserQuestion`으로 *현재 stage에 유효한* 선택지를 띄우고, 고른 전이를 **state.md에 자동 적용**한다 — 수동 편집·별도 호출 없음. 상태는 두 축: **stage**(어디까지) × **status**(active/paused/abandoned). abandon·done은 status지 accept/refine/back과 동급이 아니다.

  | 선택 | 자동 처리 | 유효 stage |
  |---|---|---|
  | **accept** | stage→다음 (review면 status=done) | 전부 |
  | **refine** | stage 유지, 현 산출물을 `rejected`에 적고 현 단계 재실행 | 전부 |
  | **back** | stage→이전(또는 지정한 더 앞). 이전 산출물은 메뉴로 남음(explore 후보 등) | explore 외 |
  | **pause** | status=paused + `unblock`(뭐 풀리면 재개) 기록, `active` 비움. resume=그 stage 재진입 | 전부 |
  | **abandon** | status=abandoned + history(이유), `active` 비움, 아티팩트 남김(코드 미변경). `/cidd:abort` 핸들러 | 전부 |

  - **전이(상태)는 자동, 실행은 별개**: accept가 stage를 올리되, build처럼 *코드를 쓰는* 단계의 실제 실행은 따로 go를 받아라.
  - "끝까지 알아서"는 accept를 기본 자동 전진하는 **오토 모드**(향후 opt-in). 기본은 이 메뉴(사람 게이트).
- **자급자족** — fdd `.flow` 척추를 재사용하지 않는다(플러그인 이식성). 트레이드오프: 개념 중복. CIDD 척추는 *핸드오프 최소*만 — 라우터·hook 게이트는 fdd 몫이고, fdd 환경이면 나중에 통합 가능.

## 핵심 원칙 (요약)
1. 오라클 비대칭 — plan은 lens 주력, review는 오라클 주력.
2. **lens는 review 게이트 금지. 수렴 ≠ 검증.**
3. 위상: **lens proposes → oracle disposes** (순서가 아니라 파이프).
4. 오라클 3계층: hard / extension / lens. 하드가 보는 걸 lens로 중복 금지.

## 설치 / 사용
크레딧 0 — Claude Code `Agent` 도구(구독)로 동작. 서브에이전트 haiku + low effort.

```bash
# A. 로컬 dev 로드 — 세션 시작 시에만 적용, 재시작 필요
claude --plugin-dir /path/to/collective-intelligence-driven-development

# B. 상시 설치(영속, 권장) — GitHub 카탈로그 경유:
#   /plugin marketplace add pdev-jay/plugins
#   /plugin install cidd@pdev-jay
#   /reload-plugins        ← 재시작 없이 이 세션에 적용됨(실측). --plugin-dir 만 세션 시작 시 한정.
```

로드되면:
- 스킬: `/cidd:plan-friction-loop`, `/cidd:review-oracle-first` (또는 Claude가 맥락으로 자동 호출)
- 서브에이전트: `cidd:lens-structure`, `cidd:rlens-maintainability` … `/agents`에 등록

출력은 대상 프로젝트 cwd의 `.cidd/`에 모인다 — 결과물 `.cidd/explorations/`·`.cidd/plans/`·`.cidd/builds/`·`.cidd/reviews/`(써먹는 산출물; build은 코드 변경은 repo에, 리포트는 builds/), 과정 로그 `.cidd/runs/`(감사·dogfooding). 단계 연결: explore `explorations/<slug>.md`(초안) → plan friction이 `plans/<slug>.md`로 다듬음 → build이 소비·diff 생성 → review가 그 diff에 오라클. 네임스페이스라 남의 repo와 충돌 없음, `.gitignore`에 `.cidd/` 한 줄.

## 상태
> ✅ **배포됨(2026-06-25)** — GitHub `pdev-jay/cidd-cc` + `pdev-jay/plugins` 카탈로그 경유 `/plugin install cidd@pdev-jay` + `/reload-plugins`로 **재시작 없이 in-session 적용**(설치엔 재시작 필수라는 통념은 실측 반증). `/cidd:*` 스킬 5 + `cidd:*` 에이전트 25 호출 가능. 실제 `cidd:lens-structure` dispatch 검증: resolve + on-task + tool 제한(Bash 없음)으로 **off-script 사라짐** — general-purpose 인라인이 3회 빗나갔던 근본 해소.

- 설계 검증됨(설치 전, general-purpose 인라인): plan friction-loop(run3~5: lens 한계커버리지·flow 강등·layer 다이어그램·결함#3), build gen-verify-repair + review oracle-first + `.cidd/state.md` 척추(run6 e2e on scratch repo). 도중 conformance git-status 결함 발견·수정.
- 미검증(이제 실제 dispatch로 가능): 실제 `cidd:` 에이전트로 e2e 재현, 큰/모호 task 분해, coverage/mutation adequacy, 라우터.

> ⚠️ 정직성: review를 오라클 없이 돌리면 advisory일 뿐 게이트가 아니다. "범용 개발 도구" 주장은 다양한 실제 task 측정 뒤에.
