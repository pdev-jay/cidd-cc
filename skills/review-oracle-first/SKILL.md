---
name: review-oracle-first
description: 변경(diff)을 리뷰할 때 하드 오라클(test/type/lint/run)을 먼저 최대로 짜내고, 그 위에 review-lens를 advisory로만 얹는다. lens는 절대 승인 게이트가 아니다. "이 변경/PR 리뷰해줘, 머지해도 되나" 류 요청에 사용.
---

# review-oracle-first

review는 plan과 다르다 — **오라클이 풍부**하다. 그래서 lens가 주력이 아니라, 하드 오라클이 게이트고 lens는 보조다.

## 절대 규칙
- **lens는 게이트가 아니다.** 게이트(머지 차단) = 하드 오라클 pass뿐. adequacy(coverage/mutation)·미검증 경로는 게이트가 아니라 *고지* — 머지를 막지 않고 "얼마나 믿을지"를 표시한다(거짓 안심 방지). lens findings는 advisory.
- **수렴 ≠ 검증.** "lens가 더 못 찾음"을 통과 근거로 쓰지 마라.
- **oracle-subtraction.** 오라클이 보는 것(동작/타입/테스트/회귀)은 lens에게 시키지 마라. lens는 오라클이 *구조적으로 못 보는 것*만.

## 입력
- diff 또는 변경된 파일 + 대상 repo (오라클 실행에 필수).

## 단계 상태 (lifecycle 척추)
**진입 시** 대상 repo의 `.cidd/state.md`에서 `build: done`인 active slug의 build 리포트·diff를 읽는다(있으면). `handoff.build→review`에 적힌 "adequacy 미측정 / conformance 우려" unit에 **오라클·lens를 우선 겨눈다**(build이 약하다고 자백한 곳). build 없이 직접 호출된 diff면 그냥 진행. **완료 시** 갱신: `review: done → .cidd/reviews/<slug>.md`, `gate: pass|fail`. **끝나면 `AskUserQuestion` 결정 메뉴(accept/refine/back/pause/abandon)로 고른 전이를 자동 적용**(README "단계 끝 = 결정 메뉴") — accept면 gate pass 시 `stage: done`(+ history), fail이면 refine/back. ⚠️ **단 `auto` 구동 중이면 끝-메뉴 생략, gate 결과(pass/fail) + DISCLOSURE(미검증 경로·adequacy 미측정)를 반환** — pass면 auto가 done 처리(DISCLOSURE는 auto 최종 리포트로 올림), fail이면 멈춤. 메뉴는 fork·red·done에서만. (`updated`는 세션이 박음.)

## 규모 적응 (먼저)
review에서 **하드 오라클은 규모 무관 항상 최대**로 — 게이트이자 제일 싼 안전망이다. 줄이는 건 lens(advisory) 개수뿐.
- **규모는 state.md에서 먼저 읽어라(요청보다 우선)**: `handoff.build→review`의 `adequacy 미측정 unit·conformance 우려`가 *오라클 약한 지점* = lens 유지·집중할 곳을 직접 가리킨다(build이 약하다고 자백한 곳). profile 라벨은 출발점, 실제 diff 범위로 정련. 없으면 자가 판정(diff 범위·위험 표면·coverage).
- **lens 개수 = 방향/위험 따라**: micro(작고 되돌리기 쉽고 변경 라인 테스트 덮음) → lens 0~1 / standard → 3~5.
- ⚠️ **변경 라인이 테스트에 안 덮였으면(오라클 약함) lens를 줄이지 마라** — 그게 유일한 advisory 안전망. coverage 공백을 DISCLOSURE에 명시.
- ⚠️ **오류비용 큰 변경**(auth·권한·민감데이터 등)이면 규모 작아도 `rlens-security-logic` 유지(task-gating이 이미 켬).
- **GATE(머지 판정)는 어느 규모서도 생략 불가.** 번복: 영향 커지면 lens 올림.

