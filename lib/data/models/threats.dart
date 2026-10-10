/// ThreatLevels model (map-backed).
class ThreatLevels {
  ThreatLevels([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  final Map<String, dynamic> json;

  String? get unlocked => json['unlocked'] as String?;
  set unlocked(String? v) => json['unlocked'] = v;
}
