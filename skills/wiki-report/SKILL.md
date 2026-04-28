---
name: wiki-report
description: `~/.reports/sessions.log` + `~/.reports/baseline.json` + `gh` PR 메타데이터를 입력으로 받아 Confluence 부모 페이지 아래 5장 트리(AI 도입 요약 / 성과 지표 / 기술 향상 / 작업 사례 / 한계와 다음 단계)를 생성한다. 1차 독자는 기획자(비개발 청중). 모든 수치는 Claude 도입 전 baseline 대비 증감률 + 시간/비용 환산 + caveat 동반. "위키 보고서", "wiki 업로드", "컨플루언스 보고서" 요청에 사용.
---

# Wiki Report

## 입력
- `~/.reports/sessions.log` — Stop 훅이 세션 종료마다 append 하는 블록 로그.
  - 블록 구분자: `---`
  - 필드: `session_id, ts_start, ts_end, repo, branch, head, tools, messages, tokens_in/out, cache_create, cache_read, commits, lines_added, lines_deleted, issues, summary`
- `~/.reports/baseline.json` — Claude 도입 전 기준선 (수기 작성). 필수 필드:
  - `weekly_commits, weekly_issues_closed, weekly_lines_added, weekly_lines_deleted, weekly_lines_changed, avg_issue_lead_time_hours`
  - 권장 추가 필드: `hourly_rate_krw` (없으면 50000), `tool_cost_krw_per_month` (없으면 140000 — Max 5x $100 환산), `productivity_conversion_factor` (없으면 0.7)
- `gh` CLI — 본인 PR 메타데이터(`opened_at`, `merged_at`, `first_review_at`) 수집용.

`weekly-claude-report` 등 외부 MD 보고서에 의존하지 않는다.

## 작성 원칙
1. **분석 단위로 페이지를 나눈다** — 청중별이 아닌 주제별. 5장 트리 고정.
2. **모든 수치에 baseline 대비 증감률 + 판정** — ✅ 개선 / ⚠️ 악화 / ➖ 변동없음. 기간이 1주 미만이면 baseline 을 `(기간 일수 / 7)` 로 prorate.
3. **시간/비용 환산 필수** — 기획자가 "그래서 회사에 얼마 이득"에 답을 얻도록.
4. **caveat 3개 필수** — LOC 함정 / 개인 ≠ 팀 역설 / 코드 품질 모니터링. 이게 빠지면 신뢰도 무너진다.
5. **참조 링크 누락 금지** — Jira·GitHub 커밋·PR 풀링크.
6. **성능 향상은 "왜 빨라지나" 한 줄 근거**.

## 실행 절차

### 1. 입력 수집
- 기간 결정: 인자 없으면 이번 ISO 주(`date +%G-W%V`) 월~일. 인자 있으면 `YYYY-Www` 또는 `YYYY-MM-DD~YYYY-MM-DD`.
- 부모 pageId: 인자에서 `pageId=NNN` 패턴 추출. 없으면 사용자에게 질의.
- 시급/도구비/전환계수: `baseline.json` 에서 우선 읽고, 없으면 위 기본값 사용. 본문에 "가정값 명시" 필수.

### 2. sessions.log 파싱
`---` split → 기간 내 `ts_end` 만 채택 → 같은 `session_id` 중복 시 ts_end 최신 1건만 남김.

집계:
- `total_sessions` (블록 수, 중복 제거 후)
- `total_commits` (모든 `commits` 해시 distinct count)
- `total_lines_added / total_lines_deleted / total_lines_changed`
- `issues_set` (모든 `issues` 유니온)
- `repos_set` (등장한 `repo` distinct, 셸 cwd `ParkJinHyeong` 같은 비저장소는 제외)
- 토큰 합계 → `cache_hit_rate = cache_read / (cache_read + cache_create + tokens_in)`
- `avg_session_minutes`, `avg_messages`, `avg_tools`
- `issue_lead_time_hours[i]` = (해당 이슈 첫 ts_start ~ 마지막 ts_end). 평균 → `actual_lead_time_hours`

