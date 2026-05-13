# gw-member 컨텍스트

## 역할
토큰, 설정값, 사용자 관리 REST API (CI4)

## 디렉토리 구조
```
gw-member/
├── app/                    # CI4 공통 (Controllers, Services, Models, Entities, DTO, Enums, Filters, Libraries, Helpers, Traits)
├── auth/                   # 인증 도메인 (Controllers, Services, Libraries, Repository, Factories, Entities)
├── board/                  # 게시판 연동
├── calendar/               # 캘린더 연동
├── capacity/               # 용량 관리
├── common/                 # 공통 모듈
├── configs/                # 설정값 도메인 (Controllers, Services, Models, DTO, Entities, Mappers, Utils)
├── fingerprint/            # 핑거프린트 도메인 (Controllers, Services, Models, DTO, Entity, Enums, Filters, Infrastructure, Libraries)
├── health/                 # 헬스체크
├── internal/               # 내부 API
├── link/                   # 링크 관리
├── member/                 # 사용자 도메인 (controller, service, dao, domain, dto, mapper, infra, util, config, constant)
├── membersync/             # 멤버 동기화
├── migration/              # 마이그레이션
├── organization/           # 조직도
├── sync/                   # 동기화
├── tests/                  # 테스트
├── public/                 # 웹 루트
├── vendor/                 # 의존성
└── writable/               # 캐시/로그
```

## 핵심 DB: db1_member
mb_config, mb_groups, mb_config_user_group, mb_auth, mb_organ_link, mb_login_otp, mb_user_links, mb_config_user, mb_user_log

## 주요 작업 이력

### configs API 제거 및 분리
- GET/PATCH api/v2/member/configs → 별도 API로 분리 진행 중
- JSON Hijacking 취약점 대응 목적
- 관련: WM-32174, WM-32175, CR-3845

### default config 성능 개선 (WM-32233, 진행중)
- 사용자 북마크 제거 → 프로필 클릭 시 별도 API
- 관리자 북마크 캐시 TTL 무제한, bookmarks 필드 통합
- 권한 필드 제거 → 프론트에서 토큰 scope 활용
- updateInfo redis별 캐싱, userContext 사용자별 캐시
- 하위: WM-32234 캐시 작업 (Holding)

### UserContext lazy loading (WM-32224)
- 79개 서비스 중 9개만 실제 사용 → 속성 접근 시점에 DB 조회로 변경
- DB 커넥션 4→3개 축소

### DB 인덱스 튜닝 (WM-32004, WM-32005)
- mb_auth: au_vh_id_au_seq_idx
- mb_user_log: DROP ul_vh_id_u_seq_ul_type_idx
- mb_groups: gr_vh_id_gr_name_idx
- mb_config_user_group: cu_vh_id_name_idx, cu_vh_id_usergroupseq_idx
- mb_config: co_vh_id_name_idx

### Member DB 커넥션 축소 (WM-32200)
- 토큰에 accountId 없으면 define 안 하도록 수정
- 토큰 발급처: wm70-api, wm60, 각 서비스 직접 생성 케이스

### ScopeService 이슈 (LA-3896)
- 메신저 미사용인데 scope 활성화 버그
- setTopMessenger: useMessenger || usePuddlr 조건으로 수정
- 경로: ScopeService → getUserMenuAuth → getInitialMenuAuth → getDefaultValueForMenu

### 구글 계정 전환 (WM-32653 Epic, 진행중)
- active, ac_type 변경
- 테이블 정리 (WM-32729): Sqlite3(ea_auth_new, organ_join_user, organ_link, sms, 메일링) / 통합DB(mb_auth, mb_organ_link, mb_login_otp, mb_user_links, mb_config_user)
- hard delete 예정

### 용량 관리 (NCP)
- GET /api/v2/member/capacity-info/{service}
- GET /api/v2/member/drive/capacities
- NCP 상품은 -1(무제한)이 아니라 실제 값 반환 필요
- 1회 최대 업로드 제한 용량 검증 제거 (LA-4009)

### Redis 최적화 (WM-31644)
- connect → pconnect 전환

### 기타 완료 이력
- Config 소스 공통화 (WM-31472)
- login_otp 동기화 개선 (WM-32641)
- 인사관리 메뉴 노출 조건: config custom eas + mb_auth au_personal_manage (WM-32694)
- 사용자 이름 1글자 허용 (WM-31930)
- NCP 기능 노출 조건: GW_GZ, GW_EZ, GW_EDU (LA-3838)
- 도메인 병합 (WM-30966)
- 프로필 이미지: 아이디에 점(.) 확장자 인식 오류 수정 (WM-32617)
- 내부편지함 이름 변경 batch (WM-32758, 진행중)

## 주의사항
- 토큰 accountId 유무에 따른 분기 항상 체크
- Sqlite3 ↔ 통합DB 동기화 영향 확인
- configs API 호출부가 gw-bbs, wm70-api, wm60에 분산됨
