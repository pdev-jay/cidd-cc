# CIDD — Collective-Intelligence-Driven Development

여러 관점(lens)이 **마찰**로 수렴하는 변증법적 심의를 개발의 plan·review 단계에 끼워 넣는 Claude Code 플러그인. 단일 LLM 의견의 누락·편향을 줄이되, **결정적 신호(오라클: test/type/compile/run)가 있는 곳에선 lens가 그 위에 군림하지 않게** 한다.

핵심 원칙: **lens는 절대 게이트가 아니다(수렴 ≠ 검증)** — 오라클(test/type/compile/run)이 있는 곳에선 오라클이 판정하고 lens는 advisory다. 오케스트레이션 모양은 단계별 오라클 가용성을 따른다(아래 표).

## 개념 (오해 금지)
- 집단지성 = wisdom-of-crowds(독립 추정 *집계*)가 **아니다.** 같은 수준 에이전트가 lens별로 검토 → 충돌 → 수정으로 수렴하는 **dialectic deliberation**. 엔진은 투표가 아니라 *반박*.
- 단일 모델 다각도 = *누락형* 오류를 잡는다. *편향형*(공유 사각)은 오라클/cross-model/사람이 맡는다.

## 단계 스킬 (단계마다 오라클 가용성이 다르면 오케스트레이션 모양도 다르다)
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
- **lifecycle/meta 스킬**: `/cidd:auto`(목표→explore→…→review **자율 주행**; 전진=오라클 green, 멈춤=오라클 red·진짜 갈림길·시작 1회 동의 — 단계 기계는 그대로 재사용), `/cidd:status`(`.cidd/state.md` 읽기 전용 — 현재 stage·다음·막힌 이유), `/cidd:abort`(작업 폐기, 코드 미변경). **엔트리 라우터는 안 만든다**(Skill 설명 자동매칭이 그 역할).
## 작동 시나리오

```
요청 / 목표
   │
   ▼
[ .cidd/state.md ]  척추 — stage × status + 단계 간 handoff
   │   /cidd:auto면 자동 주행: 전진 = 오라클 green / 멈춤 = 오라클 red · 진짜 갈림길
   ▼
[ explore ]   오라클 없음 · 발산
   │   approach-generator ×N (독립 stance) → approach-judge → 초안 plan
   ├─ 결정 메뉴: accept→다음 / refine→재실행 / back / pause / abandon
   ▼
[ plan ]      오라클 빈곤 · 마찰
   │   lens 3~5개 병렬 → friction-extractor → plan-reviser
   │   ↺ loop-until-dry → completeness-critic  → 다듬은 plan
   ├─ 결정 메뉴
   ▼
[ build ]     오라클 최대 · 생성-검증-repair
   │   foundation → 독립 unit 병렬 (builder)
   │   → oracle-runner(green?) → conformance(옳은 이유로 green?)
   │   red면 repair · 게이트 통과해야 done  → 코드 + diff
   ├─ 결정 메뉴
   ▼
[ review ]    오라클 풍부 · oracle-first
   │   oracle-runner = hard(test/type/lint) + adequacy(coverage/mutation/complexity)  ← GATE
   │   review-lens는 advisory만 (게이트 아님)  → 리뷰 리포트
   │   gate pass
   ▼
[ done ]      history 기록

축: lens proposes → oracle disposes.  오라클이 없을수록 lens/judge가, 풍부할수록 오라클이 판정한다.
```

## 에이전트 (lens 라이브러리 + 기계)
**plan lens (9)** — 오라클 빈곤이라 lens가 주력(마찰). 매 run 3~5개만 *도출*:

| lens | 보는 것 | 켜기 |
|---|---|---|
| `lens-structure` | 변경 비용을 어디 쌓나 — 벌지 않은 seam(과/미설계)·한 개념의 분산(지역성) | 상시 |
| `lens-feature` | 기능 완결성 — happy path·엣지·에러 처리·빠진 단계 | 상시 |
| `lens-failure` | 무엇이 깨지나 — 경계값·실패 경로·예외·동시 접근 | 상시 |
| `lens-testability` | 이대로 테스트 가능한가 — 부작용·전역상태·시간/IO 결합, 주입·관측 | 상시 |
| `lens-scope` | 과/미설계(YAGNI) — 요청 안 한 추상·빠진 핵심 단계 | 상시 |
| `lens-security` | 신뢰 못 할 입력·권한·인증·민감데이터 | auth/입력 닿을 때 |
| `lens-operability` | 롤백·마이그레이션·배포·운영 영향 | 배포 영향 있을 때 |
| `lens-cost` | 성능·자원 — 핫패스·N+1·재계산·캐시 | 성능 민감할 때 |
| `lens-flow` | data/control/state 흐름이 옳은가/위험한가 | 수동(기본 제외 — 비평보다 이해 도구) |

