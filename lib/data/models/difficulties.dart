import '../enums.dart';

/// Difficulties model (map-backed).
class Difficulties {
  Difficulties([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  final Map<String, dynamic> json;

  DifficultyEnum? get announced => DifficultyEnum.fromJsonName(json['announced'] as String?);
  set announced(DifficultyEnum? v) => json['announced'] = v?.jsonName;

  DifficultyEnum? get selected => DifficultyEnum.fromJsonName(json['selected'] as String?);
  set selected(DifficultyEnum? v) => json['selected'] = v?.jsonName;

  DifficultyEnum get unlocked =>
      DifficultyEnum.fromJsonName(json['unlocked'] as String?) ?? DifficultyEnum.difficulty1;
  set unlocked(DifficultyEnum v) => json['unlocked'] = v.jsonName;
}
