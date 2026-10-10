import 'objects.dart';

/// Ported from FModel `Paks.cs` — merges raw pak entries into a virtual
/// package map (dropping .uexp/.ubulk/.uptnl sidecars and linking them to
/// their .uasset/.umap).
abstract final class Paks {
  static Map<String, FPakEntry> merge(
      Map<String, FPakEntry> tempFiles, String mount) {
    final files = <String, FPakEntry>{};
    for (final entry in tempFiles.values) {
      if (!entry.name.contains('.')) continue;
      final ext = entry.extension;
      if (files.containsKey(mount + entry.pathWithoutExtension) ||
          ext == '.uptnl' ||
          ext == '.uexp' ||
          ext == '.ubulk') {
        continue;
      }

      if (entry.isUE4Package()) {
        final umapName = _changeExtension(entry.name, '.umap');
        if (!tempFiles.containsKey(umapName)) {
          final uexpName = _changeExtension(entry.name, '.uexp');
          final uexp = tempFiles[uexpName];
          if (uexp != null) entry.uexp = uexp;

          final ubulkName = _changeExtension(entry.name, '.ubulk');
          final ubulk = tempFiles[ubulkName];
          if (ubulk != null) {
            entry.ubulk = ubulk;
          } else {
            final ufontName = _changeExtension(entry.name, '.ufont');
            final ufont = tempFiles[ufontName];
            if (ufont != null) entry.ubulk = ufont;
          }
        }
      } else if (entry.isUE4Map()) {
        final uexp = tempFiles[_changeExtension(entry.name, '.uexp')];
        if (uexp != null) entry.uexp = uexp;
        final ubulk = tempFiles[_changeExtension(entry.name, '.ubulk')];
        if (ubulk != null) entry.ubulk = ubulk;
      }

      files[mount + entry.pathWithoutExtension] = entry;
    }
    return files;
  }

  static String _changeExtension(String path, String newExt) {
    final idx = path.lastIndexOf('.');
    if (idx < 0) return path + newExt;
    return path.substring(0, idx) + newExt;
  }
}
