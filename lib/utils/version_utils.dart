/// Small semver parser/comparator — no external dependency.
class Version implements Comparable<Version> {
  const Version(this.major, this.minor, this.patch,
      [this.extra = const <int>[]]);

  final int major;
  final int minor;
  final int patch;
  final List<int> extra;

  /// Parses strings like `1.2.3`, `v1.2.3`, `1.5.8.0`.
  /// Returns null when the text is not version-shaped.
  static Version? tryParse(String text) {
    var input = text.trim();
    if (input.startsWith('v') || input.startsWith('V')) {
      input = input.substring(1);
    }
    // Strip any prerelease/build suffixes.
    input = input.split(RegExp(r'[-+]')).first;
    final parts = input.split('.');
    if (parts.isEmpty) return null;
    final nums = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null) return null;
      nums.add(n);
    }
    while (nums.length < 3) {
      nums.add(0);
    }
    return Version(nums[0], nums[1], nums[2], nums.sublist(3));
  }

  @override
  int compareTo(Version other) {
    final a = [major, minor, patch, ...extra];
    final b = [other.major, other.minor, other.patch, ...other.extra];
    for (var i = 0; i < a.length || i < b.length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }

  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >=(Version other) => compareTo(other) >= 0;
  bool operator <=(Version other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is Version && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, Object.hashAll(extra));

  @override
  String toString() =>
      [major, minor, patch, ...extra].join('.');
}
