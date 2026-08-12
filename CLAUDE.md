# CLAUDE.md — 공통 응답 규칙

`~/.claude/CLAUDE.md` 로 설치된다. 모든 프로젝트에 적용되는 개인 전역 지침.

## 응답 규칙
1. 한국어로 대화, 기술 용어는 영어
2. 코드 작업 시 꼬리질문으로 엣지케이스를 짚는다
3. 테스트 케이스는 정상/실패/경계값으로 구분한다

## 코드 탐색 규칙
4. 코드 구조 파악·심볼 검색·호출 관계·변경 영향 분석은 grep/Read 반복 대신 **codegraph MCP 도구**를 우선 사용한다 (`codegraph_search`, `codegraph_context`, `codegraph_callers`, `codegraph_callees`, `codegraph_impact`). 단, codegraph 인덱스가 없는 프로젝트(`.codegraph/` 폴더 부재)에서는 평소대로 grep/Read를 쓴다.

## HTML 문서 작성 규칙
5. "HTML로 문서 만들어줘" 요청은 기본적으로 아래 포맷으로 작성한다.
   - **톤**: Apple 디자인(system font stack, 넓은 여백, 무채색 + 절제된 블루 `#06c`), **차분하고 정적인 기술 메모**. 그라데이션 헤드라인·이모지·체크마크·CTA 버튼 등 설득/세일즈 장치 금지, 평서체(`~된다`). 제안 문서면 기대효과뿐 아니라 고려사항/리스크도 포함.
   - **구조**: 글래스 sticky 상단바 / 메모형 헤더(eyebrow + 제목 + lead + 메타 테이블) / **좌측 sticky 목차(TOC) + 본문 2단**(모바일은 상단 2열 인라인으로 접힘) / IntersectionObserver scroll-spy로 현재 섹션 강조 / 섹션마다 번호 칩(01,02…) + 라운드 카드, 홀짝 밴드 배경 교차 / `scroll-margin-top`으로 앵커 오프셋 / 비교표·다이어그램은 무채색 박스.
   - **재사용**: 이전에 만든 문서가 로컬에 있으면 그 구조/CSS를 그대로 가져오고 섹션 내용만 교체한다. 없으면 위 명세대로 새로 만든다.
   - 푸터 서명과 저장 경로 규칙은 memory 의 `feedback_html_doc_output` 참고.
