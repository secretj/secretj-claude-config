---
name: wiki-report-evolve
description: wiki-report 스킬 자체를 매주 자가 진화시키는 메타 루프. 매주 화요일 09:30 KST(wiki-report cron 발행 90분 후) launchd 자동 실행. 직전 주 발행된 5장 보고서의 정정 패턴·자가 체크리스트 미통과 항목·외부 트렌드(매월 첫 화요일만)를 입력으로 받아, 안전 영역(품질 체크리스트·약어 풀어쓰기·caveat 출처 풀)은 SKILL.md에 자동 적용하고, 위험 영역(작성 원칙·페이지 책임·페이지 템플릿 구조)은 인덱스 자식 "스킬 개선 제안 YYYY-MM-DD" 페이지에 누적해 사용자 승인을 기다린다. 모든 자동 변경은 ~/.claude-backup/wiki-report/ 에 사본 보관(git 대체). 호출 키워드: "스킬 자가 진화", "wiki-report 회고", "/wiki-report-evolve".
---

# Wiki Report Evolve

wiki-report 스킬이 사용자 손이 닿지 않아도 매주 스스로 탐구·피드백·발전하도록 만드는 자가 진화 메타 루프.

## 호출 가정

매주 화요일 09:30 KST. wiki-report cron(08:00) 이 직전 주(월~일) 의 5장 보고서를 발행한 90분 후. launchd `com.parkjinhyeong.wiki-report-evolve.plist` 가 자동 실행.

## 안전 장치 (먼저 읽어주세요)

**자동 진화 루프의 가장 큰 위험은 "검증 안 된 자가 변경이 SKILL.md 를 망가뜨리고 다음 보고서 품질을 떨어뜨리는 무한 드리프트"** 입니다. 그래서 4가지 안전 장치를 박았습니다.

| 장치 | 무엇을 막나 |
| --- | --- |
| **2주 연속 패턴만 명시화** | 일회성 이상치로 SKILL.md 비대화 방지 |
| **자동 적용 영역을 안전 영역으로 한정** | 페이지 구조·책임 같은 큰 변경은 사용자 승인 필요 |
| **모든 자동 변경이 `~/.claude-backup/wiki-report/<timestamp>/` 에 사본 보관** | 망가지면 1줄로 복원 가능 (git repo 가 아니라 파일 사본) |
| **인덱스 페이지에 매주 진화 로그 누적** | 변경 이력이 보고서로 가시화 |

### 자동 적용 영역 vs 제안 영역

| 자동 적용 (안전) | 제안 만 (위험) |
| --- | --- |
| `SKILL.md` 의 품질 체크리스트 항목 추가 (append 만, 삭제·수정 금지) | 작성 원칙 1~11 변경 |
| `caveat-sources.json` used_urls 풀 갱신 | 페이지 책임 분리 변경 |
| `SKILL.md` "비개발 청중 톤" 약어 풀어쓰기 표 row 추가 (append 만) | 페이지 템플릿 구조 (단계 8) 변경 |
| 인덱스 페이지 "보고서 목록" 자동 갱신 | 새 페이지·새 섹션 신설 |

## 입력 수집

1. **인덱스 페이지의 자식 트리** (`confluence_get_page_children` parent_id=212478414, limit=20) — 가장 최근 "M월N주차 사용 분석" 컨테이너 1건 + 직전 1건 (총 2주치) 식별.
2. **두 컨테이너의 5장 자식 + 자식별 version 이력** — 각 자식 페이지의 `confluence_get_page` 로 본문·version·version_comment 회수. (Confluence API 가 version 이력을 별도로 노출하지 않으면 현 version 의 comment 만으로 우회.)
3. **직전 자가 진화 루프 결과 페이지** — 인덱스 자식 중 "스킬 개선 제안" 으로 시작하는 가장 최근 페이지 1건 (있으면).
4. **현재 SKILL.md 본문** (`~/.claude/skills/wiki-report/SKILL.md`).
5. **caveat 출처 풀** (`~/.claude/skills/wiki-report/caveat-sources.json` 의 `used_urls`).
6. **(매월 첫 화요일만) 외부 트렌드** — `web-search-researcher` 에이전트 호출.

