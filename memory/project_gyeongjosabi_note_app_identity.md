---
name: project-gyeongjosabi-note-app-identity
description: "gyeongjosabi-note 안드로이드 앱의 브랜드명은 '품앗이'(구 '경조사비 장부'), 아이콘 컨셉과 리브랜딩 경위"
metadata: 
  node_type: memory
  type: project
  originSessionId: 74892977-ad01-421c-9aaa-1496a341fa9f
  modified: 2026-08-05T07:25:18.885Z
---

`~/gyeongjosabi-note` 안드로이드 앱(패키지 com.gyeongjosabi.note, 경조사비 관계·답례 추적 앱)의 **서비스명은 "품앗이"**다(2026-08-05 확정). 이전엔 `strings.xml`의 app_name이 "경조사비 장부"였는데, 사용자가 "그건 서비스 특성 설명일 뿐 브랜드명이 아니다"라고 지적해 리네이밍했다. "품앗이"는 전통 상호부조 개념 — 받으면 언젠가 갚는다는 이 앱의 핵심 가치(예산관리 아님, 관계·답례 추적)와 정확히 맞아떨어진다는 게 채택 이유.

**앱 아이콘/로고 컨셉 — "봉투 속 지폐"**: 결혼식/장례식에서 축의금·조의금을 봉투에 담아 건네는 모습을 형상화. 덮개(flap) 없는 봉투 윤곽선 위에 지폐가 절반쯤 삐져나온 형태 + 지폐 위 작은 인장 포인트. `ic_launcher_foreground.xml`/`ic_launcher_monochrome.xml`(Adaptive Icon)과 상단바 `LedgerWordmark`(`ui/theme/Logo.kt`)가 같은 도형 언어를 공유한다.

**Why:** 아이콘 1차 시도("도장" 원형 링+바 모티프)는 너무 추상적이라 반려됐고, 2차 시도(봉투+덮개 V자)는 이메일 앱 아이콘과 구분되지 않아 폐기됐다 — 덮개 자체가 이메일 픽토그램의 핵심 요소라 아무리 다르게 그려도 "메일"로 읽혔다. 이 실패 경험 때문에 최종안은 덮개를 아예 없애고 "돈이 든 봉투"라는 개념을 지폐 형상으로 직접 드러내는 쪽을 택했다.

**How to apply:** 이 앱 관련 작업에서 "경조사비 장부"라는 옛 이름을 쓰지 말 것 — 코드 주석·커밋 메시지·문서에서 "품앗이"로 지칭. 향후 아이콘/로고를 추가로 다듬을 때도 실제 서비스 대상(축의금·조의금 봉투)을 직접 형상화하는 방향을 유지하고, 흔한 픽토그램(이메일·지갑·동전·하트·그래프)과 겹치는 실루엣은 반드시 사전에 의심할 것. [[feedback_creative_specific_design]]
