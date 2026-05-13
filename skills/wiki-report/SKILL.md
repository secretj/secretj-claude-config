---
name: wiki-report
description: `~/.reports/sessions.log` + `~/.reports/baseline.json` + `gh` PR 메타데이터를 입력으로 받아 Confluence 보고서 인덱스 페이지 아래 "M월N주차 사용 분석" 컨테이너를 매주 새로 만들고 그 아래 5장 트리(AI 도입 요약 / 성과 지표 / 기술 향상 / 작업 사례 / 한계와 다음 단계)를 생성한다. 1차 독자는 기획자(비개발 청중). 매주 화요일 직전 주(월~일) 기간을 기본값으로 사용한다. 직전 주차의 [한계와 다음 단계] 페이지를 먼저 읽어 미해결 caveat·다음 측정 계획을 회수하고, 웹 서칭으로 추가 근거를 보강해 이번 보고서에 반영한다. 모든 수치는 Claude 도입 전 baseline 대비 증감률 + 시간/비용 환산 + caveat 동반. "위키 보고서", "wiki 업로드", "컨플루언스 보고서" 요청에 사용.
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
- **직전 주차 [한계와 다음 단계] 페이지** — `confluence_search` 로 인덱스 페이지(보고서 인덱스 pageId) 의 자식 트리에서 가장 최근 "한계와 다음 단계" 페이지를 찾아 `confluence_get_page` 로 본문 읽기.

## 작성 원칙
1. **분석 단위로 페이지를 나눈다** — 청중별이 아닌 주제별. 5장 트리 고정.
2. **모든 수치에 baseline 대비 증감률 + 판정** — ✅ 개선 / ⚠️ 악화 / ➖ 변동없음. 기간이 1주 미만이면 baseline 을 `(기간 일수 / 7)` 로 prorate.
3. **시간/비용 환산 필수** — 기획자가 "그래서 회사에 얼마 이득"에 답을 얻도록.
4. **caveat 3개 필수** — LOC 함정 / 개인 ≠ 팀 역설 / 코드 품질 모니터링. 이게 빠지면 신뢰도 무너진다.
5. **참조 링크 누락 금지** — Jira·GitHub 커밋·PR 풀링크.
6. **성능 향상은 "왜 빨라지나" 한 줄 근거**.
7. **피드백 루프 필수** — 직전 주차의 [한계와 다음 단계] 를 읽고, "다음 측정 계획" 체크리스트 항목별로 이번 주차의 후속 조치 상태(도입됨 ✅ / 진행 중 ⏳ / 미진행 ➖)를 [05] 페이지 상단에 명시한다. caveat 항목은 동일 출처를 답습하지 말고 **이번 주에 새로 검색한 근거 1건 이상**으로 갱신한다.
8. **페이지 책임 명확 분리** — [02]=숫자만 / [03]=메일플러그 코드 What·How / [04]=Why·협업 narrative. 같은 정보(예: 본인 commit 표) 를 여러 페이지에 중복 게재 금지 — **[02]에 단 한 번** 두고 [03]/[04] 는 링크 참조만.
9. **본인 author 직접 작업만 [03]/[04] 에 narrative 포함** — PR 리뷰 학습 내용은 [03]/[04] narrative 금지 (사용자 정정 지시 4월6주차 v3 정정 이력). PR 리뷰 활동은 [02] "AI 활용 인프라 지표" 표에서 정량으로만 카운트, [04] 사례 5 "Claude 작업 환경 개선" 에서 자동화 자산으로만 언급.
10. **비개발 청중 톤** — 약어·약식 표기 (`ts_end`, carryover, P0 패턴 등) 풀어쓰기 (예: `ts_end` → "세션 종료 시각", carryover → "이전 주에 시작해 이번 주에 끝난 세션"). 코드 식별자는 [03] 에만 깊게, 다른 페이지는 자연어 위주.
11. **본인 author commit 정확 산정** — sessions.log 의 hook 기록은 cwd 기반 git stat 이라 홈 디렉터리에서 시작된 세션의 본인 commit 이 모두 0 으로 잡히는 한계가 있음 (4월6주차 v3 정정 이력). **반드시 단계 4.5 의 git log --author 직접 조회로 보강**.

