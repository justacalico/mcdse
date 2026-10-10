# MCDSE

A Flutter desktop port of
[MCDSaveEdit](https://github.com/CutFlame/MCDSaveEdit) — an editor for
*Minecraft Dungeons* character save files.

Runs on **Linux**, **Windows**, and **macOS**.

## Features

- Open encrypted (`.dat`) and decrypted (`.json`) character save files
- Convert between formats automatically on save
- Edit currencies (Emeralds, Gold, Eyes of Ender), unlock the portal
- Edit level, character power, enchantment points
- Inventory + storage chest management: filter, add, duplicate, delete,
  move items between inventory/chest
- Edit gear and hotbar equipment
- Per-item editing: power, rarity, marked-new, upgraded, gifted flags
- Enchantments: tier editing, slot management, gilded (Netherite)
  enchantments, armor properties
- Stats/Counters tab: progress counters and mob kills
- Reads the game's own pak files for item/enchantment images and
  localized names — or runs in a limited mode without them
- Language picker, update checks, drag-and-drop file opening, recent
  files, Ctrl+O/Ctrl+S/Ctrl+Q/Delete shortcuts

## Quick start

```bash
flutter pub get
flutter run -d linux        # or -d windows / -d macos
```

On first launch the app looks for `Dungeons/Content/Paks` in the usual
install locations (Steam, Mojang launcher, Xbox PC) and asks if it can't
find them — you can pick a folder or run with no game content.

Builds:

```bash
flutter build linux      # → build/linux/x64/release/bundle/
flutter build windows
flutter build macos
```

## Testing

```bash
flutter test            # unit + widget smoke tests
flutter analyze         # lint
```

## Not affiliated

This project is not affiliated with Mojang Studios or Microsoft. Image
assets extracted at runtime from game files are Copyright © Mojang.

## License

MIT — see [LICENSE](LICENSE). Original C#/WPF implementation by
Michael Holt (CutFlame), MIT.
