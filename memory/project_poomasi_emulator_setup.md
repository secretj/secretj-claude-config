---
name: project-poomasi-emulator-setup
description: "품앗이(gyeongjosabi-note) 검증용 에뮬레이터 — poomasi_api36 사용, 기존 gyeongjosabi_test AVD는 부팅 불가"
metadata: 
  node_type: memory
  type: project
  originSessionId: b2c0f8c5-280e-464d-a449-2b22cb821a92
  modified: 2026-08-09T23:23:10.177Z
---

품앗이(`~/gyeongjosabi-note`) UI 검증은 **AVD `poomasi_api36`**(system-images;android-36;google_apis;arm64-v8a, Pixel 7)로 한다. 2026-08-10 생성.

- 기존 **`gyeongjosabi_test`(API 34) AVD는 부팅 불가** — `Vulkan emulation initialized` 직후 `detected a hanging thread 'QEMU2 main loop'` 로 멈춘다. GPU swiftshader / `-no-snapshot-load` / 스테일 lock 제거 모두 실패했다. 이 AVD 를 다시 쓰려 시간 쓰지 말 것.
- 콜드 부팅 직후 2~3분은 GMS `BOOT_COMPLETED` 작업으로 프레임이 4초씩 밀려(`Davey! duration=4506ms`) **SystemUI ANR 이 뜨고 소프트 키보드(`mImeWindowVis=0`)가 안 올라온다**. IME 검증은 부팅 후 충분히 기다린 뒤에 해야 한다 — 안 뜬다고 코드 문제로 오해하지 말 것.
- 키보드 표시 확인은 `adb shell dumpsys input_method | grep -E "mInputShown|mImeWindowVis"` 로 판단한다. `mInputShown=true` 만으로는 부족하고 **`mImeWindowVis=3` 이어야 실제로 보이는 상태**다.
- targetSdk 36 은 edge-to-edge 가 강제되므로 인셋 회귀 검증은 반드시 API 36 이미지에서 한다. API 34 에뮬레이터는 `enableEdgeToEdge()` 덕에 비슷해 보이지만 강제 모드가 아니다.

관련: [[project_gyeongjosabi_note_app_identity]]