## 실행 절차

### 1. 입력 수집
- **기간 결정**: 인자 없으면 "직전 주(월~일)" 기본값. 매주 화요일 호출 가정. 인자 있으면 `YYYY-Www` 또는 `YYYY-MM-DD~YYYY-MM-DD` 또는 `M월N주차` 패턴.
- **인덱스 pageId 결정**: 인자에서 `pageId=NNN` 추출. 이 pageId 는 **연간/누적 인덱스 페이지** (예: "AI 사용 지표"). 이 아래에 매주 새 "M월N주차 사용 분석" 컨테이너를 만든다. 없으면 사용자 질의.
- **컨테이너 페이지 제목**: `{기간 시작 월}월{ISO 주차 - 해당 월 첫 주차 + 1}주차 사용 분석`. 예: 4/20~4/23 → "4월5주차 사용 분석" (사용자 표기 우선; 모호하면 기간 첫날 기준 ISO 주차로 결정 후 사용자에게 확인).
- 시급/도구비/전환계수: `baseline.json` 에서 우선 읽고, 없으면 위 기본값 사용. 본문에 "가정값 명시" 필수.

### 2. 직전 주차 회고 수집 (피드백 루프)
인덱스 pageId 의 자식 트리를 `confluence_get_page_children` 으로 나열 → `M월N주차 사용 분석` 컨테이너 중 최신을 1건 선택 → 그 자식 중 "한계와 다음 단계" 페이지를 `confluence_get_page` 로 markdown 변환해 읽음.

추출:
- `prev_caveats[]` — 3개 caveat 의 **출처 URL** 목록 (이번 주에 동일 URL 재사용 금지).
- `prev_next_measurements[]` — "다음 측정 계획" 체크리스트 항목 (text + 도입 여부).
- `prev_remaining_limits[]` — "본 보고서의 추가 한계" 표 행 중 "보완 계획" 컬럼이 진행 중인 항목.

회고 페이지를 찾지 못하면 (첫 보고서) `prev_*` 모두 빈 리스트로 두고 본문에 "초회 보고서 — 이전 회고 없음" 명시.

### 3. 웹 서칭으로 근거 보강
**web-search-researcher** 에이전트를 호출해 다음을 수집:
- caveat 3축(LOC 함정 / 개인 ≠ 팀 / 단기 속도 ≠ 품질) 각각에 대해 **최근 6개월 이내** 발표된 연구·블로그·벤치마크 1건씩.
- 직전 주차에 미해결로 남은 측정 항목(예: "결함 탈출률", "코드 재작업률")의 정의·도입 사례 1건씩.

**중복 회피 (필수)**:
- `~/.claude/skills/wiki-report/caveat-sources.json` 의 `used_urls` 풀을 읽어 **누적 used URL 모두 제외**. `prev_caveats[]` 만 제외하면 4주 전 출처가 다시 등장할 위험.
- (있으면) `~/.claude/skills/wiki-report/caveat-candidates.json` 의 `pending_urls` 가 `wiki-report-evolve` 의 매월 첫 화요일 외부 트렌드 검색 결과 — **우선 후보**로 사용.
- 본 주차 사용 URL 은 보고서 발행 후 `wiki-report-evolve` 가 자동으로 `caveat-sources.json` 에 추가 (수동 갱신 불필요).

에이전트 프롬프트 예시:
```
Find 1 recent (last 6 months) study/blog post for each topic, exclude these URLs: {caveat-sources.json used_urls 전체}.
Topics:
1) LOC/commit-count fallacy in AI-assisted coding
2) Individual vs team productivity paradox with AI coding tools
3) Short-term velocity vs long-term code health (defect escape rate, churn)
4) Defect escape rate definition and adoption case studies
5) Code rework / churn rate definition for AI-generated code
Return: { topic, url, 1-line summary, why credible }
```

수집 결과는 `new_evidence[]` 로 저장 → [05] caveat 본문에서 출처 갱신, [05] "이번 주 보강 근거" 섹션에 별도 표로 노출.