## 실행 절차

### 단계 1: 사용자 정정 패턴 분석

각 자식 페이지의 `version_comment` 텍스트를 모아 동사 추출:

```
"v3 — PR 리뷰 narrative 제거" → 동사: "제거", 대상: "PR 리뷰 narrative"
"v4 — 비개발 청중을 위해 톤 정리" → 동사: "톤 정리", 대상: "전체"
"v5 — AI 활용 인프라 지표 신설" → 동사: "신설", 대상: "AI 활용 인프라"
```

직전 자가 진화 결과 페이지에서 같은 패턴을 검색해 **2주 연속 등장하면 SKILL.md 명시화 후보로 등록**:

* 동사 + 대상 조합이 두 주 모두 등장 → 후보 점수 +2
* 한 주만 등장 → 후보 점수 +1 (다음 주 재검토 대기)

점수 ≥ 2 인 항목만 단계 4 의 "자동 적용 후보" 또는 "제안 후보" 로 분류.

### 단계 2: 자가 체크리스트 진단

가장 최근 발행 보고서 5장이 SKILL.md 품질 체크리스트(현재 17 항목) 를 통과했는지 자동 검증:

| 체크리스트 항목 | 자동 검증 방법 |
| --- | --- |
| "[02] 에 본인 commit 표가 있는가" | `confluence_get_page` 로 [02] 본문 → 표 패턴 grep (`\| 일시 \| 저장소 \| 커밋 \|`) |
| "[02] 에 AI 활용 인프라 지표 표가 있는가" | [02] 본문 grep (`AI 활용 인프라 지표`) |
| "caveat 3개 출처 URL 이 직전 주차와 다른가" | [05] 본문에서 URL 추출 → caveat-sources.json `used_urls` 와 교집합 0인지 검증 |
| "비개발 청중 톤 인가" | 5장 본문에서 약어(`ts_end`, `carryover`, `P0 패턴`) grep → 0건이면 통과 |
| ... 나머지 항목 | 동일 패턴 |

통과 못 한 항목 = 다음 주차 보고서가 자동 회수할 수 있도록 **개선 제안 페이지에 명시**.

### 단계 3: 외부 트렌드 보강 (매월 첫 화요일만)

`date '+%V'` 의 ISO 주차 번호와 `date '+%m'` 의 월 비교로 "매월 첫째 화요일" 판정. 첫째 화요일이면 `web-search-researcher` 에이전트 호출:

```
Find 1 recent (last 30 days) study/blog/benchmark for each topic, exclude these URLs: {caveat-sources.json used_urls}.
Topics:
1) AI coding productivity measurement (DORA / DPE / SPACE 새 트렌드)
2) AI generated code quality metrics (defect escape rate / churn / rework)
3) Individual vs team AI productivity (last 30 days new evidence)
Return: { topic, url, 1-line summary, why credible, published date }
```

결과를 `~/.claude/skills/wiki-report/caveat-candidates.json` 에 누적 (`pending_urls` 배열). wiki-report 가 다음 화요일 caveat 갱신할 때 우선 후보로 사용.

### 단계 4: 개선 제안 페이지 작성

인덱스 페이지(212478414) 자식으로 **"스킬 개선 제안 YYYY-MM-DD"** 페이지 생성 (`confluence_create_page`).

본문 템플릿:

