# GOAL — collective-intelligence-driven-development (CIDD) 플러그인

## 한 문단 (요약)
개발의 explore·plan·build·review 단계에 멀티에이전트 규율을 끼워 넣는 Claude Code 플러그인을 만든다. 핵심 명제는 **오라클 비대칭**: 단계마다 결정적 신호(오라클: test/type/compile/run)의 가용성이 다르고, 그에 따라 오케스트레이션 *모양*이 달라야 한다. explore(방향 미정·오라클 없음)는 서로 다른 stance의 접근안을 *발산* 생성해 judge-panel로 초안을 빚고, plan(오라클 빈곤)은 그 초안을 lens가 *마찰*로 수렴시키는 변증법적 심의 — 단일 LLM 의견의 누락·편향을 줄인다. build(오라클 최대)는 심의가 아니라 generate→verify→repair — 오라클이 엔진, 마찰은 *구현*에만(conformance/judge-panel). review(오라클 풍부, 완성품)는 하드 오라클이 게이트, lens는 advisory. **lens는 절대 게이트가 아니다(수렴 ≠ 검증).** Claude Code `Agent` 도구(구독)로 구현한다 — raw API/SDK는 쓰지 않는다.

## 핵심 개념 (오해 금지)
- 집단지성 = wisdom-of-crowds(독립 추정 *집계*)가 **아니다.** 같은 수준 에이전트가 관심사별 lens로 검토 → 충돌 → 수정으로 수렴하는 **dialectic deliberation**. 엔진은 투표가 아니라 *반박*.
- 단일 모델 다각도는 *누락형* 오류를 잡는다. *편향형*(공유 사각)은 못 잡는다 → ground truth(오라클/cross-model/사람)가 그 칸을 맡는다.

## 깨면 안 되는 원칙
1. **오라클 비대칭(플러그인의 척추).** explore = 오라클 없음(초안조차) → 발산 생성 + judge-panel 종합. plan = 오라클 빈곤 → lens 주력(마찰 수렴). build = 오라클 최대 → gen-verify-repair(오라클 엔진, lens 심의 금지). review = 오라클 풍부 → 하드 오라클 주력, lens는 advisory. **explore↔plan은 발산↔수렴 짝.** 오케스트레이션 모양은 오라클 가용성을 따른다.
2. **lens는 review 게이트 금지.** 게이트 = 하드 오라클 pass + oracle-adequacy(coverage/mutation). "lens 충돌 소진"을 머지 근거로 쓰지 마라. **수렴 ≠ 검증.**
3. **위상: lens proposes → oracle disposes.** lens는 싼 *가설 생성기*. 검증 가능한 후보는 오라클이 판정, 판단 영역만 advisory로 남긴다. 순서가 아니라 파이프.
4. **오라클 3계층.** hard(실행/test/type/compile/회귀) / extension(coverage·mutation·fuzz = "초록불 충분성") / lens(유지보수·경계·컨벤션·의도한 실패모드). 하드가 보는 걸 lens로 중복 금지(oracle-subtraction).
5. **lens는 나열이 아니라 도출.** 매 run 3~5개만, 3축 선택: oracle-subtraction · task-relevance · diversity(저상관). 누락은 completeness-critic이 가리킬 때 적응적 추가.
6. **decorrelation.** 생성 측과 검토 측 분리. review 최강 decorr는 cross-model이 아니라 *non-LLM 오라클* 그 자체.

## 제약
- **Agent 도구로만.** raw API / Agent SDK는 쓰지 않고 Claude Code `Agent` 도구(구독)로 동작. 서브에이전트 모델은 작업에 맞춰: haiku(grounded·enumeration) / sonnet(grounding 없는 판단) / 상속(코드생성). low effort, 작은 fan-out.
- **형태**: 플러그인 — `agents/`(lens·friction-extractor·plan-reviser·completeness-critic) + `skills/`(오케스트레이션) + `.claude-plugin/plugin.json`.
- **제어흐름은 모델 판단(SKILL 지시)** → 결정론 보장 없음. 종료조건·dedup을 문자 그대로 박고 캡으로 폭주 방지.

