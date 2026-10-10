import 'dart:collection';
import 'item.dart';
import 'currency.dart';
import 'cosmetic.dart';
import 'difficulties.dart';
import 'threats.dart';
import 'lobby_chest.dart';
import 'progress.dart';

/// Character save file model. Wraps the raw JSON map so every field —
/// including ones the editor does not model — round-trips verbatim.
class ProfileSaveFile {
  ProfileSaveFile([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  final Map<String, dynamic> json;

  List<Item>? _items;
  List<Item>? _storageChestItems;

  List<String>? _stringList(String key) {
    final raw = json[key];
    if (raw is! List) return null;
    return raw.cast<String>();
  }

  Map<String, int>? _longMap(String key) {
    final raw = json[key];
    if (raw is! Map) return null;
    return _IntMapView(raw);
  }

  List<String>? get bonusPrerequisites => _stringList('bonus_prerequisites');
  set bonusPrerequisites(List<String>? v) => json['bonus_prerequisites'] = v;

  bool? get clone => json['clone'] as bool?;
  set clone(bool? v) => json['clone'] = v;

  List<Cosmetic>? get cosmetics {
    final raw = json['cosmetics'];
    if (raw is! List) return null;
    return [for (final e in raw) Cosmetic(e as Map<String, dynamic>)];
  }

  set cosmetics(List<Cosmetic>? v) =>
      json['cosmetics'] = v == null ? null : [for (final e in v) e.json];

  List<String>? get cosmeticsEverEquipped => _stringList('cosmeticsEverEquipped');
  set cosmeticsEverEquipped(List<String>? v) => json['cosmeticsEverEquipped'] = v;

  String? get creationDate => json['creationDate'] as String?;
  set creationDate(String? v) => json['creationDate'] = v;

  List<String>? get currenciesFound => _stringList('currenciesFound');
  set currenciesFound(List<String>? v) => json['currenciesFound'] = v;

  List<Currency>? get currency {
    final raw = json['currency'];
    if (raw is! List) return null;
    return [for (final e in raw) Currency(e as Map<String, dynamic>)];
  }

  set currency(List<Currency>? v) =>
      json['currency'] = v == null ? null : [for (final e in v) e.json];

  bool? get customized => json['customized'] as bool?;
  set customized(bool? v) => json['customized'] = v;

  Difficulties? get difficulties {
    final raw = json['difficulties'];
    if (raw is! Map<String, dynamic>) return null;
    return Difficulties(raw);
  }

  set difficulties(Difficulties? v) => json['difficulties'] = v?.json;

  dynamic get endGameContentProgress => json['endGameContentProgress'];
  set endGameContentProgress(dynamic v) => json['endGameContentProgress'] = v;

  Map<String, int>? get finishedObjectiveTags => _longMap('finishedObjectiveTags');
  set finishedObjectiveTags(Map<String, int>? v) => json['finishedObjectiveTags'] = v;

  List<Item>? get items => _items ??= _wrapItems(json['items']);
  set items(List<Item>? v) {
    _items = v;
    json['items'] = v == null ? null : [for (final e in v) e.json];
  }

  List<String>? get itemsFound => _stringList('itemsFound');
  set itemsFound(List<String>? v) => json['itemsFound'] = v;

  double? get legendaryStatus => (json['legendaryStatus'] as num?)?.toDouble();
  set legendaryStatus(double? v) => json['legendaryStatus'] = v;

  Map<String, LobbychestProgress>? get lobbychestProgress {
    final raw = json['lobbychest_progress'];
    if (raw is! Map<String, dynamic>) return null;
    return raw.map((k, v) =>
        MapEntry(k, LobbychestProgress(v as Map<String, dynamic>)));
  }

  set lobbychestProgress(Map<String, LobbychestProgress>? v) =>
      json['lobbychest_progress'] =
          v == null ? null : v.map((k, e) => MapEntry(k, e.json));

  dynamic get mapUiState => json['mapUIState'];
  set mapUiState(dynamic v) => json['mapUIState'] = v;

  /// Merchant definitions. Kept as raw JSON — the editor never edits them.
  Map<String, dynamic>? get merchantData => json['merchantData'] as Map<String, dynamic>?;
  set merchantData(Map<String, dynamic>? v) => json['merchantData'] = v;

  dynamic get missionStatesMap => json['missionStatesMap'];
  set missionStatesMap(dynamic v) => json['missionStatesMap'] = v;

  Map<String, int>? get mobKills => _longMap('mob_kills');
  set mobKills(Map<String, int>? v) => json['mob_kills'] = v;

  String? get name => json['name'] as String?;
  set name(String? v) => json['name'] = v;

  dynamic get pendingRewardItem => json['pendingRewardItem'];
  set pendingRewardItem(dynamic v) => json['pendingRewardItem'] = v;

  dynamic get pendingRewardItems => json['pendingRewardItems'];
  set pendingRewardItems(dynamic v) => json['pendingRewardItems'] = v;

  String? get playerId => json['playerId'] as String?;
  set playerId(String? v) => json['playerId'] = v;

  Map<String, Progress>? get progress {
    final raw = json['progress'];
    if (raw is! Map<String, dynamic>) return null;
    return raw.map((k, v) => MapEntry(k, Progress(v as Map<String, dynamic>)));
  }

  set progress(Map<String, Progress>? v) =>
      json['progress'] = v == null ? null : v.map((k, e) => MapEntry(k, e.json));

  Map<String, int>? get progressStatCounters => _longMap('progressStatCounters');
  set progressStatCounters(Map<String, int>? v) => json['progressStatCounters'] = v;

  List<String>? get progressionKeys => _stringList('progressionKeys');
  set progressionKeys(List<String>? v) => json['progressionKeys'] = v;

  String? get skin => json['skin'] as String?;
  set skin(String? v) => json['skin'] = v;

  dynamic get storageChestAnnouncement => json['storageChestAnnouncement'];
  set storageChestAnnouncement(dynamic v) => json['storageChestAnnouncement'] = v;

  List<Item>? get storageChestItems =>
      _storageChestItems ??= _wrapItems(json['storageChestItems']);
  set storageChestItems(List<Item>? v) {
    _storageChestItems = v;
    json['storageChestItems'] =
        v == null ? null : [for (final e in v) e.json];
  }

  Map<String, bool>? get strongholdProgress {
    final raw = json['strongholdProgress'];
    if (raw is! Map<String, dynamic>) return null;
    return raw.map((k, v) => MapEntry(k, v as bool));
  }

  set strongholdProgress(Map<String, bool>? v) => json['strongholdProgress'] = v;

  ThreatLevels? get threatLevels {
    final raw = json['threatLevels'];
    if (raw is! Map<String, dynamic>) return null;
    return ThreatLevels(raw);
  }

  set threatLevels(ThreatLevels? v) => json['threatLevels'] = v?.json;

  int? get timestamp => (json['timestamp'] as num?)?.toInt();
  set timestamp(int? v) => json['timestamp'] = v;

  int? get totalGearPower => (json['totalGearPower'] as num?)?.toInt();
  set totalGearPower(int? v) => json['totalGearPower'] = v;

  List<dynamic>? get trialsCompleted => json['trialsCompleted'] as List<dynamic>?;
  set trialsCompleted(List<dynamic>? v) => json['trialsCompleted'] = v;

  List<dynamic>? get uiHintsExpired => json['uiHintsExpired'] as List<dynamic>?;
  set uiHintsExpired(List<dynamic>? v) => json['uiHintsExpired'] = v;

  String? get uniqueSaveId => json['uniqueSaveId'] as String?;
  set uniqueSaveId(String? v) => json['uniqueSaveId'] = v;

  int? get version => (json['version'] as num?)?.toInt();
  set version(int? v) => json['version'] = v;

  List<String>? get videosPlayed => _stringList('videosPlayed');
  set videosPlayed(List<String>? v) => json['videosPlayed'] = v;

  int get xp => (json['xp'] as num?)?.toInt() ?? 0;
  set xp(int v) => json['xp'] = v;

  List<Item>? _wrapItems(dynamic raw) {
    if (raw is! List) return null;
    return [for (final e in raw) Item(e as Map<String, dynamic>)];
  }
}

/// Live view over the underlying JSON `Map` — reads coerce `num` to `int`
/// and writes update the stored map (upstream returns the raw Dictionary).
class _IntMapView extends MapBase<String, int> {
  _IntMapView(this._inner);
  final Map<dynamic, dynamic> _inner;

  @override
  int? operator [](Object? key) => (_inner[key] as num?)?.toInt();

  @override
  void operator []=(String key, int value) => _inner[key] = value;

  @override
  Iterable<String> get keys => _inner.keys.map((k) => '$k');

  @override
  void clear() => _inner.clear();

  @override
  int? remove(Object? key) => (_inner.remove(key) as num?)?.toInt();
}
