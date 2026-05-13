# gw-bbs 컨텍스트

## 역할
게시판 REST API (CI4)

## 디렉토리 구조
```
gw-bbs/
├── app/                    # CI4 공통 (Config, Constants, Controllers, DTO, Database, Entities, Enums, Filters, Helpers, Libraries, Log, Models, Services, Util, Validation)
├── mailplug/
│   ├── Board/              # 게시판 도메인 (Config, Constants, Controllers, DTO, Entities, Enums, Facade, Mappers, Models, Services, Validation)
│   ├── Health/             # 헬스체크
│   └── Notify/             # 알림
├── migration/              # 마이그레이션
├── tests/                  # 테스트
├── public/
│   └── docs/               # Swagger 명세 (gw-docs/bbs와 심볼릭 연결)
├── swagger_bootstrap.php   # Swagger 부트스트랩
├── generate-swagger.sh     # Swagger 생성 스크립트
├── phpcs.xml               # PSR-12 설정
├── infection.json.dist     # 뮤테이션 테스트
├── vendor/
└── writable/
```

## 주요 작업 이력

### Swagger 명세 적용 (WM-32393)
- api-doc → swagger 전환
- 이전: docs.wiro.kr/bbs_old / 최신: docs.wiro.kr/bbs
- gw-docs/bbs ↔ gw-bbs/public/docs 심볼릭 연결 → 게시판 배포 시 명세 자동 배포
- 실패 케이스 정의, dto 속성 정의, 잘못된 명세 수정

### N+1 쿼리 성능 개선 (WM-32272)
- Eager Loading 패턴 적용
- 게시글 리스트(10개): 21쿼리 → 3쿼리 (목록 + 작성자 일괄 + 첨부파일 일괄)
- 댓글 리스트(10개): 21쿼리 → 3쿼리 (목록 + 작성자 일괄 + 프로필 일괄)

### 첨부파일 255byte 대응 (WM-32283)
- Ubuntu 파일명 255byte 제한 vs 첨부파일 100글자(최대 400byte)
- 실제 저장: sha1(40글자) → 문제없음
- tmp 파일: 원본 파일명 사용 → qquuid로 변경하여 해결

### 용량 관리 정책 (LA-3753)
- 상품별 업로드 분기:
  - GW_GZ/EZ/EDU: 100MB, 드라이브 미사용(0MB)
  - GW_GZ/EZ/EDU + 드라이브 프리미엄: 2048MB, 드라이브 차감 기준 100MB
  - GW_DEDI/SHRD: 2048MB, 드라이브 차감 기준 20MB
  - 기업메일: 1024MB, 드라이브 미사용
- 핵심 변수: maxUploadTotalSize, driveDeductionThreshold, remainSize, driveRemainSize
- 드라이브 용량 초과 시 임계값 미만 파일은 게시판 용량에서만 차감

### Redis 최적화 (WM-31549)
- connect → pconnect 전환, 싱글톤 패턴 적용

### 기타 완료 이력
- 메일→게시글 이동 시 본문 이미지 깨짐 수정 (LA-3907)
- 2GB 첨부파일 업로드 누락 — front timeout 대응 (LA-3862)
- 드라이브 미사용 그룹 100MB 이상 업로드 차단 (LA-3868)
- 게시판 수정 시 ₩ 중복 증상 수정 (BB-33)
- DEMO 개통 시 첨부파일 복사 경로 버그 수정 (WM-31086)
- 게시판 삭제 시 서비스 필드 private 접근 수정 (WM-29785)
- 게시판 리스트 속도 개선 (WM-29274)
- 게시판 인수인계 문서 작성 (WM-29413)
- 파일 확장자 차단 기능 (WM-31281)
- 과거 게시글 이동 불가 (WM-30766, Holding)
- 공지 팝업글 등록여부 hideNotify 필드 반영 (WM-30439)

## gw-member 의존
- mb_config 업데이트: gw-member의 member API를 통해 호출
- 구 게시판(wm70-bbs)은 통합DB 직접 접근 → 신 게시판(gw-bbs)은 member API 경유
- 용량 API: gw-member의 capacity-info, drive/capacities 호출

## 주의사항
- 용량 관련 작업 시 상품코드별 분기 반드시 확인
- 첨부파일 tmp 경로: qquuid 사용 (원본 파일명 X)
- 게시판 배포 시 docs 심볼릭 링크 확인
