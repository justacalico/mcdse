# MCDSE — development notes

Flutter port of [MCDSaveEdit](https://github.com/CutFlame/MCDSaveEdit)
(C#/WPF, MIT). Targets Linux, Windows, and macOS desktops.

## Layout

- `lib/main.dart` — app entrypoint; `McdseApp` accepts `args` + injectable `AppModel` for tests.
- `lib/app_model.dart` — startup / game-content loading (`usableGameContentIfExists`, `loadGameContent`, `loadLanguageStrings`).
- `lib/data/` — constants, enums, JSON-backed models (`Item`, `Enchantment`, `ProfileSaveFile`, …) that preserve every JSON field verbatim, `ProfileParser` (sanitization + pretty-print write), `Secrets` (AES keys).
- `lib/logic/` — `GameCalculator` (power/level/xp formulas), `FileProcessHelper` (encrypt/decrypt/convert), extensions.
- `lib/services/` — `encryption.dart` (local AES-256-ECB + remote provider), `save_file_handler.dart` (D001 magic), `string_library.dart` (`R` — bundled EN strings + `.locres` lookup), `databases.dart` (`ItemDatabase`/`EnchantmentDatabase`/`EnchantmentDescriptions`), `settings_store.dart` (JSON-file replacement for upstream registry), `config.dart` (remote config + version check), `event_logger.dart`, `content_resolver.dart` / `local_content_resolver.dart` / `pak_content_resolver.dart`.
- `lib/pak/` — Unreal Engine pak reader port: lazy `PakSource`, `PakFileReader`, `PakIndex`, uasset parsing, `UTexture2D` + BC/DXT decode, `.locres` reader.
- `lib/viewmodels/` — `ProfileViewModel`, `MainViewModel`, `ItemListViewModel`, `MainEquipmentViewModel`, `StorageChestEquipmentViewModel`; `lib/core/property.dart` implements the observable `Property`/`MappedProperty`/`IReadWriteProperty` pattern.
- `lib/ui/` — `windows/` (main, splash, game-files, about, selection), `tabs/` (inventory, stats, chest), `screens/` (equipment, item-list, item, enchantment), `widgets/` (stepper, stat-field, item-control, enchantment-set, netherite, busy-indicator), `app_shell.dart` (splash → game-files → main startup flow).

## Build & test

```bash
/home/calico/flutter/bin/flutter pub get
/home/calico/flutter/bin/flutter test              # unit + widget tests
/home/calico/flutter/bin/flutter analyze           # lint
/home/calico/flutter/bin/flutter build linux       # release bundle
/home/calico/flutter/bin/flutter run -d linux -- --dev --local   # dev server
```

CI: GitHub Actions (`.github/workflows/`) builds Linux + Windows + macOS and
drafts releases on `v*` tags; GitLab CI mirrors test/build + a pages landing
site under `landing/`.

## Gotchas

- `SaveKeys.initFromEnvironment()` reads `MCDSE_SAVE_KEY` (hex) at startup.
- Encrypted saves carry an 8-byte `D001` + zero magic before the AES body.
- `ProfileParser.read` throws `FormatException` on non-JSON input; returns null
  for valid-but-non-object JSON. `MainViewModel` catches and calls `showError`.
- `window_manager` init is skipped when `FLUTTER_TEST` is set.
- Golden tests live in `test/goldens/` (one per screen/dialog + theme
  variants). Regenerate with `flutter test test/goldens/ --update-goldens`.
  Roboto is bundled in `assets/fonts/` and loaded in the golden `setUpAll`
  so text renders as real glyphs.
- In widget tests, `BusyIndicator` animates forever — use bounded `tester.pump`
  loops inside `tester.runAsync` (file IO needs the real event loop).
- Pak key constant lives in `lib/data/secrets.dart` (`PakAesKey`).
- Tests need real Blank.dat at `test/data/Blank.dat`.
- Do not commit paks or save files.
