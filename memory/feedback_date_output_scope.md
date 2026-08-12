---
name: 날짜 출력 통일의 범위
description: "날짜 포맷 통일" 논의는 프론트↔백 JSON 에 한정하고 CSV/엑셀 등 파일 다운로드는 제외한다
type: feedback
---
"날짜 입/출력을 통일한다"는 논의는 **프론트↔백엔드 JSON 요청/응답에만 적용**한다. CSV·엑셀 다운로드는 대상이 아니다.

**Why:** CSV/엑셀은 프론트 JS를 거치지 않고 사용자가 직접 엑셀 등으로 열어 보는 산출물이라, 사용자 기준 시각(로컬 TZ)으로 내보내는 게 기획/UX상 맞다. 여기에 ISO8601 UTC를 강제하면 오히려 사용자 체감이 어긋난다. 실제로 CSV 생성 클래스에서 로컬 TZ 로 오버라이드한 코드를 발견했을 때, 그건 "통일 규칙 이탈"이 아니라 의도된 동작이었다.

**How to apply:**
- 날짜 포맷 통일/리팩토링 제안 시 CSV·엑셀·PDF·첨부 리포트 등 파일 다운로드 경로는 대상 집합에서 제외.
- 고쳐야 할 곳은 `controller → service → ResponseDTO/Mapper → JSON` 경로의 날짜 필드, 그리고 프론트가 쿼리/바디로 보내는 날짜 파라미터의 검증·파싱.
- 파일 다운로드용 Context/Exporter 클래스(`*CsvContext`, `*XlsContext`, Excel 라이브러리)에서 로컬 포맷이 보여도 문제 삼지 않는다.

관련: [[feedback_multiregion_timezone]]