**review lens (7)** — 오라클 풍부라 lens는 advisory only(게이트 아님):

| lens | 보는 것 | 켜기 |
|---|---|---|
| `rlens-maintainability` | 6개월 뒤 고칠 사람 — 가독성·네이밍·숨은 결합·암묵 가정 | 상시 |
| `rlens-convention` | 기존 코드 패턴·관용구와 일치하나 | repo 필수 |
| `rlens-failure-mode` | 초록불이 옳은 이유로 초록인가 (의심만 → 오라클이 판정) | 상시 |
| `rlens-abstraction-fit` | 추상·경계가 옳은가 — 삭제 테스트(얕은 모듈)·의존성 방향 | 상시(코드 필요) |
| `rlens-security-logic` | SAST가 못 잡는 로직 수준 권한 | auth/입력 닿을 때 |
| `rlens-readability` | 호출부/시그니처 인간공학 — 오용하기 어려운가 | 상시 |
| `rlens-simplicity` | 필요 이상 복잡/긴 코드(우발적 복잡도) — 카운트는 메트릭, essential/accidental 판정은 lens | 상시 |
- **explore 기계**: `approach-generator`(stance별 독립 발산), `approach-judge`(judge-panel 비교·종합)
- **plan 기계**: `friction-extractor`, `plan-reviser`, `completeness-critic`
- **build 기계**: `builder`(unit 구현+repair, 코드 생성이라 capable 모델 상속), `build-conformance`(adversarial plan-일치+green-적정성, haiku), `build-judge`(judge-panel, haiku)
- **오라클 기계**: `oracle-runner`(test/type/lint/build + coverage/mutation/complexity/duplication을 detect→실행→파싱→구조화; 없는 도구는 "미측정"; **sonnet 고정** — 약한 모델은 없는 도구의 metric을 *환각*하기 때문). build·review가 호출해 게이트·`rlens-simplicity` 입력에 먹임.
- lens는 *나열*이 아니라 매 run 3~5개 *도출*(oracle-subtraction · task-relevance · diversity).

## 단계 상태 (lifecycle 척추)
세 단계를 *파이프라인*으로 잇는 최소 상태 파일 — 대상 repo의 `.cidd/state.md`. 단계가 **다른 세션에서 독립 호출**돼도(예: build만 새 세션) 이전 단계 산출물을 찾고, plan→build→review→done 전이를 추적한다.

