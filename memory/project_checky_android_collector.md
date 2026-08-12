---
name: project-checky-android-collector
description: "체키(hichecky.com) 안드로이드 = TWA+결제수집기, Play 아닌 사이드로드 배포. 빌드/배포·config 파일수정 운영법"
metadata: 
  node_type: memory
  type: project
  originSessionId: aaac4105-d747-4f26-a3e9-f09cc8f732ad
---

체키(checklist-app, hichecky.com) 안드로이드 앱은 `android-collector/`에 있고 **TWA(체키 웹) + 결제수집기**다. 수집기 `CollectorService`(NotificationListenerService)가 사용자가 켠 카드/은행 앱 알림을 읽어 백엔드 `/api/payments/collect`로 전송(파싱은 서버). 알림 읽기는 Play 최고위험이라 **Play 미출시 · 사이드로드 배포**: `frontend/public/dl/install.html` + `frontend/public/dl/checky-app-bece5daa.apk`.

운영 핵심:
- **콜렉터 빌드**엔 Android SDK 필요 → repo의 docker gradle 파이프라인이 아니라 **Android Studio/호스트 `./gradlew`**. 전용 빌드 워크스페이스 = `~/Desktop/source/checky-apk`(detached origin/main, local.properties·wrapper·웜캐시). `cd android-collector && ./gradlew assembleDebug`.
- ⚠️ **`checky-chores` 등 오래된 feature 워크트리에서 콜렉터 빌드 금지**(구버전 됨). gradle wrapper는 커밋됨 — .gitignore에서 jar 재제외 금지.
- **배포** = 빌드 apk를 `frontend/public/dl/checky-app-bece5daa.apk`로 복사 → 커밋 → 일반 웹 배포.
- **결제앱 목록은 서버 config** `frontend/public/collector-config.json` — 은행 추가/제외는 이 파일만 수정+웹배포, **APK 재빌드 불필요**.
- Play 대응(고지동의 `SetupActivity.requireConsent`, `<queries>`/QUERY_ALL_PACKAGES 제거)·법적페이지(`/terms`,`/privacy`)·단일 연락처 `help@hichecky.com`(Cloudflare Email Routing)·UGC 신고 `/api/reports` 는 되돌리지 말 것.

상세는 repo `CLAUDE.md`의 "안드로이드 콜렉터"·"법적 페이지" 섹션과 `docs/play-data-safety-mapping.md`(Play 제출 기준). (2026-07 확립). 공유 `~/.gradle` transforms 캐시 손상 시 `rm -rf ~/.gradle/caches/transforms-4`+`gradlew --stop`.
