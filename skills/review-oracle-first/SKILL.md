---
name: review-oracle-first
description: 변경(diff)을 리뷰할 때 하드 오라클(test/type/lint/run)을 먼저 최대로 짜내고, 그 위에 review-lens를 advisory로만 얹는다. lens는 절대 승인 게이트가 아니다. "이 변경/PR 리뷰해줘, 머지해도 되나" 류 요청에 사용.
---

# review-oracle-first

review는 plan과 다르다 — **오라클이 풍부**하다. 그래서 lens가 주력이 아니라, 하드 오라클이 게이트고 lens는 보조다. (배경: `GOAL.md` 원칙 1~4)

## 절대 규칙
- **lens는 게이트가 아니다.** 머지 가능 판정 = 하드 오라클 pass + oracle-adequacy. lens findings는 advisory.
- **수렴 ≠ 검증.** "lens가 더 못 찾음"을 통과 근거로 쓰지 마라.
- **oracle-subtraction.** 오라클이 보는 것(동작/타입/테스트/회귀)은 lens에게 시키지 마라. lens는 오라클이 *구조적으로 못 보는 것*만.

## 입력
- diff 또는 변경된 파일 + 대상 repo (오라클 실행에 필수).

## 단계 상태 (lifecycle 척추)
**진입 시** 대상 repo의 `.cidd/state.md`에서 `build: done`인 active slug의 build 리포트·diff를 읽는다(있으면). `handoff.build→review`에 적힌 "adequacy 미측정 / conformance 우려" unit에 **오라클·lens를 우선 겨눈다**(build이 약하다고 자백한 곳). build 없이 직접 호출된 diff면 그냥 진행. **완료 시** 갱신: `review: done → .cidd/reviews/<slug>.md`, `gate: pass|fail`. **끝나면 `AskUserQuestion` 결정 메뉴(accept/refine/back/pause/abandon)로 고른 전이를 자동 적용**(README "단계 끝 = 결정 메뉴") — accept면 gate pass 시 `stage: done`(+ history), fail이면 refine/back. (`updated`는 세션이 박음.)

## 절차
1. **① Hard oracle (먼저, Bash로 실제 실행).** 프로젝트의 test / type-check / lint / build / 해당되면 실행을 돈다. 결과는 추측이 아니라 실행 출력. 실패가 있으면 그게 1차 게이트 결과 — 실패 목록을 보고하고, 이게 머지 차단 사유다.
2. **② Oracle-extension (가능하면).** coverage로 변경 라인이 덮였나 본다(미덮이면 "초록불 불충분"). mutation 도구가 있으면 핵심 변경에 돌려 "테스트가 *옳은 이유로* 초록인지" 본다. 도구 없으면 "adequacy 미측정"으로 명시(거짓 안심 금지).
3. **③ Lens fan-out (advisory).** review-lens를 3축(oracle-subtraction·task-relevance·diversity)으로 **3~5개 선택**해 병렬 호출(`Agent`, haiku). 각 lens는 ①②가 못 보는 것만. failure-mode lens가 의심 지점을 내면 *판정하지 말고* ②(테스트/mutation)로 내려 확인 — **lens proposes, oracle disposes.**
4. **④ (선택) 정리.** `completeness-critic`으로 어느 축도 안 본 사각지대. lens findings 간 긴장은 `friction-extractor`로 묶어도 됨(advisory).
5. **출력 = 리뷰 리포트.** 사용자에게 인라인으로 보여주고, **`.cidd/reviews/<slug>.md`에 저장**한다(`<slug>` = PR/브랜치/변경 이름, 없으면 `<날짜>-<n>`). 리포트가 머지 판정의 근거 기록이므로 파일로 남긴다. 인라인·파일 둘 다 같은 내용.
   - **다이어그램(필수, 리포트 맨 위) = layer 통과 flow**: 변경이 닿는 경로를 **계층(layer)을 가로지르는 flow**로 그려라(네가 직접). 왼쪽 축에 layer 라벨(`[Route] [Service] [Infra] [External] [Worker]` 등), flow는 위→아래로 layer를 가로지르며 내려간다(화살표에 무엇이 흐르나 라벨). 변경 노드 `*` + 그 노드를 쓰는 소비자(blast radius)까지. **각 노드에 오라클 상태**: `✅`(테스트 덮음) / `⚠️`(미덮임·미측정). 오라클 공백이 *어느 layer*에 있는지 그림에서 바로 보인다.
     ```
     예)
     [Route]     POST /checkout* ✅ ──order──┐
     [Service]   OrderService* ⚠️미덮임 ──▶ PaymentGateway* ⚠️ ──▶
     [External]  Ledger ✅
                 △ Service layer 변경분 커버리지 0 — 게이트 주의
     ```
   - **GATE**: 하드 오라클 pass/fail + adequacy(coverage/mutation 또는 "미측정") + 실제 실행 출력 인용. ← 머지 판정은 여기서만.
   - **ADVISORY**: lens findings (각 "오라클이 못 보는 이유" 포함). 명시: 이건 게이트 아님.

## review-lens 선택 풀 (도출용, 다 켜는 게 아님)
- `rlens-maintainability` — 6개월 뒤 고칠 사람 관점
- `rlens-convention` — 기존 패턴 일치 (repo 필수)
- `rlens-failure-mode` — 초록불이 옳은 이유인가 (제안만 → 오라클이 판정)
- `rlens-abstraction-fit` — 경계/추상이 옳은가
- `rlens-security-logic` — SAST가 못 잡는 로직 권한 (auth/입력 닿을 때만)
- `rlens-readability` — 호출부/시그니처 인간공학

## 비용·정직성
- 서브에이전트 haiku. lens 3~5개로 제한.
- 오라클 결과는 *실행 출력*으로 보고 — LLM 추측을 실행 위에 얹지 마라.
- repo가 없어 ①②를 못 돌면, "오라클 미배선 — 이건 advisory 리뷰일 뿐, 게이트 아님"을 리포트 **맨 위에** 경고로 박아라.