## 절차
1. **① Hard oracle (먼저) — `cidd:oracle-runner` 호출.** 변경 파일/diff 범위를 넘기면 runner가 test/type/lint/build를 *실제 실행·인용*해 구조화 리포트로 돌려준다(추측 아님; 없는 도구는 "미측정 + 이유"). 하드 실패 목록이 1차 게이트 결과 = 머지 차단 사유.
2. **② Oracle-extension — 같은 runner 리포트의 확장부.** coverage(변경 라인 미덮이면 "초록불 불충분"), mutation("옳은 이유로 green인지"), complexity/duplication 린터(radon·lizard·eslint-complexity·jscpd). 없는 축은 runner가 "adequacy 미측정 + 이유"로 표시 — 거짓 안심 금지. complexity/duplication 후보는 `rlens-simplicity`가 소비한다(카운트는 runner의 오라클 몫, 본질/우발 판정은 lens 몫 — 오라클 빼기).
3. **③ Lens fan-out (advisory).** review-lens를 3축(oracle-subtraction·task-relevance·diversity)으로 **3~5개 선택**해 병렬 호출(`Agent`, haiku). 각 lens는 ①②가 못 보는 것만. failure-mode lens가 의심 지점을 내면 *판정하지 말고* ②(테스트/mutation)로 내려 확인 — **lens proposes, oracle disposes.**
4. **④ (선택) 정리.** `completeness-critic`으로 어느 축도 안 본 사각지대. lens findings 간 긴장은 `friction-extractor`로 묶어도 됨(advisory).
5. **⑤ CLAUDE.md 후보 추적(극히 드물어야 정상 — 서브에이전트 없음, 너 직접).** ADVISORY 중 세 조건을 **전부** 만족하는 것만 걸러라: (a) repo 코드/설정을 읽어서 나오지 않고 (b) 이번 diff 한정이 아니라 **이 repo에 상시 적용되는** 규칙/컨벤션이고 (c) 팀 전체가 알아야 한다. 대부분의 finding(이번 변경 자체의 문제)은 여기 안 걸린다 — 걸리는 게 드문 게 정상이다.
   - 걸러진 항목을 `.cidd/claude-md-candidates.md`(gitignored, repo 로컬 누적 원장 — 없으면 새로 만들어라)와 대조: 이미 있는 항목과 실질 동일하면 `count` +1·최근 확인일 갱신, 새 항목이면 `count: 1`로 추가.
   - **`count >= 2`(다른 review에서 반복 확인됨)인 항목만** 최종 리포트에 "CLAUDE.md 후보" 절로 승격 — 문구 초안 + 근거(몇 번째·어느 review) + 대상(`./CLAUDE.md` 있으면 추가할 절, 없으면 신규 생성 여부).
   - **사람이 승인해야만 실제 `CLAUDE.md`에 쓴다 — 자동 기록 절대 금지.** 승인하면 그 절에 반영, 거절하면 원장에 `dismissed: true`로 표시해 재제안 안 함.
   - ⚠️ 이건 advisory 중의 advisory다 — 게이트에 전혀 영향 없다. `auto` 구동 중이면 승인을 못 받으니(대화 없음) 최종 리포트에 "제안됨 — 사람이 나중에 검토"로만 얹고 파일엔 안 쓴다.
