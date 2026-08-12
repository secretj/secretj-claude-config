---
name: ot-job-tracker 인프라 상태 (Fly → Vercel/Neon)
description: ot-job-tracker 프로젝트의 현 인프라와 Fly SQLite 폐기 상태 — Phase 6 마이그레이션 보류 결정 배경
type: project
originSessionId: 21b1a782-ed8b-4cd0-b099-2bf7c898f162
---
ot-job-tracker는 Vercel(웹) + Neon Postgres(DB) + GitHub Actions(크롤 크론) 구조로 운영 중. 기존 Fly.io 배포는 trial 만료로 접근 불가 상태 (2026-04-16 확인, `fly status` 실행 시 "trial has ended" 에러). `fly.toml`은 저장소에 남아있지만 레거시 참조용.

Phase 6 (Fly SQLite → Neon 유저 데이터 마이그레이션)은 **보류 결정 (2026-04-16)**. 기존 유저는 Vercel에서 카카오 재로그인 시 자동 재가입하는 방향. 필요 시 Fly에 결제 등록 후 복구 가능하나 현재는 진행 안 함.

**Why:** Fly trial 만료로 SQLite 덤프가 물리적으로 불가 + 유저 수 적어 재로그인 비용이 작음 + 다른 작업(크롤러 안정화, UI) 우선순위가 높음.

**How to apply:** ot-job-tracker 작업 시 Fly 관련 가정 금지 (DB는 Neon만 참조). `fly.toml` 수정 요청 들어와도 레거시임을 사용자에게 확인. 크롤 실패 디버깅은 GitHub Actions `crawl.yml` 로그 + Neon DB 상태 기준.
