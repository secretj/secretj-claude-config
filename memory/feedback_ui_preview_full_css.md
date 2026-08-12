---
name: feedback_ui_preview_full_css
description: UI 시각 검토는 페이지 전체 CSS + 타깃 뷰포트로. 공용 스타일시트에 새 클래스 추가 시 이름 충돌 확인
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2bee3996-74b3-4432-8bc7-4396af3c939b
---

프론트 UI(특히 CSS 레이아웃) 변경을 프리뷰로 검토할 때, **격리된 harness(내가 쓴 규칙만)로 보면 안 된다** — 반드시 **해당 페이지의 CSS 전문 + 실제 타깃 뷰포트(모바일 폭 등)**로 렌더해 검토한다.

**Why:** checklist-app 달력 월뷰에 막대 기능을 넣으며 `.cal__week` 클래스를 새로 썼는데, 같은 파일의 주간 뷰가 이미 `.cal__week`(display:flex column)를 쓰고 있어 CSS 순서상 내 `display:grid`가 덮여 7열이 세로로 무너졌다. 격리 프리뷰엔 주간뷰 CSS가 없어 정상으로 보였고, 그대로 배포해 폰에서 깨진 채 나갔다(2026-07-27, 원복 후 `.cal__mrow`로 rename 재배포).

**How to apply:**
- 공용 스타일시트에 클래스 추가 전 `grep '\.새클래스\b'`로 **이름 충돌 확인**. 있으면 고유 접두어(예: `.cal__mrow`).
- 프리뷰 harness는 실제 `*.css` 전문을 `<link>`로 걸고, 폰 폭(390px 등)에서 확인.
- 관련: [[feedback_test_after_work]] (빌드·유닛테스트만으론 시각 회귀 못 잡음).
