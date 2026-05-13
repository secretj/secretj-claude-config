---
name: build-service
description: 7개 subagent(planner/designer/architect/developer/infra/qa/security)를 PM 오케스트레이션으로 협업시켜 신규 서비스를 0에서 구축하는 워크플로. 8 Phase 구조 (PRD → 분해 → 병렬 설계 → 정합 점검 → 구현 → 병렬 검증 → 최종 점검 → 사용자 보고), Phase 1·4·7에 사용자 승인 게이트, 재기획 루프 최대 10회. 병렬화 가능한 Phase 3·6은 단일 메시지에서 multiple Agent calls로 진짜 병렬 실행. 모든 산출물은 로컬 .build-service/ + Obsidian Vault dual-write. mailplug 외부 프로젝트는 일반 agent, mailplug/ 하위는 mailplug-* wrapper 사용. "신규 서비스 구축", "그룹웨어 만들어줘", "/build-service" 같은 요청에 사용.
---

# Build Service — 멀티 에이전트 오케스트레이션

당신은 **PM 오케스트레이터** 역할로 이 skill을 실행한다. 7개 subagent를 8 Phase 워크플로로 협업시켜 신규 서비스를 구축한다.

## 입력
- 도메인 / 서비스 컨셉 한 줄 (예: "그룹웨어", "협업툴", "가계부 앱")
- 선택: 제약 (기술 스택·예산·기간·타겟·차별화 의도)

## 핵심 규칙

### Agent 라우팅
- CWD가 `mailplug/` 하위면 → `mailplug-*` wrapper 사용 (`mailplug-planner`, `mailplug-developer` 등)
- 그 외 → 일반 agent (`planner`, `architect`, `developer`, `designer`, `infra`, `qa`, `security`)
- PM 자신은 일반 `pm` agent (또는 mailplug면 `mailplug-pm`)

### 병렬 실행 원칙
- 독립적인 작업은 **단일 메시지 안에 multiple Agent calls** — 진짜 병렬 (sequential X)
- 의존성 있는 작업만 sequential

### 사용자 승인 게이트 (3곳)
- **Phase 1 종료 후** — PRD 가정·차별화 가설 확인
- **Phase 4 재기획 루프 진입 직전** — 충돌·결손 진단 후
- **Phase 7 종료 후** — 최종 결과 사용자에 전달 전

각 게이트에서:
- 진단 + 옵션 제시
- 사용자 응답 대기 (자동 진행 X)
- "진행"/"수정"/"중단" 결정 받음

### 재기획 루프 제한
- Phase 4 (정합 점검)에서 발견된 결손·충돌이 있으면 planner에 재호출
- **최대 10회** — 10회 초과 시 자동 중단 + 사용자에 에스컬레이션
- 매 루프마다 카운터 +1, 직전 루프와 동일 결손이 반복되면 즉시 사용자 게이트 (deadlock 방지)

### 영속화 (이중 백엔드)
- 로컬: `.build-service/{YYYYMMDD}-{slug}/{phase}-{type}.md`
- Obsidian: `AI-Agents/{project}/build-service/{slug}/{phase}-{type}.md`
- 각 Phase 결과는 양쪽 dual-write
- 마스터 인덱스: `.build-service/{slug}/INDEX.md` — 모든 phase 산출물 링크 + 최종 결과

### 토큰 예산 관리
- 각 subagent 호출 시 명시적 출력 길이 제한 권고 (예: "report in under 500 words")
- Phase 5 (구현)는 가장 무거움 — developer 호출을 작은 단위로 분할
- Phase 4 루프에서 동일 컨텍스트 반복 전송 금지 — 차이만 전달

---

## 워크플로 8 Phase

### Phase 0 — 입력 수신·세션 초기화
1. 사용자 입력 파싱 (도메인·제약·차별화 의도)
2. 세션 ID 생성: `{YYYYMMDD-HHMM}-{도메인-slug}`
3. 작업 디렉토리: `.build-service/{session-id}/`
4. INDEX.md 초기화 (메타 + 각 phase 빈 슬롯)
5. Obsidian에 같은 주제 과거 build-service 검색 (`obsidian_search_notes "{도메인}"`)
   - 회수된 인사이트가 있으면 본문에 인용
