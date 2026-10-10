import 'dart:typed_data';

import 'binary_reader.dart';
import 'objects.dart';

/// Ported from `LocResReader.cs` — parses .locres localization binaries into
/// a nested map of namespace → (key → localized string).
class LocResReader {
  LocResReader(Uint8List bytes) {
    final reader = PakBinaryReader(bytes);

    var magicOk = true;
    final magic = FGuid.read(reader);
    if (!(magic.a == 0x7574140E &&
        magic.b == 0xFC034A67 &&
        magic.c == 0x9D90154A &&
        magic.d == 0x1B7F37C3)) {
      magicOk = false;
    }

    var version = 0; // LEGACY
    if (magicOk) {
      version = reader.readUint8();
    } else {
      // Legacy files lack the magic — rewind.
      reader.seek(0);
    }

    if (version > 2) {
      throw const FormatException('LocRes file is too new to be loaded!');
    }

    // Localized string array (COMPACT+).
    var localizedStrings = <_LocString>[];
    if (version >= 1) {
      final localizedStringArrayOffset = reader.readInt64();
      if (localizedStringArrayOffset != -1) {
        if (version >= 2) {
          final currentFileOffset = reader.position;
          reader.seek(localizedStringArrayOffset);
          localizedStrings = reader.readTArray(() {
            final s = reader.readFString() ?? '';
            final refCount = reader.readInt32();
            return _LocString(s, refCount);
          });
          reader.seek(currentFileOffset);
        } else {
          final currentFileOffset = reader.position;
          reader.seek(localizedStringArrayOffset);
          final tmp = reader.readTArray(() => reader.readFString() ?? '');
          reader.seek(currentFileOffset);
          localizedStrings = [for (final s in tmp) _LocString(s, -1)];
        }
      }
    }

    if (version >= 2) {
      reader.readUInt32(); // EntriesCount
    }

    final namespaceCount = reader.readUInt32();
    for (var i = 0; i < namespaceCount; i++) {
      if (version >= 2) reader.readUInt32(); // StrHash
      final namespace_ = reader.readFString() ?? '';

      final keyCount = reader.readUInt32();
      final namespaceEntries = <String, String>{};
      for (var j = 0; j < keyCount; j++) {
        if (version >= 2) reader.readUInt32(); // StrHash
        final key = reader.readFString() ?? '';

        reader.readUInt32(); // SourceStringHash

        String entryLocalizedString;
        if (version >= 1) {
          final localizedStringIndex = reader.readInt32();
          if (localizedStrings.length > localizedStringIndex &&
              localizedStringIndex >= 0) {
            final localizedString = localizedStrings[localizedStringIndex];
            entryLocalizedString = localizedString.string;
            if (localizedString.refCount != -1) {
              localizedString.refCount--;
            }
          } else {
            throw FormatException(
                "LocRes has an invalid localized string index for namespace '$namespace_' and key '$key'.");
          }
        } else {
          entryLocalizedString = reader.readFString() ?? '';
        }
        namespaceEntries[key] = entryLocalizedString;
      }
      entries[namespace_] = namespaceEntries;
    }
  }

  final Map<String, Map<String, String>> entries = {};
}

class _LocString {
  _LocString(this.string, this.refCount);
  final String string;
  int refCount;
}