### 3. PR 메타데이터 수집 (`gh` CLI)
```bash
gh pr list --search "author:@me created:{ts_start}..{ts_end}" --state merged \
  --json number,url,title,createdAt,mergedAt,reviews,additions,deletions \
  --repo mailplug-inc/{repo}
```
대상 저장소: `repos_set` 에 등장한 mailplug-inc 저장소만 순회.
산출:
- `pr_cycle_time_hours` = avg(`mergedAt - createdAt`)
- `pr_first_review_hours` = avg(`reviews[0].submittedAt - createdAt`)
- `merged_pr_count`, `total_pr_additions`, `total_pr_deletions`
- gh 호출 실패 시 본문에 "PR 메타데이터 수집 실패 — sessions.log 만으로 산정"이라 명시하고 진행.

### 4. baseline 비교 + 환산
prorate 계수 `s = period_days / 7`.
- `expected_commits = baseline.weekly_commits * s` → `commits_delta_pct = (total_commits - expected) / expected * 100`
- `expected_issues / expected_lines_changed` 동일.
- 리드타임은 prorate 안 함: `lead_delta_hours = actual_lead_time_hours - baseline.avg_issue_lead_time_hours`.

ROI 계산:
```
weekly_saved_hours = max(0, baseline.avg_issue_lead_time_hours - actual_lead_time_hours) * issues_processed / 7
adjusted_saved_hours = weekly_saved_hours * productivity_conversion_factor
weekly_saved_value_krw = adjusted_saved_hours * hourly_rate_krw
weekly_tool_cost_krw = tool_cost_krw_per_month / 4.33
roi_pct = (weekly_saved_value_krw - weekly_tool_cost_krw) / weekly_tool_cost_krw * 100
```
보수성 확보를 위해 productivity_conversion_factor 0.7 default.

### 5. 기술 근거 보강 (선택)
주요 핫픽스 해시(예: WM-XXXXX 가 `issues` 에 잡힌 세션의 `commits`)는 **codebase-analyzer** 에이전트에 diff 요약 의뢰 — Before / After / 효과 3단. 사례 페이지에 narrative 로 사용.

### 6. 5장 트리 페이지 작성

부모 pageId 아래 다음 5장을 순서대로 생성. 부모-자식 위치는 **모두 부모 pageId 직속** (자식끼리 중첩 안 함). 제목은 아래 그대로 사용.

#### [01] AI 도입 요약 (YYYY-MM-DD~MM-DD)
1쪽 Executive Brief. 기획자 30초 스캔용.

```markdown
## 한 줄 결론
도입 N일차, 이슈 처리 X% 가속·주간 약 H시간 절감 추정. ROI ≈ R%. (가정값: 시급 W원/h, 전환계수 0.7)

## 핵심 4지표 (Claude 도입 전 vs 이번 기간)
| 지표 | Baseline (prorated) | 이번 기간 | 증감 | 판정 |
|---|---:|---:|---:|:---:|
| 처리 이슈 수 | ... | ... | +X% | ✅ |
| 평균 이슈 리드타임 (h) | ... | ... | -H시간 | ✅ |
| PR 사이클 타임 (h) | ... | ... | ... | ... |
| 주간 커밋 수 | ... | ... | +X% | ✅ |

## 비용 환산 (보수적 추정)
- 절감 시간 × 시급 × 전환계수 0.7 = **약 K원/주**
- Max 5x 도구비: **약 32,300원/주** (월 140,000원 ÷ 4.33)
- ROI: **약 R%**

## 한계 (1줄)
LOC·커밋 수는 참고치. 개인 지표 ≠ 팀 산출. 코드 품질은 별도 모니터링 중.

## 상세 페이지
- [성과 지표](URL)
- [기술 향상](URL)
- [작업 사례](URL)
- [한계와 다음 단계](URL)
```

#### [02] 성과 지표
정량 Before/After 표 + 환산 계산 노출.