6. 사용자에 워크플로 개요 1회 출력 (8 Phase + 게이트 위치 + 예상 호출 수)

### Phase 1 — 기획 (planner 단독)
**호출**: `Agent(subagent_type=planner)` 1회

**프롬프트 골자**:
```
신규 서비스 "{도메인}"의 PRD-mini를 작성해라.

요구:
- PRD-mini 10줄 내외 (목적·타겟·핵심 시나리오·성공지표·비스코프·제약·오픈이슈)
- 차별화 가설 표 (AI 템플릿 안 거부, 이 서비스만의 안 1-2개 + 근거)
- MoSCoW 우선순위 (Must / Should / Could / Won't)
- 모호 트리거 발동 시 가정 명시 + 꼬리질문 1-2개

산출물은 .plans/{slug}-prd.md 와 Obsidian dual-write.
응답은 5블록 형식. 본문 600단어 이내.
```

**출력 검증**:
- PRD-mini 7필드 모두 채워졌나
- 차별화 가설 ≥ 1개 (AI 템플릿 안 거부 명시)
- MoSCoW Must 항목 ≤ 5개 (사이드 프로젝트 가정)

→ **사용자 승인 게이트 1**:
```
[Phase 1 완료]
PRD-mini 요약: <1-2줄>
차별화 가설: <항목>
가정: <planner가 명시한 가정>
꼬리질문: <있으면>

진행 여부:
1. 그대로 진행
2. 가정 수정 (어떻게)
3. 중단
```

### Phase 2 — 분해 (PM 단독)
**호출**: 직접 PM 사고 (subagent 호출 X — PM이 본인 책임)

**작업**:
1. PRD의 Must 항목별로 작업 분해
2. 각 작업을 1개 이상 subagent에 매핑:
   - UI/UX 명세 필요 → designer
   - 코드 구현 필요 → developer
   - DB·외부 API·서버 필요 → infra (사전 환경 옵션)
   - 인증·세션·민감 데이터 → security (위협 모델 사전)
3. 의존성 그래프 작성 (어느 작업이 어느 작업 선행 필요)
4. **1태스크 ≤ 4h** 강제 (넘으면 추가 분해)
5. 산출: Task Breakdown Table → `.build-service/{slug}/02-breakdown.md`

**출력**: subagent별 작업 카드 + 의존성 그래프 (mermaid)

### Phase 3 — 병렬 설계 (designer · architect · infra · security 동시)
**호출**: **단일 메시지에서 4개 Agent calls 병렬**

```
Agent(designer, "Phase 2 분해 결과의 화면 N개 명세 + 11 mistake 자가검증 + 차별화 가설표. <컨텍스트>")
Agent(architect, "Phase 2 분해 결과의 도메인 모델(DDD) + 바운디드 컨텍스트 분리 + ADR + OpenAPI 발췌 + 도메인 다이어그램. <컨텍스트>. 이번 Phase는 설계만, 코드 구현은 Phase 5 developer.")
Agent(infra, "Phase 2 분해 결과의 환경 옵션 비교 (PaaS·VPS·DB·인증·스토리지). 단정 X. <컨텍스트>")
Agent(security, "Phase 2 분해 결과에 STRIDE 위협 모델 + 사이드 프로젝트 10가지 빈틈 점검. <컨텍스트>")
```

**모든 호출에 공통 첨부**: PRD 요약 (200단어), Phase 2 task breakdown 요약 (300단어), 세션 ID, 산출물 저장 경로

**출력 수집**: 4 산출물 → `.build-service/{slug}/03-{designer|architect|infra|security}.md`

### Phase 4 — 정합 점검 (PM 단독) + 재기획 루프
**작업** (PM 직접):
1. 4 산출물 교차 검증
2. 충돌·결손 검사:
   - 화면 명세 ↔ API 컨트랙트 불일치
   - 도메인 모델 ↔ 화면 입출력 불일치
   - infra 옵션 ↔ developer 기술 가정 불일치
   - security 위협 ↔ 미반영 항목
   - PRD 인수 기준 ↔ 산출물 매핑 결손
