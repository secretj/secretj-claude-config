---
name: html-doc-output-footer-path
description: HTML 문서 생성 시 푸터 서명과 저장 경로 규칙
metadata:
  node_type: memory
  type: feedback
---

"html 만들어줘" 요청으로 문서를 만들 때(별도 지시 없으면 기본 적용):

**푸터**: 한 줄로, 작성자를 `{소속} {이름}` 형식으로 기재한다.
형식: `{소속} {이름} · {저장소/대상} · {내용} 명세`.
"기준: …" 같은 계보/출처 줄은 넣지 않는다.
→ 실제 소속·이름은 로컬 memory 에만 두고 공개 저장소에는 넣지 않는다.

**저장 경로**: `~/Desktop/docs/(연월)/(이슈번호)-(내용 한글).html`
- `()`는 양식(placeholder)이지 고정값이 아니다.
- 연월 = `YYYYMM` (예: `202606`)
- 예: `~/Desktop/docs/202606/ABC-1234-계정-명세.html`
- 폴더가 없으면 생성한다.

**Why:** 문서 산출물의 위치·작성자 표기를 매번 일관되게 유지하려는 사용자 규칙.
**How to apply:** HTML 문서 요청 시 위 푸터와 경로를 기본값으로 적용. 문서 톤·구조는 [[CLAUDE.md]] 의 HTML 규칙(Apple 톤 템플릿)을 그대로 따른다.