```markdown
## 측정 기간
YYYY-MM-DD ~ MM-DD (N일). Baseline: `~/.reports/baseline.json` 의 14주 평균.

## DORA 4지표
| 지표 | Baseline | 이번 기간 | 변화 | 판정 |
|---|---:|---:|---:|:---:|
| 배포 빈도 (주당 merged PR) | ... | ... | ... | ... |
| 변경 리드타임 (PR open→merge h) | ... | ... | ... | ... |
| 이슈 처리 리드타임 (h) | ... | ... | ... | ... |
| 변경 실패율 (주의: 별도 측정 필요) | n/a | n/a | n/a | ➖ |

## 처리량 지표
| 지표 | Baseline | 이번 기간 | 증감 | 판정 |
|---|---:|---:|---:|:---:|
| 주간 커밋 수 | ... | ... | +X% | ✅ |
| 주간 처리 이슈 수 | ... | ... | +X% | ✅ |
| 변경 라인 (참고치) | ... | ... | ... | ➖ |

## 시간/비용 환산
- 가정값: 시급 W원/h, 전환계수 0.7, 도구비 월 T원
- 절감 시간 = (baseline 리드타임 - 실제 리드타임) × 처리 이슈 수 / 7 = **A h/주**
- 보정 절감 시간 = A × 0.7 = **B h/주**
- 절감 가치 = B × W = **K 원/주**
- 도구비 = T / 4.33 = **C 원/주**
- ROI = (K - C) / C × 100 = **R%**

## Claude 활용 효율
| 지표 | 값 |
|---|---:|
| 총 세션 | N |
| 캐시 히트율 | XX.X% |
| 평균 세션 길이 (분) | ... |
| 세션당 커밋 | ... |
| 처리 토큰 (입력+출력+캐시) | ... |
| 실질 과금 토큰 | ... |
```

#### [03] 기술 향상
기능·아키텍처·성능 변화. 개발자가 검증 가능한 톤. 기획자도 "이런 게 좋아졌구나" 정도는 읽도록.

```markdown
## 기간 핵심 변경 요약
[2~4 항목, 각 1~2 문장]

## 영역별 변경
### 1. [영역 이름 — 예: 캐시 아키텍처]
- 변경: [무엇을 바꿨는가]
- Before: [이전 동작]
- After: [현재 동작]
- 효과: [왜 빨라졌나/안전해졌나 — 한 문장 근거]
- 근거 커밋: [GitHub 링크]

### 2. ...

## 멀티 저장소 영향
| 저장소 | 변경 요약 | 다른 저장소에 미친 영향 |
|---|---|---|
| gw-member | ... | wm70-api / wm60 |
| ... | | |

## 성능 향상의 근거 (왜 빨라지는가)
| 변경 | 빨라지는 이유 |
|---|---|
| ... | ... |
```

#### [04] 작업 사례
이슈 단위 narrative. 4~6건. 협업 가치(PR 설명·Confluence 동기화·핸드오프)는 여기에 녹임.

```markdown
## 사례 1 — WM-XXXXX [한 줄 제목]
**문제**: [무엇이 안 됐는가, 평이한 언어]

**Claude 활용**: [어떤 식으로 활용했는가 — 예: 4개 저장소 교차 디버깅, PR 설명·위키 동시 업데이트, 핸드오프로 컨텍스트 유지]

**결과**:
- N세션, M커밋, +A/-D 라인, 리드타임 H시간
- 영향 저장소: ...
- PR: [링크]
- 참고 위키: [링크]

## 사례 2 — ...
```

#### [05] 한계와 다음 단계
caveat 3개 + 향후 측정 계획. 이게 빠지면 신뢰도 무너진다.