```markdown
## 이 페이지가 무엇인가

`wiki-report-evolve` 가 매주 화요일 09:30 KST 에 자동 생성하는 자가 진화 회고 페이지. 직전 주(M월N주차) 보고서를 회고해 자동 적용된 변경 + 다음 주차에 회수할 제안을 누적합니다.

## 자동 적용 (안전 영역, 적용 완료)

| 변경 | 적용 위치 | 백업 위치 |
| --- | --- | --- |
| ... | ... | ... |

## 제안 (위험 영역, 사용자 승인 대기)

다음 주차 wiki-report 가 직전 주차 [한계] 회수할 때 함께 회수해 적용 검토.

| 후보 | 근거 (몇 주 연속 등장) | 영역 |
| --- | --- | --- |
| ... | 2주 연속 (4월6주차 v3, 5월1주차 v?) | 작성 원칙 |

## 자가 체크리스트 진단

직전 주차 발행 보고서 5장의 SKILL.md 품질 체크리스트 통과 결과:

| 체크리스트 항목 | 통과 | 비통과 시 다음 주 보강 계획 |
| --- | --- | --- |
| ... | ✅/❌ | ... |

## 외부 트렌드 보강 (매월 첫 화요일만)

`web-search-researcher` 가 찾은 최근 30일 새 근거:

| 주제 | 출처 | 한 줄 요약 |
| --- | --- | --- |
| ... | URL | ... |

## 다음 자가 진화 루프

`wiki-report-evolve` 다음 실행: 다음 주 화요일 09:30 KST.
```

### 단계 5: 자동 적용 (안전 영역만)

#### 5-1. SKILL.md 백업

자동 적용 직전 항상 사본 보관:

```bash
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
mkdir -p ~/.claude-backup/wiki-report/$TIMESTAMP
cp ~/.claude/skills/wiki-report/SKILL.md ~/.claude-backup/wiki-report/$TIMESTAMP/SKILL.md
cp ~/.claude/skills/wiki-report/caveat-sources.json ~/.claude/skills/wiki-report-evolve/SKILL.md ~/.claude-backup/wiki-report/$TIMESTAMP/ 2>/dev/null
```

#### 5-2. 안전 영역 변경 적용

**append-only** 패턴으로만 (기존 항목 수정·삭제 절대 금지):

* 품질 체크리스트 항목 추가: `Edit` 으로 마지막 `- [ ]` 항목 뒤에 새 항목 append.
* 약어 풀어쓰기 표 row 추가: 작성 원칙 10번 표의 마지막 row 뒤에 append.
* `caveat-sources.json` `used_urls` 갱신: 직전 주차 [05] 의 새 URL 5개 (caveat 3개 + 결함 탈출률 + churn) 를 풀에 추가.

#### 5-3. 인덱스 페이지 "보고서 목록" 자동 갱신

인덱스 페이지(212478414) 본문의 "보고서 목록" 섹션에 직전 주차 컨테이너 row 추가 (이미 있으면 skip).

### 단계 6: 인덱스 페이지에 진화 로그 한 줄 추가

인덱스 페이지(212478414) 본문의 "자동화" 섹션 아래에 "자가 진화 로그" 표 1행 append:

| 일자 | 자동 적용 | 제안 | 외부 트렌드 검색 | 제안 페이지 |
| --- | --- | --- | --- | --- |
| 2026-05-12 | ✅ N건 | 🔍 M건 | (Y/N) | [링크] |

## 산출물

* **자동 적용 영역** SKILL.md / caveat-sources.json / 인덱스 페이지 "보고서 목록" 갱신 — 사본 `~/.claude-backup/wiki-report/<timestamp>/` 에 보관
* **제안 페이지** 신규 생성 (인덱스 자식, 제목 "스킬 개선 제안 YYYY-MM-DD")
* **인덱스 페이지** 진화 로그 row 1행 append
* **stdout 요약** (launchd 로그 `~/.reports/cron-wiki-report-evolve.log` 에 누적)

## 실패 처리

* 외부 도구 호출 실패 (`web-search-researcher` / `confluence_*`) → 해당 단계 skip + 제안 페이지에 "단계 N 실패: 다음 주 재시도" 명시
* SKILL.md `Edit` 실패 → 백업 사본으로 복원 + 제안 페이지에 "자동 적용 실패: 사용자 검토 필요" 명시
* 첫 실행 (직전 자가 진화 결과 페이지 없음) → 단계 1 의 2주 연속 점수 매기기를 1주 단발 점수로 대체, 첫 실행이라 명시

## 호출 형식

* **자동**: launchd `com.parkjinhyeong.wiki-report-evolve.plist` 매주 화요일 09:30 KST
* **수동**: `/wiki-report-evolve` (사용자가 임시 실행 시)
