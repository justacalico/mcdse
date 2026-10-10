import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/data/models/cosmetic.dart';
import 'package:mcdse/data/models/currency.dart';
import 'package:mcdse/data/models/difficulties.dart';
import 'package:mcdse/data/models/item.dart';
import 'package:mcdse/data/models/lobby_chest.dart';
import 'package:mcdse/data/models/profile_save_file.dart';
import 'package:mcdse/data/models/progress.dart';
import 'package:mcdse/data/models/threats.dart';

void main() {
  test('scalar accessors round-trip through json', () {
    final p = ProfileSaveFile();
    p.clone = true;
    p.creationDate = '2020-01-01';
    p.customized = true;
    p.endGameContentProgress = {'a': 1};
    p.legendaryStatus = 1.5;
    p.mapUiState = {'x': true};
    p.merchantData = {'m': 2};
    p.missionStatesMap = {'k': 'v'};
    p.name = 'Hero';
    p.pendingRewardItem = {'type': 'Sword'};
    p.pendingRewardItems = [];
    p.playerId = 'pid';
    p.skin = 'skin';
    p.storageChestAnnouncement = 3;
    p.timestamp = 42;
    p.totalGearPower = 999;
    p.trialsCompleted = ['t'];
    p.uiHintsExpired = ['h'];
    p.uniqueSaveId = 'uid';
    p.version = 7;
    p.xp = 123;
    expect(p.clone, true);
    expect(p.creationDate, '2020-01-01');
    expect(p.customized, true);
    expect(p.endGameContentProgress, {'a': 1});
    expect(p.legendaryStatus, 1.5);
    expect(p.mapUiState, {'x': true});
    expect(p.merchantData, {'m': 2});
    expect(p.missionStatesMap, {'k': 'v'});
    expect(p.name, 'Hero');
    expect(p.pendingRewardItem, {'type': 'Sword'});
    expect(p.pendingRewardItems, []);
    expect(p.playerId, 'pid');
    expect(p.skin, 'skin');
    expect(p.storageChestAnnouncement, 3);
    expect(p.timestamp, 42);
    expect(p.totalGearPower, 999);
    expect(p.trialsCompleted, ['t']);
    expect(p.uiHintsExpired, ['h']);
    expect(p.uniqueSaveId, 'uid');
    expect(p.version, 7);
    expect(p.xp, 123);
    expect(p.json['xp'], 123);
  });

  test('string-list accessors', () {
    final p = ProfileSaveFile();
    expect(p.bonusPrerequisites, isNull);
    p.bonusPrerequisites = ['a'];
    p.cosmeticsEverEquipped = ['b'];
    p.currenciesFound = ['Emerald'];
    p.itemsFound = ['Sword'];
    p.progressionKeys = ['k'];
    p.videosPlayed = ['v'];
    expect(p.bonusPrerequisites, ['a']);
    expect(p.cosmeticsEverEquipped, ['b']);
    expect(p.currenciesFound, ['Emerald']);
    expect(p.itemsFound, ['Sword']);
    expect(p.progressionKeys, ['k']);
    expect(p.videosPlayed, ['v']);
    expect(ProfileSaveFile({'itemsFound': 'nope'}).itemsFound, isNull);
  });

  test('int-map accessors coerce num and write through', () {
    final p = ProfileSaveFile({
      'mob_kills': {'zombie': 3},
      'progressStatCounters': {'a': 1.5},
      'finishedObjectiveTags': {},
    });
    expect(p.mobKills!['zombie'], 3);
    p.mobKills!['creeper'] = 2;
    expect(p.json['mob_kills']['creeper'], 2);
    expect(p.progressStatCounters!['a'], 1);
    p.mobKills!.remove('zombie');
    expect(p.mobKills!.keys, ['creeper']);
    p.finishedObjectiveTags!.clear();
    expect(p.json['finishedObjectiveTags'], isEmpty);
    p.mobKills = {'x': 9};
    expect(p.json['mob_kills'], {'x': 9});
    expect(ProfileSaveFile().mobKills, isNull);
    expect(ProfileSaveFile({'mob_kills': 1}).mobKills, isNull);
  });

  test('item lists cache and write through to json', () {
    final p = ProfileSaveFile({
      'items': [
        {'type': 'Sword'}
      ],
      'storageChestItems': [
        {'type': 'Bow'}
      ],
    });
    expect(p.items!.single.type, 'Sword');
    expect(p.storageChestItems!.single.type, 'Bow');
    p.items!.add(Item.fromFields(type: 'Axe', power: 5));
    expect(p.items, hasLength(2));
    p.items = p.items;
    expect(p.json['items'], hasLength(2));
    p.storageChestItems = null;
    expect(p.json['storageChestItems'], isNull);
    expect(ProfileSaveFile().items, isNull);
    expect(ProfileSaveFile({'items': 'x'}).items, isNull);
  });

  test('object accessors wrap raw json', () {
    final p = ProfileSaveFile({
      'currency': [
        {'type': 'Emerald', 'count': 5}
      ],
      'cosmetics': [
        {'id': 'c1'}
      ],
      'difficulties': <String, dynamic>{},
      'lobbychest_progress': {
        'k': <String, dynamic>{}
      },
      'progress': {
        'p': <String, dynamic>{}
      },
      'strongholdProgress': {'s': true},
      'threatLevels': <String, dynamic>{},
    });
    expect(p.currency!.single, isA<Currency>());
    expect(p.cosmetics!.single, isA<Cosmetic>());
    expect(p.difficulties, isA<Difficulties>());
    expect(p.lobbychestProgress!['k'], isA<LobbychestProgress>());
    expect(p.progress!['p'], isA<Progress>());
    expect(p.strongholdProgress, {'s': true});
    expect(p.threatLevels, isA<ThreatLevels>());
    final c = Currency.fromFields(count: 7, type: 'Gold');
    p.currency = [c];
    expect(p.json['currency'], [c.json]);
    final cos = Cosmetic({'id': 'z'});
    p.cosmetics = [cos];
    expect(p.json['cosmetics'], [cos.json]);
    p.difficulties = Difficulties(<String, dynamic>{});
    expect(p.json['difficulties'], isA<Map>());
    p.progress = {'q': Progress(<String, dynamic>{})};
    expect(p.json['progress']['q'], isA<Map>());
    p.strongholdProgress = {'x': false};
    expect(p.json['strongholdProgress'], {'x': false});
    p.threatLevels = ThreatLevels(<String, dynamic>{});
    expect(p.json['threatLevels'], isA<Map>());
    expect(ProfileSaveFile().currency, isNull);
    expect(ProfileSaveFile().cosmetics, isNull);
    expect(ProfileSaveFile().difficulties, isNull);
    expect(ProfileSaveFile().lobbychestProgress, isNull);
    expect(ProfileSaveFile().progress, isNull);
    expect(ProfileSaveFile().strongholdProgress, isNull);
    expect(ProfileSaveFile().threatLevels, isNull);
    expect(ProfileSaveFile({'currency': 'x'}).currency, isNull);
    expect(ProfileSaveFile().xp, 0);
  });
}