## 단계별 기계 (오라클 가용성 따라 모양이 다름 — 한 기계를 재탕하지 마라)
- **explore(0) = diverge→judge→synthesize**: stance 갈라 접근안 독립 발산(서로 안 봄=anchoring 회피) → approach-judge 비교 → 승자+접목 종합해 초안 plan → plan-friction-loop로 핸드오프. 넓고 갈리는 결정에만.
- **plan = friction-loop**: fan-out(lens 병렬) → 추출(충돌 + high-severity findings) → revise(해소+반영; 검증가능 가정은 "검증 필요"→오라클) → loop-until-dry(새 충돌 0 & 새 high 0, 2연속; seen/addressed로 dedup; 캡) → completeness-critic.
- **build = gen-verify-repair**: 오라클·work-unit 도출(layer 다이어그램; 공유 artifact=foundation 먼저 순차, 진짜 독립만 병렬 — layer hop ≠ 독립 unit) → foundation → 병렬 구현(builder, worktree 격리) → unit별 conformance 게이트(plan 일치 + 옳은 이유로 green; adversarial) → hard unit judge-panel → 전체 오라클 통합 → review handoff.
- **review = oracle-first**: 하드 오라클 → oracle-extension → advisory lens(3축 도출) → completeness-critic.

## 단계 상태 (lifecycle 척추)
세 단계를 파이프라인으로 잇는 최소 상태 파일 `.cidd/state.md`(대상 repo). 단계가 다른 세션에서 독립 호출돼도 이전 산출물을 찾고 plan→build→review→done 전이를 추적. 전이 가드(건너뛰기 방지지 강제 전진 아님): build은 plan:done 전제 등. **각 단계 끝은 `AskUserQuestion` 결정 메뉴**(accept/refine/back/pause/abandon) — 고르면 state.md에 전이 자동 적용(수동 편집·별도 호출 없음). 상태는 두 축: stage(explore/plan/build/review/done) × status(active/paused/abandoned); abandon·done은 status지 이동 아님. abandon=`/cidd:abort` 핸들러(코드 미변경), pause=보류+unblock+레인 비움, refine은 rejected로 되풀이 방지. accept의 상태전이는 자동이되 build 등 코드쓰는 실행은 별개 go(오토모드 `/cidd:auto` 추가 — 시작 1회 동의로 흡수, 전진=오라클 green / 멈춤=red·갈림길; 읽기전용 `/cidd:status`도. 엔트리 라우터는 여전히 안 만듦 — Skill 자동매칭). handoff로 다음 단계에 집중점 전달(plan→build: scope·검증필요 / build→review: adequacy 미측정·conformance 우려). **핸드오프 최소만** — 라우터·hook 게이트는 만들지 않는다(fdd 몫, 자급자족 위해 `.flow` 재사용 안 함). 날짜는 모델이 못 만드니 세션이 박는다.

## 범위 / 빌드 순서
- **구현**: 7 스킬(explore·plan·build·review 4단계 + lifecycle `auto`·`status`·`abort`) + 서브에이전트(plan/review lens · friction·revise·critic · explore·build 기계 · `oracle-runner`) + `.cidd/state.md` 척추 + 출력계약 `.cidd/{explorations,plans,builds,reviews,runs}/` + layer-통과 다이어그램 + 오라클 배선.
- **로드맵(ROI)**: ① 오라클 배선 ✅(`oracle-runner` — detect→실행→파싱→구조화, 없는 도구는 정직하게 "미측정") ② I/O·트리거 계약(다른 워크플로에 꽂기, hook 게이트 뒤 advisory) ③ 가드(캡·예산·lens 선택 검증) ④ 다양한 실제 task로 측정.
- **나중**: 패턴 키트(judge-panel / loop-until-dry-finder / adversarial-verify). friction-loop는 키트의 1개.
- **남음**: 큰/모호 task로 분해 재검증, `auto` 실제 end-to-end 주행.

## 성공 기준
- review가 의견이 아니라 *오라클 판정*으로 게이트된다(lens는 advisory).
- lens 선택이 task에 적응하고, 켠 lens가 *실제로 새 finding을 낸다*(한계 커버리지 측정으로 입증).
- 같은 입력 반복에 결론이 *유용하게* 안정적(완전 동일 불가, 결론 일관).
- "범용" 주장은 다양한 실제 task 측정 데이터 뒤에만.

## 안티골 (하지 마라)
- lens를 review 승인 게이트로 쓰기 / 수렴을 검증으로 착각.
- 하드 오라클이 보는 걸 lens로 중복(노이즈).
- lens "그냥 많이" 추가(상관·비용·느린 수렴). 레버는 다양성·선택.
- raw API/SDK 사용. plan lens를 review에 그대로 재탕.
- 오라클 미배선 상태로 "범용 개발 도구" 주장.