6. **출력 = 리뷰 리포트.** **`.cidd/reviews/<slug>.md`에 전체 저장**(`<slug>` = PR/브랜치/변경 이름, 없으면 `<날짜>-<n>`) — 머지 판정의 근거 기록. 아래 다이어그램·GATE·ADVISORY는 *파일(리포트)* 구조다. **인라인은 결과물 우선, 과정은 파일로** — 순서: 리드(1줄) → **결과물 = 머지 판정(GATE = 하드 pass/fail만)**(다이어그램 맨 위 + GATE: 하드 pass/fail·실행출력 인용) → **DISCLOSURE(고지, 게이트 아님)**: adequacy 또는 "미측정" + 미검증 경로 → ADVISORY는 **high만 한 줄씩**(전체 lens findings는 파일로) → **CLAUDE.md 후보(있으면만 — `count>=2`인 것만, 대부분 빈 섹션이 정상)** → 게이트 fail이면 결정 포인트(무엇이 막나 + 무엇 고치면 풀리나). 게이트: 평이어·장식기호 금지·빈 섹션 생략.
   - **다이어그램(필수, 리포트 맨 위) = layer 통과 flow**: 변경이 닿는 경로를 **계층(layer)을 가로지르는 flow**로 그려라(네가 직접). 왼쪽 축에 layer 라벨(`[Route] [Service] [Infra] [External] [Worker]` 등), flow는 위→아래로 layer를 가로지르며 내려간다(화살표에 무엇이 흐르나 라벨). 변경 노드 `*` + 그 노드를 쓰는 소비자(blast radius)까지. **각 노드에 오라클 상태**: `✅`(테스트 덮음) / `⚠️`(미덮임·미측정). 오라클 공백이 *어느 layer*에 있는지 그림에서 바로 보인다.
     ```
     예)
     [Route]     POST /checkout* ✅ ──order──┐
     [Service]   OrderService* ⚠️미덮임 ──▶ PaymentGateway* ⚠️ ──▶
     [External]  Ledger ✅
                 △ Service layer 변경분 커버리지 0 — 게이트 주의
     ```
   - **GATE(머지 판정 = 하드 오라클만)**: 하드 오라클 pass/fail + 실제 실행 출력 인용. ← 머지를 *막는* 판정은 여기뿐. adequacy 공백도 미검증 경로도 머지를 막지 않는다(막는 건 하드 fail뿐).
   - **DISCLOSURE(고지 — 게이트 아님, 의무)**: adequacy(coverage/mutation 또는 "미측정") + ⚠️ **`PROD PATH UNVERIFIED: <file:line>`(handoff에서 받았거나 coverage로 직접 발견)를 *의무 한 줄*로 박아라** — "머지 가능하나 이 프로덕션 라인은 미검증, 거기 회귀는 조용히 green"으로 *강등 표시*. 표면이 얇아도 silent pass 금지(멈춤을 안 거니 이 고지가 유일한 안전망). 미검증 경로 없으면 "전 경로 검증됨"이라도 항상 출력(빈 줄로 거짓 안심 만들지 마라).
   - **ADVISORY**: lens findings (각 "오라클이 못 보는 이유" 포함). 명시: 이건 게이트 아님.
   - **CLAUDE.md 후보(있을 때만)**: `count>=2`로 승격된 항목의 문구 초안 + "N번째 반복 확인" 근거. 사람이 승인해야 실제 파일에 반영 — 여기 적힌 건 제안이지 이미 반영된 게 아니다.

## review-lens 선택 풀 (도출용, 다 켜는 게 아님)
- `rlens-maintainability` — 6개월 뒤 고칠 사람 관점
- `rlens-convention` — 기존 패턴 일치 (repo 필수)
- `rlens-failure-mode` — 초록불이 옳은 이유인가 (제안만 → 오라클이 판정)
- `rlens-abstraction-fit` — 경계/추상이 옳은가
- `rlens-security-logic` — SAST가 못 잡는 로직 권한 (auth/입력 닿을 때만)
- `rlens-readability` — 호출부/시그니처 인간공학
- `rlens-simplicity` — 필요 이상 복잡/긴 코드(우발적 복잡도). 메트릭(복잡도/중복 린터)이 후보를 세고, lens는 essential/accidental + 더 단순한 형태만 판정

## 비용·정직성
- review-lens는 haiku(코드가 grounding이라 약한 모델로 충분), `oracle-runner`는 sonnet(도구 부재 시 환각 방지). lens 3~5개로 제한.
- 오라클 결과는 *실행 출력*으로 보고 — LLM 추측을 실행 위에 얹지 마라.
- repo가 없어 ①②를 못 돌면, "오라클 미배선 — 이건 advisory 리뷰일 뿐, 게이트 아님"을 리포트 **맨 위에** 경고로 박아라.