```
active: <slug>
## <slug>
status:  active | paused | abandoned
target_repo: <path>
stage:  explore | plan | build | review | done   # = 여기까지 *승인*됨(다음이 열림). 강제 아님 — ratchet 아니다.
profile: micro | small | standard | high-risk | -   # 규모 triage 결과 — 각 단계가 폭/게이트 결정에 읽음(auto가 박음, 단독 호출이면 단계가 자가 판정). 번복 시 갱신.
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
- **자급자족** — CIDD 척추(`.cidd/state.md`)는 *핸드오프 최소*만 담는다. 라우터·hook 게이트는 의도적으로 안 만든다(Skill 자동매칭으로 충분). 단계 자동 연결이 필요하면 `/cidd:auto`, 그 외엔 사람이 단계를 호출한다.

## 인라인 출력 형태
인라인(대화) 출력은 **결과물 우선** — 그 단계 산출물(explore=방향·초안 / plan=결론 plan / build=빌드 상태 / review=머지 판정)을 다이어그램+핵심으로 보여주고, 과정(라운드·후보·repair raw)은 단계 파일(`runs`/`explorations`/`builds`/`reviews`)로 강등한다. 진짜 fork/트레이드오프가 남으면 "결정 포인트"로 묻는다. 평이어(내부용어는 ≤6단어로 풀기)·신호밀도(장식기호·과압축 금지)·적응형(빈 섹션 생략) 게이트. **규약 본문은 각 스킬 출력 절이 contained로 담는다** — 스킬은 런타임에 README를 로드하지 않으므로 참조가 아니라 내장이다.

## 작업 규모 적응 (가볍게/무겁게)
작은 작업(한 줄 수정·필드 추가·rename)에 풀 파이프라인은 과하다. CIDD는 규모에 맞춰 무게를 **자동** 조절한다 — 시작에 메인 에이전트가 값싸게 판정(서브에이전트 없음): ① 방향 뻔한가 ② 틀리면 위험한가 ③ 테스트 있나. 셋이 *다른* 다이얼을 움직인다:
- **방향 불확실성 → 심의**(explore·lens·라운드·judge). 뻔하면 0까지 접는다 — 비용 대부분이 여기서 빠진다.
- **오류비용×범위 → 검증 게이트**(conformance·security). 작아도 위험하면(auth·schema·결제·동시성·BLE/프로토콜 등) 유지·승격.
- **오라클 강도 → 심의 바닥**. 테스트 없으면 "green"이 거짓 안심이라 심의를 안 줄이거나 특성 테스트부터 세운다.

profile: **micro / small / standard / high-risk**. ⚠️ **검증(하드 오라클·머지 게이트)은 어느 규모서도 생략 불가 — "가볍게"가 "검증 없이"가 되면 안 된다.** 진행 중 영향이 커지면 올린다(내리는 건 보수적). `auto`는 단계 건너뛰기까지 자동, 단독 호출 단계는 자기 폭을 스스로 접는다.

## 핵심 원칙 (요약)
1. 오라클 비대칭 — plan은 lens 주력, review는 오라클 주력.
2. **lens는 review 게이트 금지. 수렴 ≠ 검증.**
3. 위상: **lens proposes → oracle disposes** (순서가 아니라 파이프).
4. 오라클 3계층: hard / extension / lens. 하드가 보는 걸 lens로 중복 금지.

## 설치 / 사용
Claude Code `Agent` 도구로 동작. 서브에이전트 모델은 작업에 맞춰 haiku(grounded·enumeration) / sonnet(grounding 없는 판단) / 상속(코드생성), low effort.

```bash
# 설치 (GitHub) — 이 repo가 자체 마켓플레이스를 포함한다
/plugin marketplace add pdev-jay/cidd-cc
/plugin install cidd@cidd-cc
/reload-plugins                 # 재시작 없이 현재 세션에 적용

# 또는 로컬 dev (소스 라이브 로드 — 세션 시작 시 플래그)
claude --plugin-dir /path/to/cidd-cc
```

설치되면 `/cidd:*` 스킬 7 + `cidd:*` 서브에이전트 25가 등록된다(`/help`·`/agents`에서 확인). 슬래시로 부르거나("`/cidd:plan-friction-loop`") 자연어로 맥락 자동 호출된다("이 plan 마찰 검토해줘", "이 변경 리뷰해줘", "알아서 끝까지").

출력은 대상 프로젝트 cwd의 `.cidd/`에 모인다 — 결과물 `.cidd/explorations/`·`.cidd/plans/`·`.cidd/builds/`·`.cidd/reviews/`(써먹는 산출물; build은 코드 변경은 repo에, 리포트는 builds/), 과정 로그 `.cidd/runs/`(감사·dogfooding). 단계 연결: explore `explorations/<slug>.md`(초안) → plan friction이 `plans/<slug>.md`로 다듬음 → build이 소비·diff 생성 → review가 그 diff에 오라클. 네임스페이스라 남의 repo와 충돌 없음, `.gitignore`에 `.cidd/` 한 줄.

## 상태
스킬 7(explore·plan·build·review + lifecycle auto·status·abort) + 서브에이전트 25. 설치는 위 "설치/사용" 참조.

설계 근거(오라클 비대칭 · 모델 배치 haiku/sonnet/상속 · 오라클 배선)는 작은 케이스 측정으로 다듬었다 — 예: 테스트가 green이어도 mutation이 "옳은 이유로 green인지"를 잡는 흐름을 end-to-end로 확인. **검증 진행 중**: 더 크고 모호한 task에서의 분해, `auto`의 실제 end-to-end 주행.

> ⚠️ 정직성: review를 오라클 없이 돌리면 advisory일 뿐 게이트가 아니다. "범용 개발 도구" 주장은 다양한 실제 task 측정 뒤에.