### 4. sessions.log 파싱
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

### 4.5. 본인 author commit 직접 조회 (sessions.log 보강 — 필수)

sessions.log 의 `commits` / `lines_added` / `lines_deleted` 는 hook 이 cwd 기반으로 `git log` 를 실행한 결과라 한계가 있다:
- 홈 디렉터리(예: `/Users/ParkJinHyeong`) 에서 시작된 세션은 cwd 가 git repo 가 아니라 `commits=-` / `lines=0` 으로 잡힘
- 본인이 직접 코딩한 commit 이 통계에서 누락될 위험 (4월6주차 v2 → v3 에서 WM-20701 wm70-api 3 commits 누락 발견)

**반드시 git log 로 직접 조회** 하여 본인 author commit 을 정확히 산정한다:
```bash
for repo in gw-member wm70-api gw-bbs wm60 setting-dev wm70-lib batch www-api gw-auth-server; do
  D="$HOME/Desktop/source/mailplug/$repo"
  if [ -d "$D" ]; then
    LOG=$(git -C "$D" log --since=YYYY-MM-DD --until=YYYY-MM-DD --all --no-merges \
      --pretty=format:"%h|%ai|%an|%s" 2>/dev/null \
      | grep -i 'secret\|qkrw\|박진형')
    [ -n "$LOG" ] && { echo "=== $repo ==="; echo "$LOG"; }
  fi
done
```

각 commit 의 라인 수는 `git show --stat <hash>` 로 보강.

산출:
- `own_commits[]` — (hash, ts, repo, ticket, message, lines_added, lines_deleted)
- `own_commits_count` — distinct hash 수
- `own_lines_added`, `own_lines_deleted`, `own_lines_changed`

이 결과가 [02] 의 "본인 commit 상세 표" + 처리량 지표 행("본인이 작성한 커밋 수", "본인이 변경한 코드 줄 수") 의 **신뢰 가능한 출처**다. sessions.log 의 `total_commits` / `total_lines_*` 는 단계 4 통계 (참고치) 로만 사용하고, **본인 author 산정은 본 단계 결과를 우선** 적용.

### 5. PR 메타데이터 수집 (`gh` CLI)
```bash
gh pr list --search "author:@me merged:{ts_start}..{ts_end}" --state merged \
  --json number,url,title,createdAt,mergedAt,reviews,additions,deletions \
  --repo mailplug-inc/{repo}
```
대상 저장소: `repos_set` 에 등장한 mailplug-inc 저장소만 순회.
산출:
- `pr_cycle_time_hours` = avg(`mergedAt - createdAt`)
- `pr_first_review_hours` = avg(`reviews[0].submittedAt - createdAt`)
- `merged_pr_count`, `total_pr_additions`, `total_pr_deletions`
- gh 호출 실패 시 본문에 "PR 메타데이터 수집 실패 — sessions.log 만으로 산정"이라 명시하고 진행.

### 6. baseline 비교 + 환산
prorate 계수 `s = period_days / 7`.
- `expected_commits = baseline.weekly_commits * s` → `commits_delta_pct = (total_commits - expected) / expected * 100`
- `expected_issues / expected_lines_changed` 동일.
- 리드타임은 prorate 안 함: `lead_delta_hours = actual_lead_time_hours - baseline.avg_issue_lead_time_hours`.

ROI 계산 (보수적, 1건당 절감 시간 가정):
```
weekly_pr_extra        = (merged_pr_count / period_days * 7) - baseline.weekly_issues_closed
weekly_saved_hours_raw = max(0, weekly_pr_extra) * D_per_pr_hours   # default D=4
adjusted_saved_hours   = weekly_saved_hours_raw * productivity_conversion_factor
weekly_saved_value_krw = adjusted_saved_hours * hourly_rate_krw
weekly_tool_cost_krw   = tool_cost_krw_per_month / 4.33
roi_pct                = (weekly_saved_value_krw - weekly_tool_cost_krw) / weekly_tool_cost_krw * 100
```
가정값(`D_per_pr_hours=4`, `productivity_conversion_factor=0.7`)을 본문에 반드시 노출. 리드타임 절감 기반 계산은 baseline 단위가 calendar h 일 때만 사용 가능 — 단위 불일치 시 PR 처리량 기반으로 대체.

