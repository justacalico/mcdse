/// Mission progress model (map-backed).
class Progress {
  Progress([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  final Map<String, dynamic> json;

  String? get completedDifficulty => json['completedDifficulty'] as String?;
  set completedDifficulty(String? v) => json['completedDifficulty'] = v;

  int get completedEndlessStruggle =>
      (json['completedEndlessStruggle'] as num?)?.toInt() ?? 0;
  set completedEndlessStruggle(int v) => json['completedEndlessStruggle'] = v;

  String? get completedThreatLevel => json['completedThreatLevel'] as String?;
  set completedThreatLevel(String? v) => json['completedThreatLevel'] = v;
}
