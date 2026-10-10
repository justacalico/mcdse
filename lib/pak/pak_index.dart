import 'dart:io';
import 'dart:typed_data';

import 'objects.dart';
import 'pak_file_reader.dart';
import 'pak_filter.dart';
import 'pak_package.dart';

/// Ported from `Pak/PakIndex.cs` — the aggregate of all .pak files in a
/// directory, keyed by mount-relative path.
class PakIndex {
  PakIndex({required String path, bool cacheFiles = true, bool caseSensitive = true, this._filter})
      : _caseSensitive = caseSensitive,
        _cacheFiles = cacheFiles {
    if (cacheFiles) _cachedFiles = {};
    for (final entity in Directory(path)
        .listSync()
        .where((e) => e is File && e.path.endsWith('.pak'))) {
      pakFiles.add(PakFileReader(entity.path, caseSensitive: caseSensitive));
    }
  }

  PakIndex.fromFiles(Iterable<String> files,
      {bool cacheFiles = true, bool caseSensitive = true, this._filter})
      : _caseSensitive = caseSensitive,
        _cacheFiles = cacheFiles {
    if (cacheFiles) _cachedFiles = {};
    for (final file in files) {
      pakFiles.add(PakFileReader(file, caseSensitive: caseSensitive));
    }
  }

  final bool _caseSensitive;
  final bool _cacheFiles;
  final PakFilter? _filter;

  final List<PakFileReader> pakFiles = [];
  int get pakFileCount => pakFiles.length;

  late Map<String, Uint8List?> _cachedFiles;

  int useKey(Uint8List key, [FGuid? encryptionGuid]) {
    var n = 0;
    for (final pak in pakFiles) {
      if (pak.initialized) continue;
      if (encryptionGuid != null &&
          pak.info.encryptionKeyGuid != null &&
          encryptionGuid != pak.info.encryptionKeyGuid) {
        continue;
      }
      final err = pak.tryReadIndex(key, _filter);
      if (err == null) n++;
    }
    return n;
  }

  int useKeys(Iterable<Uint8List> keys) {
    var n = 0;
    for (final key in keys) {
      n += useKey(key);
    }
    return n;
  }

  /// Iterates every file path (mount point + entry key, which itself is
  /// mount-prefixed by `Paks.merge`). Upstream relies on the resulting
  /// `//` junction — resolvers strip it via `indexOf('//') + 1`.
  Iterable<String> get filePaths sync* {
    for (final pak in pakFiles) {
      if (!pak.initialized) continue;
      for (final file in pak.entries.keys) {
        yield pak.mountPoint + file;
      }
    }
  }

  int get fileCount {
    var n = 0;
    for (final pak in pakFiles) {
      if (pak.initialized) n += pak.entries.length;
    }
    return n;
  }

  Uint8List? getFile(String path) => tryGetFile(path);

  Uint8List? tryGetFile(String path) {
    var p = _caseSensitive ? path : path.toLowerCase();
    if (_cacheFiles && _cachedFiles.containsKey(p)) {
      return _cachedFiles[p];
    }
    for (final pak in pakFiles) {
      if (!pak.initialized) continue;
      if (p.startsWith(pak.mountPoint)) {
        final (uasset, _, _) = pak.tryGetFile(p);
        if (uasset != null) {
          if (_cacheFiles) _cachedFiles[p] = uasset;
          return uasset;
        }
      }
    }
    return null;
  }

  final Map<String, PakPackage> _packages = {};

  PakPackage? tryGetPackage(String path) {
    final cached = _packages[path];
    if (cached != null) return cached;
    for (final pak in pakFiles) {
      if (!pak.initialized) continue;
      if (!path.startsWith(pak.mountPoint)) continue;
      final (uasset, uexp, ubulk) = pak.tryGetFile(path);
      // Entry not in this pak — keep looking in the others.
      if (uasset == null) continue;
      if (uexp == null) return null;
      final package = PakPackage(uasset, uexp, ubulk);
      _packages[path] = package;
      return package;
    }
    return null;
  }
}
