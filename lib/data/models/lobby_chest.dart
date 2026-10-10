/// LobbychestProgress model (map-backed).
class LobbychestProgress {
  LobbychestProgress([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  final Map<String, dynamic> json;

  int get unlockedTimes => (json['unlockedTimes'] as num?)?.toInt() ?? 0;
  set unlockedTimes(int v) => json['unlockedTimes'] = v;
}