3. **루프 카운터** 확인 (최대 10회)
4. 결손 0건 → Phase 5로
5. 결손 ≥ 1건 → 재기획 루프

**재기획 루프**:
1. 결손 분류 (PRD 결손 / 설계 결손 / 외부 의존 결손)
2. 직전 루프와 동일 결손이면 → **즉시 사용자 게이트** (deadlock)
3. **사용자 승인 게이트 2** (루프 진입 직전, 첫 진입과 deadlock 진입에만):
   ```
   [Phase 4 — 정합 결손 발견]
   결손 N건:
   - <항목 1>
   - <항목 2>
   ...
   루프 카운트: K/10

   조치 옵션:
   1. planner에 재호출 (PRD 보강) — 자동 진행
   2. developer/designer/infra에 재설계 요청
   3. 사용자 직접 결정 (수동 수정)
   4. 중단
   ```
4. 결정에 따라 해당 agent 재호출 → Phase 4로 복귀
5. 루프 ≥ 10회 시 강제 중단 + 사용자에 전체 결손 + 추정 원인 보고

### Phase 5 — 구현 (developer 단독, 필요 시 분할)
**호출**: `Agent(developer)` — 작업 단위로 분할 호출 가능

**프롬프트 골자**:
```
Phase 3 architect 설계 + Phase 4 정합 통과한 명세를 코드로 구현해라.

대상: <작업 카드 1개 또는 묶음>
요구:
- DDD 4질문 통과 후 코드
- 단위·통합 테스트 직접 작성 (정상/실패/경계값/에러 path)
- 문서: ADR 갱신, OpenAPI 갱신, README 갱신
- 12가지 AI 템플릿 코드 패턴 자가검증
- 인수 기준 매핑 표 첨부

산출물 + 변경 파일 목록 보고.
응답 800단어 이내.
```

**완료 조건**:
- 모든 Phase 2 작업 카드 구현 완료
- 단위·통합 테스트 통과 (developer 자가 보고 + PM이 `pnpm test` / `pytest` Bash 실행해 재검증)
- 빌드·타입체크 통과 (PM Bash 검증)

**중간 검증**:
- 각 작업 카드 완료 시 PM이 빌드·테스트 실행
- 실패 시 같은 작업 카드 재호출 (최대 3회 → 4회째는 사용자 게이트)

### Phase 6 — 병렬 검증 (qa · security · designer 동시)
**호출**: **단일 메시지에서 3개 Agent calls 병렬**

```
Agent(qa, "Phase 5 구현 결과를 위험 기반 테스트로 검증. E2E (Playwright MCP) + 접근성 + 회귀 매트릭스 + 릴리스 게이트(Go/No-Go). <세션 ID>")
Agent(security, "Phase 5 구현 결과를 12 패턴 + STRIDE + 최신 CVE 동적 회수로 점검. 의존성 audit + secret 스캔 포함. <세션 ID>")
Agent(designer, "Phase 5 구현 결과를 시각 검증 — 11 mistake 진단 + 차별화 가설 반영도 + 독창성 평가 (AI 템플릿 디자인 거부). dev server 띄워 Playwright/스크린샷으로 확인. <세션 ID>")
```

**출력 수집**: 3 산출물 → `.build-service/{slug}/06-{qa|security|designer}.md`

### Phase 7 — 최종 점검 (PM 단독)
**작업** (PM 직접):
1. Phase 6 3 산출물 통합:
   - qa: Go / No-Go + P0/P1 결함 수
   - security: Critical / High 발견 수
   - designer: 독창성 평가 + 차별화 반영도
2. 최종 게이트 매트릭스:
   | 영역 | 기준 | 결과 |
   |---|---|---|
   | 인수 기준 매핑 | 100% | ✓/△/✗ |
   | qa Go | Go | ✓/✗ |
   | security Critical | 0건 | ✓/✗ |
   | designer 독창성 | "AI 템플릿 X" 판정 | ✓/✗ |
   | 단위·통합 테스트 | 통과 | ✓/✗ |
   | 빌드·타입체크 | 통과 | ✓/✗ |
3. 모두 ✓ → 최종 보고
4. 일부 ✗ → 사용자 게이트 (carve-out / 재작업 / 중단 결정)

