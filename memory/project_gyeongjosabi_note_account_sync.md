---
name: project-gyeongjosabi-note-account-sync
description: 품앗이 계정가입+Firebase 동기화는 2026-08 중 철회됨 — 서버 동기화 대신 자동 로컬 백업+CSV 복구로 대체
metadata: 
  node_type: memory
  type: project
  originSessionId: d42533e3-5b3c-4f8b-897c-0840faf16341
  modified: 2026-08-11T05:19:27.629Z
---

품앗이 앱(`~/Desktop/source/gyeongjosabi-note`, `com.gyeongjosabi.note`)에 2026-08-05~06 Firebase Auth+Firestore 기반 "계정가입 + 선택적 동기화"를 붙였다가, **2026-08-11 이전에 다시 걷어냈다**. 현재 커밋 이력 상단이 그 철회 작업이다:

- `0d44934 계정·서버 동기화를 걷어내고 자동 로컬 백업으로 대체한다`
- `0ec8e93 계정 제거 후 남은 찌꺼기를 걷어내고 CSV 복구를 실제 경로로 검증한다`
- `5140e5b versionCode 9 / versionName 0.4.0 으로 올림`

**Why:** 앱 성격을 로컬 우선(local-first)으로 확정했다 — 경조사비 데이터가 서버로 나가지 않는 것이 이 앱의 핵심 약속이 됐고, versionName 도 그래서 올렸다. 데이터 보호는 Room+SQLCipher(Android Keystore) 로컬 암호화가 담당하고, 백업/이전은 자동 로컬 백업과 CSV 내보내기·복구로 푼다.

**How to apply:** 동기화·계정·Firebase 관련 코드를 찾거나 되살리려 하지 말 것. `FirebaseAuthRepository` / `FirebaseSyncRepository` / `SessionIdStore` / `activeSessionId` 는 더 이상 없다. 다만 `deletedAt`(soft delete, Migration 3→4)은 동기화를 위해 도입됐던 것이라 스키마에 남아 있을 수 있으니, 삭제 동작을 건드릴 때 물리 삭제인지 tombstone인지 코드에서 직접 확인한다. [[project_gyeongjosabi_note_app_identity]] [[project_poomasi_emulator_setup]]