```markdown
## 측정의 한계 (반드시 함께 읽어주세요)

### 1. 라인 수·커밋 수는 생산성 지표가 아닙니다
GitClear 2025 (211M 라인 분석)는 AI 도구 사용 후 코드 클론이 48% 증가했음을 보고합니다. 본 보고서의 LOC 수치는 **참고용**이며, 핵심 KPI 는 PR 사이클 타임·이슈 리드타임·결함 탈출률입니다.
- 출처: https://www.gitclear.com/ai_assistant_code_quality_2025_research

### 2. 개인 지표가 팀 산출과 같지 않습니다 (AI 생산성 역설)
Faros AI 600+ 조직 분석에서 AI 사용 개발자의 PR 병합은 +98% 늘었지만 조직 단위 DORA 지표 변화는 유의미하지 않았습니다. 리뷰 병목이 발생할 수 있습니다.
- 출처: https://www.faros.ai/blog/ai-software-engineering

### 3. 단기 속도 ≠ 장기 코드 건전성
METR 2025 무작위 대조 시험에서 숙련 개발자가 AI 사용 시 평균 19% 느렸으나 본인은 빨라졌다고 인식한 사례가 있습니다. 코드 리뷰 강화 정책을 병행하고 있으며 결함 탈출률은 분기 단위로 모니터링합니다.
- 출처: https://www.infoworld.com/article/4061078/the-productivity-paradox-of-ai-assisted-coding.html

## 다음 측정 계획
- [ ] 결함 탈출률 도입 — 배포 후 N일 내 신고된 버그 수 / 배포 건수
- [ ] 코드 재작업률 (churn) 도입 — 커밋 후 2주 내 수정된 라인 비율
- [ ] PR 리뷰 시간 별도 측정 — 개인 가속이 팀 병목으로 전이되는지 감시
- [ ] 다음 분기 재측정 일정: YYYY-MM-DD

## 다음 N주/N개월 작업 항목
- [ ] WM-XXXXX
- [ ] ...
```

### 7. Confluence 게시
`mcp__mailplug-atlassian__confluence_create_page`:
- `parent_id`: 위에서 결정한 부모 pageId
- `title`: 위 5장 제목 그대로 (`AI 도입 요약 (YYYY-MM-DD~MM-DD)` / `성과 지표` / `기술 향상` / `작업 사례` / `한계와 다음 단계`)
- `content_format`: `markdown`
- 게시 순서: [02] → [03] → [04] → [05] → [01] (요약을 마지막에 만들면서 자식 페이지 URL 을 본문에 채워 넣는다)
- 같은 부모 아래 같은 제목이 이미 있으면 `confluence_search` 로 찾고 `confluence_update_page` 로 전환.

### 8. 산출물 반환
- 5장의 페이지 URL 목록.
- 한 줄 요약 (사용자 피드백용).

## 링크 컨벤션
| 유형 | URL 패턴 |
|---|---|
| Jira 티켓 | `https://jira.mailplug.co.kr/browse/{TICKET-ID}` |
| GitHub 커밋 | `https://github.com/mailplug-inc/{repo}/commit/{hash}` |
| GitHub PR | `https://github.com/mailplug-inc/{repo}/pull/{number}` |
| Confluence 페이지 | `https://wiki.mailplug.co.kr/confluence/pages/viewpage.action?pageId={id}` |

## 에이전트 선택
| 에이전트 | 용도 |
|---|---|
| codebase-analyzer | 주요 커밋 Before/After/효과 3단 서술 |
| general-purpose | gh CLI / Jira MCP 다중 호출이 필요한 메타데이터 수집 |

## 품질 체크리스트
- [ ] 5장 모두 부모 pageId 직속으로 생성되었는가
- [ ] 1쪽 요약이 한 줄 결론 + 4지표 표 + 비용 환산 + 한계 1줄을 모두 포함하는가
- [ ] 모든 수치에 baseline 대비 증감률·판정이 붙었는가
- [ ] ROI 계산에 가정값(시급·전환계수·도구비)이 명시되었는가
- [ ] caveat 3개가 [05] 페이지에 각각 출처 링크와 함께 들어갔는가
- [ ] Jira·커밋·PR 풀링크가 누락 없이 포함되었는가
- [ ] 협업 가치(PR 설명·위키·핸드오프)가 [04] 사례에 narrative 로 녹았는가
- [ ] gh CLI 실패 시 그 사실이 본문에 명시되었는가
