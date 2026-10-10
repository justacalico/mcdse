/// Save-file enchantment model (map-backed for perfect round-tripping).
class Enchantment {
  Enchantment([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  Enchantment.fromFields({String id = '', int? investedPoints, int level = 0})
      : json = <String, dynamic>{
          'id': id,
          'investedPoints': ?investedPoints,
          'level': level,
        };

  final Map<String, dynamic> json;

  String get id => json['id'] as String? ?? '';
  set id(String v) => json['id'] = v;

  int? get investedPoints => (json['investedPoints'] as num?)?.toInt();
  set investedPoints(int? v) => json['investedPoints'] = v;

  int get level => (json['level'] as num?)?.toInt() ?? 0;
  set level(int v) => json['level'] = v;

  Enchantment copy() {
    // NOTE: upstream Copy() only copies Id and Level.
    return Enchantment.fromFields(id: id, level: level);
  }

  // Two Enchantment wrappers are equal when they wrap the same JSON map —
  // required because `Item.enchantments` rebuilds wrappers on each call and
  // `indexOf`/`remove` in the view models rely on equality.
  @override
  bool operator ==(Object other) =>
      other is Enchantment && identical(other.json, json);

  @override
  int get hashCode => identityHashCode(json);
}
