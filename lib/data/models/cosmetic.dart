/// Cosmetic model (map-backed).
class Cosmetic {
  Cosmetic([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  final Map<String, dynamic> json;

  String get id => json['id'] as String? ?? '';
  set id(String v) => json['id'] = v;

  String get type => json['type'] as String? ?? '';
  set type(String v) => json['type'] = v;
}