### 7. 기술 근거 보강 (선택)
주요 핫픽스 해시(예: WM-XXXXX 가 `issues` 에 잡힌 세션의 `commits`)는 **codebase-analyzer** 에이전트에 diff 요약 의뢰 — Before / After / 효과 3단. 사례 페이지에 narrative 로 사용.

### 8. 페이지 트리 작성

**계층 구조**
```
인덱스 pageId (예: 212478414 "AI 사용 지표")
  └─ M월N주차 사용 분석 (이번 주 새로 생성하는 컨테이너)
       ├─ AI 도입 요약
       ├─ 성과 지표
       ├─ 기술 향상
       ├─ 작업 사례
       └─ 한계와 다음 단계
```

게시 순서:
1. **컨테이너 페이지 생성** (`confluence_create_page`, parent_id = 인덱스 pageId, title = `M월N주차 사용 분석`).
2. **5장 자식 페이지 생성** ([02] → [03] → [04] → [05] → [01] 순. parent_id = 컨테이너 pageId. 같은 parent 아래 동명 페이지가 있으면 `confluence_search` 후 `confluence_update_page` 로 전환).
3. [01] 본문 작성 시 [02]~[05] URL 을 채워 완성.

**컨테이너 페이지 본문** (간단)
```markdown
## {M월N주차} (YYYY-MM-DD ~ YYYY-MM-DD) Claude 도입 효과

### 자식 페이지
- [AI 도입 요약](URL01) — 1쪽 Executive Brief
- [성과 지표](URL02) — DORA 4지표·처리량·ROI 환산
- [기술 향상](URL03) — 영역별 변경
- [작업 사례](URL04) — N건 narrative + 협업 가치
- [한계와 다음 단계](URL05) — caveat·후속 계획·지난 주 회고

### 측정 기간
YYYY-MM-DD(요일) ~ YYYY-MM-DD(요일), N일.

### 한 줄 결론
[01] 의 한 줄 결론 동일.
```

#### [01] AI 도입 요약
1쪽 Executive Brief. 기획자 30초 스캔용.

```markdown
## 한 줄 결론
도입 N일차, 이슈 처리 X% 가속·주간 약 H시간 절감 추정. ROI ≈ R%. (가정값: 시급 W원/h, 전환계수 0.7, 1건당 절감 D h)

## 핵심 4지표 (Claude 도입 전 vs 이번 기간)
| 지표 | Baseline (prorated) | 이번 기간 | 증감 | 판정 |
|---|---:|---:|---:|:---:|
| 처리 PR/이슈 수 | ... | ... | +X% | ✅ |
| 작업 활성 이슈 수 | ... | ... | ... | ... |
| 주간 커밋 수 | ... | ... | +X% | ✅ |
| 변경 라인 수 (참고치) | ... | ... | ... | ➖ |

## 비용 환산 (보수적 추정)
- 추가 처리 PR × D h × 전환계수 0.7 = **H h/주**
- 절감 가치: **K 원/월** (시급 W 기준)
- Max 5x 도구비: **140,000 원/월** (월 ÷ 4.33 = 32,300 원/주)
- ROI: **약 R%**

## 한계 (1줄)
LOC·커밋 수는 참고치. 개인 가속이 팀 가속으로 자동 확장되지 않음(리뷰 병목). ROI 가정값 의존.

## 상세 페이지
- [성과 지표](URL)
- [기술 향상](URL)
- [작업 사례](URL)
- [한계와 다음 단계](URL)
```

#### [02] 성과 지표
**책임: 숫자만**. 코드 What·How 는 [03], 협업 Why 는 [04]. 본인 commit 표는 **이 페이지에 단 한 번** 만 게재 ([03]/[04] 는 링크 참조).

