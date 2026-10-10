/// Currency model (map-backed).
class Currency {
  Currency([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  Currency.fromFields({int count = 0, String type = ''})
      : json = <String, dynamic>{'count': count, 'type': type};

  final Map<String, dynamic> json;

  int get count => (json['count'] as num?)?.toInt() ?? 0;
  set count(int v) => json['count'] = v;

  String get type => json['type'] as String? ?? '';
  set type(String v) => json['type'] = v;
}
