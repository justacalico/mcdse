import 'dart:convert';
import 'dart:typed_data';

import 'models/profile_save_file.dart';

/// Ported from `Data/Profiles/ProfileParser.cs`.
///
/// Reads the raw bytes of a (decrypted) save file, drops control characters,
/// keeps only the first complete JSON object (PS4/Switch files carry extra
/// duplicate data after it), then deserializes it.
abstract final class ProfileParser {
  static bool _isControlChar(int byte) {
    // Equivalent to char.IsControl on the Latin-1 code point.
    return byte <= 0x1F || (byte >= 0x7F && byte <= 0x9F);
  }

  static Uint8List sanitize(Uint8List input) {
    final out = BytesBuilder(copy: false);
    var bracketCount = 0;
    for (var i = 0; i < input.length; i++) {
      final b = input[i];
      if (_isControlChar(b)) continue;
      if (b == 0x7B /* { */) {
        bracketCount++;
      } else if (b == 0x7D /* } */) {
        bracketCount--;
        out.addByte(b);
        if (bracketCount == 0) {
          // End of the first full JSON object.
          return out.toBytes();
        }
        continue;
      }
      out.addByte(b);
    }
    return out.toBytes();
  }

  static ProfileSaveFile? read(Uint8List input) {
    final sanitized = sanitize(input);
    // Upstream parses with AllowTrailingCommas=true.
    final decoded = json.decode(
        _stripTrailingCommas(utf8.decode(sanitized)));
    if (decoded is! Map<String, dynamic>) return null;
    return ProfileSaveFile(decoded);
  }

  /// Removes `,}` / `,]` trailing commas outside string literals.
  static String _stripTrailingCommas(String text) {
    final out = StringBuffer();
    var inString = false;
    var escaped = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        out.write(ch);
        escaped = false;
        continue;
      }
      if (ch == '\\' && inString) {
        out.write(ch);
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        out.write(ch);
        continue;
      }
      if (ch == ',' && !inString) {
        // Look ahead past whitespace for a closing bracket.
        var j = i + 1;
        while (j < text.length &&
            (text[j] == ' ' ||
                text[j] == '\n' ||
                text[j] == '\r' ||
                text[j] == '\t')) {
          j++;
        }
        if (j < text.length && (text[j] == '}' || text[j] == ']')) {
          continue; // drop the comma
        }
      }
      out.write(ch);
    }
    return out.toString();
  }

  /// Writes the profile as pretty-printed JSON, omitting nulls at the typed
  /// model level (matching upstream's `WhenWritingNull`) and escaping
  /// non-Latin-1 characters to \uXXXX (matching System.Text.Json's default
  /// encoder).
  static Uint8List write(ProfileSaveFile profile) {
    final cleaned = _cleanProfileMap(profile.json);
    const encoder = JsonEncoder.withIndent('  ');
    final text = encoder.convert(cleaned);
    return utf8.encode(_escapeNonLatin1(text));
  }

  /// Mirrors System.Text.Json's default encoder: non-Latin-1 characters are
  /// escaped as \uXXXX (surrogate pairs for astral planes), and the
  /// HTML-sensitive ASCII characters <, >, &, ' are escaped too.
  static String _escapeNonLatin1(String text) {
    String esc(int cp) =>
        '\\u${cp.toRadixString(16).padLeft(4, '0')}';
    final buf = StringBuffer();
    for (final rune in text.runes) {
      if (rune > 0xFFFF) {
        // Emit a UTF-16 surrogate pair — a raw \uXXXXX would be parsed as
        // a BMP char plus a literal trailing digit.
        final v = rune - 0x10000;
        buf.write(esc(0xD800 + (v >> 10)));
        buf.write(esc(0xDC00 + (v & 0x3FF)));
      } else if (rune > 0x7E ||
          rune == 0x3C ||
          rune == 0x3E ||
          rune == 0x26 ||
          rune == 0x27) {
        buf.write(esc(rune));
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  /// Strips null-valued keys from the top-level profile map and from every
  /// typed sub-model (items, enchantments, currencies, etc.). Raw `dynamic`
  /// fields (merchantData, missionStatesMap, ...) pass through verbatim.
  static Map<String, dynamic> _cleanProfileMap(Map<String, dynamic> json) {
    final out = <String, dynamic>{};
    json.forEach((key, value) {
      if (value == null) return;
      out[key] = _cleanTypedValue(key, value);
    });
    return out;
  }

  static const Set<String> _typedListKeys = {
    'items',
    'storageChestItems',
    'currency',
    'cosmetics',
  };

  static const Set<String> _typedMapKeys = {
    'difficulties',
    'threatLevels',
  };

  static const Set<String> _typedValueMapKeys = {
    'lobbychest_progress',
    'progress',
  };

  static dynamic _cleanTypedValue(String key, dynamic value) {
    if (_typedListKeys.contains(key) && value is List) {
      return [for (final e in value) _stripNulls(e)];
    }
    if (_typedMapKeys.contains(key) && value is Map<String, dynamic>) {
      return _stripNulls(value);
    }
    if (_typedValueMapKeys.contains(key) && value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _stripNulls(v)));
    }
    return value;
  }

  static dynamic _stripNulls(dynamic node) {
    if (node is Map) {
      final out = <String, dynamic>{};
      node.forEach((key, value) {
        if (value == null) return;
        out[key as String] = _stripNullsInTypedModel(key, value);
      });
      return out;
    }
    if (node is List) {
      return [for (final e in node) _stripNulls(e)];
    }
    return node;
  }

  static dynamic _stripNullsInTypedModel(String key, dynamic value) {
    // Nested typed models inside an item.
    if ((key == 'enchantments' || key == 'armorproperties') && value is List) {
      return [for (final e in value) _stripNulls(e)];
    }
    if (key == 'netheriteEnchant' && value is Map) {
      return _stripNulls(value);
    }
    return value;
  }
}