```markdown
## 이 페이지가 다루는 내용
이 페이지는 **수치만** 다룹니다. 코드 What·How 는 [기술 향상], 협업 narrative 는 [작업 사례].

## 측정 기간
YYYY년 M월 D일(요일) ~ M월 D일(요일), N일. 기준값(Claude 도입 전 14주 평균) 은 N일 길이로 환산 비교.

## DORA 4지표
| 지표 | 도입 전 (N일 환산) | 이번 주 | 변화 | 판정 |
|---|---:|---:|---:|:---:|
| 배포 빈도 (기간당 머지된 PR 수) | ... | ... | ... | ... |
| 변경 리드타임 (PR 오픈→머지 시간) | ... | ... | ... | ... |
| 이슈 처리 리드타임 (시간) | ... | ... | ... | ... |
| 변경 실패율 | 측정 안 함 | 측정 안 함 | n/a | ➖ |

## 처리량 지표 (본인 직접 작업 기준 — 단계 4.5 git log 직접 조회 결과)
| 지표 | 도입 전 (N일 환산) | 이번 주 | 증감 | 판정 |
|---|---:|---:|---:|:---:|
| 머지된 PR 수 | ... | ... | +X% | ✅ |
| 새로 연 PR 수 (본인 author) | n/a | ... | n/a | ➖ |
| 본인이 작성한 커밋 수 (작성일 기준) | ... | ... | +X% | ✅ |
| 본인이 변경한 코드 줄 수 (참고치) | ... | ... | ... | ➖ |

## 본인 커밋 상세 (단계 4.5 결과)
| 일시 (KST) | 저장소 | 커밋 | 티켓 | 내용 | 줄 수 |
|---|---|---|---|---|---:|
| ... | ... | [hash](github URL) | ... | ... | +A / -D |

## PR 사이클 타임 (저장소별)
| 저장소 | PR | 티켓 | 상태 | 사이클 타임 | 추가/삭제 |
|---|---|---|---|---|---:|
| ... | ... | ... | ... | ... | ... |

## 시간·비용 환산
가정값:
- 시급 W원/시간
- 효율 환산계수 0.7 (AI 가속이 그대로 시간 절감으로 이어지지 않음을 보수적 반영)
- PR 1건당 D시간 절감
- 도구 비용 월 T원

계산:
- 추가 처리한 PR = 실측 - 기준값 = X건/주 → 환산 절감 시간 = B시간
- 절감 가치 = K원/주, 도구 비용 = 약 C원/주
- **ROI = R%**

## Claude 활용 효율 (세션 단위)
| 지표 | 값 |
|---|---:|
| 총 세션 수 | N |
| 새로 시작한 세션 수 | ... |
| 본인이 작성한 커밋 수 | (단계 4.5 결과) |
| 본인이 변경한 코드 줄 수 | (단계 4.5 결과) |
| 캐시 히트율 | XX.X% |
| 평균 메시지 / 세션 | ... |
| 평균 도구 호출 / 세션 | ... |
| 처리한 토큰 합계 | 약 X만/억 |
| 실제 과금 토큰 (입력+출력) | 약 X만 |

## AI 활용 인프라 지표 (필수)
"AI 를 얼마나 잘 쓰고 있는가" 정량 지표. 작업 환경에 누적된 자산이 많을수록 다음 작업의 진입 비용이 줄어든다.

| 항목 | 도입 전 | 직전 주 말 | **이번 주 말** | 본 주차 변화 |
|---|---:|---:|---:|---|
| 활성 메모리 entry (사용자 영구 결정) | 0 | N | N+δ | +δ (파일명·날짜) |
| 등록된 hook | 0 | N | N | (변경 사항) |
| 활성 MCP 서버 | 0 | N | N+δ | +δ (서버명·세션) |
| 자동화된 워크플로 | 0 | N | N+δ | +δ (워크플로명) |
| Obsidian 도메인 자산 (mailplug 폴더 .md 파일 수) | 0 | N | N+δ | +δ |

**수집 방법**:
- 메모리: `ls ~/.claude/projects/-Users-ParkJinHyeong/memory/*.md | wc -l` (MEMORY.md 제외)
- hook: `~/.claude/settings.json` 의 `hooks` 키 카운트
- MCP: `~/.claude/mcp-servers/` 디렉토리 + 세션 시 활성화된 서버
- 자동화 워크플로: hook 로깅 + cron + 자동 배치 시스템 등 수동 식별
- Obsidian 자산: `mailplug/*.md` 카운트 (Obsidian MCP `list_notes` 또는 vault 직접)

본 주차 변경 narrative 는 [작업 사례] 사례 N "Claude 작업 환경 개선" 에서 다룬다.

### 세션 cwd 분포 (어떤 컨텍스트에서 일했는지)
| 작업 디렉터리 | 세션 수 | 무엇을 했는지 |
|---|---:|---|
| ... | ... | ... |
```

#### [03] 기술 향상
**책임: 메일플러그 코드의 What·How 만**. 본인 author 직접 작업만 포함. **PR 리뷰 학습 내용 narrative 금지** (사용자 정정 지시). 정량 수치 (커밋 hash·줄 수) 는 [02] 참조. 협업 narrative 는 [04] 참조.

```markdown
## 이 페이지가 다루는 내용
이 페이지는 **메일플러그 코드가 무엇을 어떻게 바뀌었는지 (What/How)** 만 다룹니다.
- 정량 수치 (커밋 hash · 줄 수 · ROI 등) 는 [성과 지표] 에서.
- Claude 와 어떻게 풀었는지 (협업 narrative) 는 [작업 사례] 에서.

## 영역 N — [한 줄 제목] (티켓 ID)
**문제**: [무엇이 안 됐는가, 평이한 언어]

**원인의 본질**: [핵심 도메인 진실 1~2 문장]

**조치**:
- **저장소 1**: [무엇을 어떻게 바꿨는가 — 위치·패턴·이유 한 문단]
- **저장소 2**: [동일]

**효과**: [왜 빨라졌나/안전해졌나 — 한 문장 근거 + 안티패턴 회피 시 그 이유]

**근거**: [GitHub PR 링크] | [Jira 티켓 링크]

**도메인 자산**: `mailplug/*_YYYYMMDD.md` (Obsidian 등재 노트 경로)

## 영역 N+1 — [복합 영역, 여러 sub 변경 포함] (티켓 ID)
> 도입 한 줄 (예: "이 영역은 N월 D일 합의가 다음 날 코드로 안착된 한 줄기")

### N+1-1. [sub 영역 제목]
**왜 바꿨는지**: [기존 한계 1~2 문장]
**무엇을 바꿨는지**: [핵심 변경 — 어댑터·패턴·정책]
**효과**: [무엇을 강제/방지하게 됐는가]

### N+1-2. ...

## 멀티 저장소 영향
| 저장소 | 이번 주 변경 영역 | 다른 저장소에 미친 영향 |
|---|---|---|
| ... | ... | ... |

## 변경이 가져온 효과
| 변경 | 어떤 효과를 만들었나 |
|---|---|
| ... | ... |
```

> **금지**: 본인 commit 표·라인 수 표 (이건 [02]). PR 리뷰 학습 내용 (이건 어디에도 narrative 금지). "기간 핵심 변경 요약" 박스 ([01] 한 줄 결론과 중복).

#### [04] 작업 사례
**책임: Why·협업 narrative 만**. 사례마다 "핵심 협업 패턴" 한 줄 + "어떻게 풀었는지" + "산출(요약)" 구조. **결과 섹션에 커밋 hash·라인 수 반복 게재 금지** ([02] 참조 링크). **PR 리뷰 학습 내용 narrative 금지** (사용자 정정 지시). 사례 카테고리는 본인 코드 작업 + **반드시 1건 이상의 "Claude 작업 환경 개선" 사례**.

```markdown
## 이 페이지가 다루는 내용
이 페이지는 **Claude 와 어떻게 함께 풀었는지 (Why·협업 narrative)** 만 다룹니다.
- 정량 수치는 [성과 지표] 에서.
- 코드 변경의 What·How 는 [기술 향상] 에서.

이번 주 사례는 N건. M건은 본인 코드 작업, 1건 이상은 Claude 작업 환경 자체에 대한 개선.

## 사례 1 — [한 줄 제목] (티켓 ID)
**핵심 협업 패턴**: [한 줄 요약 — 어떤 패턴이 반복적으로 등장했나]

**어떻게 풀었는지**:
* [Claude 활용 단계 1 — 도구·접근법·결정적 단서]
* [정정 사이클이 있었다면 그 흐름]
* [최종 안착 — 코드/문서/메모리]

**산출**: [요약 1~2 문장]. 자세한 코드 변경은 [기술 향상 - 영역 N], 수치는 [성과 지표].

## 사례 2 — ...

## 사례 N — Claude 작업 환경 개선 (필수, NEW)
**핵심 협업 패턴**: 본인 코드뿐 아니라 "Claude 를 어떻게 더 잘 쓸지" 자체에도 시간을 투자해 다음 주의 진입 비용을 낮춤.

이번 주에 누적된 환경 개선 N건:

### N-1. [개선 항목 제목] (날짜)
[1~2 문장 narrative — 무엇을 추가했는가, 어떤 자산화 채널이 생겼나]

### N-2. ...

> 본 사례 N건의 결과는 [성과 지표 - AI 활용 인프라 지표] 표에 정량으로 잡혔습니다.

## 협업이 만든 가치 (N가지 패턴)
이번 주 사례에서 공통적으로 드러난 패턴:

### 1. [패턴 제목] (사례 X)
[narrative]

### 2. [패턴 제목]
[narrative]
```

> **금지**: 결과 섹션에 커밋 hash·라인 수 반복 게재 ([02] 참조 링크로). PR 리뷰 narrative (사례·패턴 어디에도 금지, 단 사례 N "Claude 작업 환경 개선" 에서 자동화 자산으로만 1줄 언급 가능).

#### [05] 한계와 다음 단계
**최상단에 지난 주차 회고 표 → caveat 3개 (이번 주 새로 검색한 근거) → 본 보고서 추가 한계 → 다음 측정 계획 → 권고 → 이번 주 보강 근거 표** 순서.

```markdown
## 지난 주차 후속 조치 (피드백 루프)
직전 주차 [한계와 다음 단계] 의 "다음 측정 계획" 체크리스트 회고. (회고 페이지 없으면 "초회 보고서" 명시)

| 직전 주차 항목 | 이번 주 상태 | 비고 |
|---|---|---|
| 결함 탈출률 도입 | ⏳ 진행 중 | 정의 합의 후 다음 주 첫 측정 예정 |
| ... | ✅ 도입됨 / ⏳ 진행 중 / ➖ 미진행 | ... |

## 측정의 한계 (반드시 함께 읽어주세요)

### 1. 라인 수·커밋 수는 생산성 지표가 아닙니다
[이번 주 web-search-researcher 가 찾은 새 근거 1건 + 1줄 요약]
- 출처: [URL]

### 2. 개인 지표가 팀 산출과 같지 않습니다 (AI 생산성 역설)
[이번 주 새 근거]
- 출처: [URL]

### 3. 단기 속도 ≠ 장기 코드 건전성
[이번 주 새 근거]
- 출처: [URL]

## 본 보고서의 추가 한계
| 항목 | 한계 | 보완 계획 |
|---|---|---|
| ... | ... | ... |

## 다음 측정 계획
- [ ] 결함 탈출률 도입 — 배포 후 N일 내 신고된 버그 수 / 배포 건수
- [ ] 코드 재작업률 (churn) — 커밋 후 2주 내 수정된 라인 비율
- [ ] PR 리뷰 시간 별도 측정 — `gh pr` first review timestamp
- [ ] 다음 분기 재측정 일정: YYYY-MM-DD

## 다음 작업 항목
- [ ] WM-XXXXX
- [ ] ...

## 권고 (기획자에게)
1. ...
2. ...
3. ...

## 이번 주 보강 근거 (web-search-researcher)
| 주제 | 출처 | 한 줄 요약 | 신뢰성 근거 |
|---|---|---|---|
| LOC 함정 | URL | ... | ... |
| 개인 ≠ 팀 | URL | ... | ... |
| 단기 속도 ≠ 품질 | URL | ... | ... |
| (선택) 결함 탈출률 정의 | URL | ... | ... |
| (선택) Churn 정의 | URL | ... | ... |
```

### 9. 산출물 반환
- 컨테이너 페이지 + 5장의 페이지 URL 목록.
- 한 줄 요약 + 회고 처리 결과(`✅ N건 / ⏳ M건 / ➖ K건`).

## 매주 화요일 정기 호출 가정
- 측정 기간 default: 직전 주(월~일) 7일.
- 화요일 호출 시 직전 주 데이터가 안정화된 상태(주말 merge 포함).
- 자동화: 사용자가 `/loop` 또는 `/schedule` 로 매주 화요일 09시 등록 가능.

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
| web-search-researcher | caveat 근거 갱신·미해결 측정 항목 정의 검색. 직전 주 caveat URL 제외 강제. |
| codebase-analyzer | 주요 커밋 Before/After/효과 3단 서술 |
| general-purpose | gh CLI / Jira MCP 다중 호출이 필요한 메타데이터 수집 |

## 품질 체크리스트
- [ ] 인덱스 pageId 아래 "M월N주차 사용 분석" 컨테이너가 생성되고, 5장이 그 직속 자식으로 게시되었는가
- [ ] [05] 최상단에 "지난 주차 후속 조치" 표가 있고, 직전 주 "다음 측정 계획" 항목이 모두 ✅/⏳/➖ 로 명시되었는가 (또는 초회 명시)
- [ ] caveat 3개의 출처 URL 이 직전 주차와 다르며, 이번 주 web-search-researcher 가 찾은 최근 6개월 이내 자료인가
- [ ] [05] 하단에 "이번 주 보강 근거" 표가 있고, 각 항목에 신뢰성 근거(저자/매체/방법론)가 적혔는가
- [ ] 1쪽 요약이 한 줄 결론 + 4지표 표 + 비용 환산 + 한계 1줄을 모두 포함하는가
- [ ] 모든 수치에 baseline 대비 증감률·판정이 붙었는가
- [ ] ROI 계산에 가정값(시급·전환계수·도구비·1건당 절감 시간)이 명시되었는가
- [ ] Jira·커밋·PR 풀링크가 누락 없이 포함되었는가
- [ ] 협업 가치(PR 설명·위키·핸드오프)가 [04] 사례에 narrative 로 녹았는가
- [ ] gh CLI 실패 시 그 사실이 본문에 명시되었는가
- [ ] **단계 4.5 의 git log --author 직접 조회로 본인 commit 정확 산정했는가** (sessions.log 만 의존 금지 — 4월6주차 v2 → v3 정정 이력 참조)
- [ ] **[02][03][04] 페이지가 책임에 맞게 분리되었는가** (숫자 / 메일플러그 코드 What·How / 협업 Why). 본인 commit 표가 [02] 에만 있고 [03]/[04] 는 링크 참조만 있는가
- [ ] **[02] 에 "AI 활용 인프라 지표" 표가 있고** (메모리 / hook / MCP / 자동화 워크플로 / Obsidian 도메인 자산) 본 주차 변화가 명시되었는가
- [ ] **[02] 에 "세션 cwd 분포" 표가 있는가** (어떤 컨텍스트에서 일했는지 가시화)
- [ ] **[03]/[04] 에 PR 리뷰 학습 내용이 narrative 로 들어가지 않았는가** (사용자 정정 지시 — PR 리뷰는 [02] AI 활용 인프라에서 정량 카운트만, [04] 사례 N "Claude 환경 개선" 에서 자동화 자산으로만 1줄)
- [ ] **[04] 에 "Claude 작업 환경 개선" 사례가 1건 이상 포함되었는가** (메모리 신규 등재 / MCP 활성화 / 자동화 워크플로 / 리서치 노트 등)
- [ ] **비개발 청중이 읽을 수 있는 톤인가** (`ts_end` → "세션 종료 시각", carryover → "이전 주에 시작해 이번 주에 끝난 세션", "P0 패턴" → "동작하지 않던 P0 버그" 식으로 약어 풀어쓰기)
