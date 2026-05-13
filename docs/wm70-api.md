# wm70-api 컨텍스트

## 역할
mail REST API (CI4)

## 디렉토리 구조
```
wm70-api/
├── app/                    # CI4 공통 (Config, Constants, Controllers, DTO, Database, Entities, Enums, Factory, Filters, Helpers, Libraries, Log, Mappers, Models, Services, Traits, Util)
├── mailplug/
│   ├── Mail/               # 메일 핵심 (Config, Constants, Controllers, DTO, Entities, Enums, Libraries, Mappers, Models, Repositories, Services, Util, Validation, Views)
│   ├── Auth/               # 인증 (OAuth2 등)
│   ├── Board/              # 게시판 연동 (레거시, 미사용 소스 포함)
│   ├── Capacity/           # 용량 관리
│   ├── Contact/            # 연락처
│   ├── Eas/                # 결재
│   ├── Enums/              # 공통 Enum
│   ├── Notify/             # 알림
│   ├── Sync/               # 동기화
│   ├── User/               # 사용자 설정
│   ├── admin/              # 관리자 기능 (메일 삭제 등)
│   ├── config/             # 설정
│   ├── hrm/                # 인사관리
│   └── me/                 # 내 정보
├── mailplug-api-v1/        # v1 API (레거시)
├── mailplug-sync/          # 동기화 수신부 (command/common/controller)
├── oauth2serverphp/        # OAuth2 서버
├── tests/
├── public/
├── vendor/
└── writable/
```

## 주요 작업 이력

### 메일 삭제 기능 (WM-30095 Mecca-2 Epic)
- 관리자 메일 삭제: 백그라운드 스크립트 → 클라이언트 조기반환 후 후순위 로직 실행으로 변경
- 이유: 감사로그 적재를 위해 DAO 접근 필수
- 인증존/비인증존 분기 처리 (WM-32567, WM-32566)
- 활동로그 추가 (WM-32600)
- 읽음/안읽음 데이터 추가 (WM-31669, Holding)
- Bugfix 2차까지 완료

### 사이버 훈련 기능 (WM-30864, IN-REVIEW)
- Mecca-2 하위 이슈, 장기 진행

### 구글 계정 전환 (WM-32654, IN-REVIEW)
- Y→G: 사용자 폴더 삭제
- G→Y: 사용자 폴더 생성
- gw-member와 연동: active, ac_type 변경

### 암호메일 (WM-30969, WM-31697)
- 비밀번호 DB 암호화 (aes-256-cbc, md5는 길이 정규화용)
- secure_mail_key_organize.php 마이그레이션 batch
- 암호메일 설정 조건 반영 (WM-32095)
- NaN 오류 수정 (WM-32675)

### 핑거프린트
- 쿠키 보관 10년, 아이디 @2개 이상 시 마지막 @로 분리 (WM-30174)
- GET Body → 쿼리파람으로 accept-Language 수신 (Spring 호환) (WM-31942)
- 분리 작업 사전 조사: 서버/DB 분리 문서화 (WM-32185)

### SAST 취약점 조치 (LA-3431)
- Path Traversal: basename 방어 (LA-3434)
- SSRF: 입력값 검증 추가 (LA-3549)
- Code Injection: DeleteMailService 입력값 검증 추가 (LA-3432)
- OS Command Injection: 전수 조사, 대부분 오탐 확인 (LA-3433)
- Use of weak hash: md5/sha1 사용처 분류 — 암호화용 아님 확인 (LA-3556)
- Use of potentially dangerous function: 미사용 파일 제거 (LA-3555)

### ElasticSearch 정리
- 5버전 소스 제거 (WM-31781)
- PHP 버전 분기 제거 → ELS7 파일 유무로 판단 (WM-31783)

### Config 개선
- mail-api config 개선 작업 누락 처리 — gov-mecca2 분기 (WM-32214)
- 신버전 외부메일함 셋업 구현 — disabledMailboxTypes (WM-32192)
- forwardMaxSize 셋업 반영 (WM-31831)

### 발송량 제한
- _SENDLIMIT_, __SENDBLOCK__, _CONTROL 폴더/파일 권한 777 변경 (WM-32100, WM-32093, WM-32076)

### 동기화
- mailplug-sync: 큐 수신부, MemberService에서 gsuite 전환 시 백업 스크립트 실행
- SyncService.php: rqcomm.py, rqprocess.py 등 Python 스크립트 실행 (사용자 입력값 미사용)

### 기타 완료 이력
- 메일함 소스 리팩토링: 내부메일함 구분 parentId=1 (WM-31999)
- 구버전 내부메일함 생성 제한 (WM-32591)
- HMAC 인증 개선 + old key 삭제 (WM-30998, WM-31173)
- 첨부파일 이름 긴 경우 업로드 제한 (WM-30851)
- 미사용 에러코드 정리 (WM-31321)
- db strictOn 옵션 제거 (WM-31945)
- 사용자별 포워딩 설정 조회 오류 수정 (WM-31511)
- pop3_imap_use_by_user 셋업 구현 (WM-31374)
- postmaster priv값 변경 버그 수정 (WM-31175)
- demo drive DB 접근 계정 수정 (WM-32008)

## gw-member 의존
- 토큰 발급: accountId 포함 여부 분기 주의 (WM-32200)
- configs 업데이트: member API 경유
- 용량 갱신: capacity API 호출

## 주의사항
- mailplug/admin/mail/command/: 메일 삭제 시 입력값 검증 필수
- preview 토큰: sha1 기반, 유효시간 60초 (wm60과 공유)
- 동기화 스크립트: 사용자 입력값 미사용 확인 필수