→ **사용자 승인 게이트 3** (최종):
```
[Phase 7 완료]

게이트 매트릭스: <위 표>

미통과 항목: <있으면>
권고: <Go / No-Go / Conditional>

최종 결정:
1. 사용자에게 결과 전달 (현 상태로)
2. 미통과 항목 carve-out하고 release
3. 재작업 (Phase 4로 복귀)
4. 중단
```

### Phase 8 — 사용자 보고
**작업** (PM 직접):
1. 마스터 INDEX.md 완성 (모든 산출물 경로 + 게이트 결과)
2. Obsidian 마스터 노트 (`AI-Agents/{project}/build-service/{slug}/INDEX.md`) dual-write
3. 사용자에 5블록 응답:
   - **핵심 요약**: 무엇을 만들었고 게이트 결과
   - **가정 / 모호점**: 워크플로 중 가정·재기획 횟수
   - **본문**: 산출물 트리 (8 phase × 6 agent) + 핵심 결정 (ADR·차별화 가설) 요약
   - **요구사항 반영도**: 사용자 원 요청 ↔ 산출물 매핑
   - **다음 액션**: 배포 권고 / 운영 시 모니터링 포인트 / 회수 가능 인사이트 (Obsidian)

---

## 에러 처리

| 상황 | 조치 |
|---|---|
| subagent 호출 timeout | 1회 재시도 (요약 입력으로 단축) → 실패 시 사용자 게이트 |
| subagent가 위임 신호만 반환하고 산출물 X | PM이 명시적으로 위임된 다른 agent 호출, 결과를 원 agent에 전달해 재호출 |
| Phase 4 루프 동일 결손 반복 | 즉시 사용자 게이트 (deadlock) |
| Phase 5 빌드/테스트 4회 연속 실패 | 사용자 게이트 (근본 원인 추정 보고) |
| Obsidian MCP 오류 | 로컬 .build-service/만 dual fallback, 사용자에 안내 |
| Phase 6 qa No-Go + security Critical 발견 | Phase 7 게이트로 정상 진행 (사용자가 carve-out 결정) |

---

## 출력 양식 (Phase 8 최종)

```
═══════════════════════════════════════
[build-service "{도메인}"] 완료 보고
세션 ID: {session-id}
═══════════════════════════════════════

[1] 핵심 요약
- 무엇을 만들었나: <한 줄>
- 게이트 결과: <Go / No-Go / Conditional>
- 재기획 루프: K/10회

[2] 가정 / 모호점
- 채택된 가정: <리스트>
- 미해결: <있으면>

[3] 본문 — 산출물 트리
.build-service/{slug}/
  INDEX.md
  01-prd.md            (planner)
  02-breakdown.md      (PM)
  03-designer.md / 03-architect.md / 03-infra.md / 03-security.md
  04-reconciliation.md (PM, 루프 K회)
  05-implementation.md (developer, M개 작업 카드)
  06-qa.md / 06-security.md / 06-designer.md
  07-gate-matrix.md    (PM)

핵심 결정:
- ADR-001: <제목> (<선택>)
- 차별화: <한 줄>

[4] 요구사항 반영도
| 원 요청 | 반영 위치 | 반영도 |
|---|---|---|

[5] 다음 액션
- 배포 권고: → @infra (별도 호출 시)
- 모니터링: <핵심 지표>
- Obsidian 회수 인사이트: <건수>
- 후속 태스크: → @pm (별도 호출 시)

[저장됨]
- 로컬: .build-service/{slug}/
- Obsidian: AI-Agents/{project}/build-service/{slug}/
═══════════════════════════════════════
```

---

## 호출 예

```
사용자: /build-service "그룹웨어"
→ Phase 0 초기화 → Phase 1 planner → 게이트 1 → Phase 2 분해
→ Phase 3 병렬(4) → Phase 4 정합(루프 K회) → 게이트 2 (필요 시)
→ Phase 5 구현(분할) → Phase 6 병렬(3) → Phase 7 게이트 매트릭스
→ 게이트 3 → Phase 8 사용자 보고
```

각 게이트에서 사용자 응답 대기 — 자동 진행 X.
