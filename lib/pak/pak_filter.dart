/// Ported from `Pak/PakFilter.cs` — a prefix filter over entry paths.
class PakFilter {
  PakFilter(Iterable<String>? filter, {bool caseSensitive = true})
      : _filter = [
          if (filter != null)
            for (final f in filter)
              caseSensitive ? f : f.toLowerCase(),
        ],
        caseSensitive = caseSensitive;

  final List<String> _filter;
  final bool caseSensitive;

  bool addFilter(String filter) {
    final f = caseSensitive ? filter : filter.toLowerCase();
    if (_filter.contains(f)) return false;
    _filter.add(f);
    return true;
  }

  bool checkFilter(String path, bool pathCaseSensitive) {
    var p = path;
    if (pathCaseSensitive && !caseSensitive) {
      p = p.toLowerCase();
    }
    for (final f in _filter) {
      if (p.startsWith(f)) return true;
    }
    return false;
  }

  List<String> get filters => List.unmodifiable(_filter);
}
