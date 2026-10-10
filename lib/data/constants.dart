import 'dart:io';

import 'enums.dart';
import 'models/item.dart';
import '../services/settings_store.dart';

/// Constants ported from MCDSaveEdit's `Data/Constants/*`.
abstract final class Constants {
  static const String applicationName = 'MCDSaveEdit';
  static const String applicationTitle = 'Minecraft Dungeons Save File Editor';
  static const String currentVersionNumber = '0.1.0';

  /// GitLab project used for the in-app update check.
  static const String gitlabNamespace = 'HttpAnimations';
  static const String gitlabProject = 'mcdse';
  static const String latestReleaseUrl =
      'https://gitlab.com/$gitlabNamespace/$gitlabProject/-/releases';
  static const String releasesApiUrl =
      'https://gitlab.com/api/v4/projects/HttpAnimations%2Fmcdse'
      '/releases?per_page=100&order_by=released_at&sort=desc';

  static const String pakFileLocationKey = 'PakFilesPath';
  static const String langSpecifierKey = 'LangSpecifier';
  static const int maxRecentFiles = 10;

  static const int maximumInventoryItemCount = 300;

  static const int minimumEnchantmentTier = 0;
  static const int maximumEnchantmentTier = 3;

  static const int minimumCharacterLevel = 1;
  static const int maximumCharacterLevel = 1000000000;

  static const int minimumItemLevel = 0;
  static const int maximumItemLevel = 1000000000;

  static const int maximumEnchantmentOptionsPerItem = 9;
  static const String defaultEnchantmentId = 'Unset';

  // These are the names found in the character save files.
  static const String emeraldCurrencyName = 'Emerald';
  static const String goldCurrencyName = 'Gold';
  static const String eyeOfEnderCurrencyName = 'EyeOfEnder';

  static const String defaultLangSpecifier = 'en';

  // ---- File system data ----

  static const String paksFilterString = '/Dungeons/Content';
  static const String firstPakFilename = 'pakchunk0-WindowsNoEditor.pak';

  /// NOTE: default location of files for Launcher version.
  static String get launcherPaksFolderPath {
    final localAppData =
        Platform.environment['LOCALAPPDATA'] ?? Platform.environment['HOME'] ?? '';
    return '$localAppData/Mojang/products/dungeons/dungeons/Dungeons/Content/Paks';
  }

  /// NOTE: default location of files for Steam version.
  static String get steamPaksFolderPath {
    if (Platform.isWindows) {
      final pf86 = Platform.environment['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)';
      return '$pf86\\Steam\\steamapps\\common\\MinecraftDungeons\\Dungeons\\Content\\Paks';
    }
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.steam/steam/steamapps/common/MinecraftDungeons/Dungeons/Content/Paks';
  }

  /// NOTE: default location of files for XBoxGames version.
  static String get xboxPcGamesPaksFolderPath {
    if (Platform.isWindows) {
      final root = Platform.environment['SYSTEMDRIVE'] ?? 'C:';
      return '$root\\XboxGames\\Minecraft Dungeons\\Content\\Dungeons\\Content\\Paks';
    }
    return '/XboxGames/Minecraft Dungeons/Content/Dungeons/Content/Paks';
  }

  /// NOTE: default location of save game files.
  static String get fileDialogInitialDirectory {
    // Prefer a save directory that actually exists (handles Proton/Steam
    // installs where saves live inside the compatdata prefix).
    final detected = detectedSaveDirectories();
    if (detected.isNotEmpty) return detected.first;
    final userFolderPath = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (Platform.isWindows) {
      return '$userFolderPath\\Saved Games\\Mojang Studios\\Dungeons';
    }
    return '$userFolderPath/Saved Games/Mojang Studios/Dungeons';
  }

  static const int mcdSteamAppId = 1672970;

  /// Every existing `Saved Games/Mojang Studios/Dungeons` directory we can
  /// find — native, Launcher, and Steam/Proton (inside compatdata prefixes
  /// across all Steam libraries).
  static List<String> detectedSaveDirectories() {
    final candidates = <String>{};
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isNotEmpty) {
      candidates.add(
          '$home${Platform.isWindows ? '\\' : '/'}Saved Games${Platform.isWindows ? '\\' : '/'}Mojang Studios${Platform.isWindows ? '\\' : '/'}Dungeons');
    }
    const suffix = 'steamapps/compatdata/$mcdSteamAppId/pfx/drive_c/'
        'users/steamuser/Saved Games/Mojang Studios/Dungeons';
    for (final lib in _steamLibraryFolders()) {
      candidates.add('$lib/$suffix');
    }
    // The picked pak folder reveals the steamapps root — compatdata sits
    // next to common/.
    final paksPath = _settingsPakPath();
    if (paksPath != null && paksPath.contains('steamapps/common')) {
      final steamapps =
          paksPath.substring(0, paksPath.indexOf('steamapps/common') + 9);
      candidates.add('$steamapps/compatdata/$mcdSteamAppId/pfx/drive_c/'
          'users/steamuser/Saved Games/Mojang Studios/Dungeons');
    }
    return candidates
        .where((d) => Directory(d).existsSync())
        .toList(growable: false);
  }

  static String? _settingsPakPath() {
    try {
      return SettingsStore.getSetting(pakFileLocationKey, '');
    } catch (_) {
      return null;
    }
  }

  /// Steam library roots: well-known install dirs plus every `"path"` entry
  /// in each `steamapps/libraryfolders.vdf`.
  static Set<String> _steamLibraryFolders() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final roots = <String>{
      if (home.isNotEmpty) ...[
        '$home/.steam/steam',
        '$home/.steam/debian-installation',
        '$home/.local/share/Steam',
        '$home/snap/steam/common/.steam/steam',
        '$home/.var/app/com.valvesoftware.Steam/.steam/steam',
        '$home/.var/app/com.valvesoftware.Steam/.local/share/Steam',
      ],
      '/mnt/SteamLibrary',
    };
    final libs = {...roots};
    final pathRe = RegExp(r'"path"\s+"([^"]+)"');
    for (final root in roots) {
      try {
        final vdf = File('$root/steamapps/libraryfolders.vdf');
        if (vdf.existsSync()) {
          for (final m in pathRe.allMatches(vdf.readAsStringSync())) {
            libs.add(m.group(1)!.replaceAll('\\\\', '/'));
          }
        }
      } catch (_) {}
    }
    return libs;
  }

  /// Save .dat files found inside the detected save directories —
  /// `savefile.dat` plus every `*/Characters/*.dat` — newest first.
  static List<File> detectedSaveFiles() {
    final files = <File>[];
    for (final dir in detectedSaveDirectories()) {
      for (final entity in Directory(dir).listSync()) {
        if (entity is File && entity.path.endsWith('.dat')) {
          files.add(entity);
        } else if (entity is Directory) {
          // Account folders hold savefile.dat + a Characters/ subdir.
          files.addAll(entity
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.dat')));
          final chars = Directory('${entity.path}/Characters');
          if (chars.existsSync()) {
            files.addAll(chars
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.dat')));
          }
        }
      }
    }
    files.sort((a, b) => b
        .lastModifiedSync()
        .compareTo(a.lastModifiedSync()));
    return files;
  }

  static const String encryptedFileExtension = '.dat';
  static const String decryptedFileExtension = '.json';

  // ---- Item data ----

  static const String defaultArmorPropertyId = 'AllyDamageBoost';
  static const String defaultMeleeWeaponId = 'Sword';
  static const String defaultArmorId = 'ArchersStrappings';
  static const String defaultRangedWeaponId = 'Bow';
  static const String defaultArtifactId = 'FireworksArrowItem';

  static String defaultItemIdForEquipmentSlot(EquipmentSlotEnum equipmentSlot) {
    return defaultItemIdForFilter(itemFilterForEquipmentSlot(equipmentSlot));
  }

  static String defaultItemIdForFilter(ItemFilterEnum filter) {
    switch (filter) {
      case ItemFilterEnum.meleeWeapons:
        return defaultMeleeWeaponId;
      case ItemFilterEnum.armor:
        return defaultArmorId;
      case ItemFilterEnum.rangedWeapons:
        return defaultRangedWeaponId;
      case ItemFilterEnum.artifacts:
        return defaultArtifactId;
      default:
        throw ArgumentError.value(filter, 'filter', 'Invalid filter value');
    }
  }

  static ItemFilterEnum itemFilterForEquipmentSlot(EquipmentSlotEnum equipmentSlot) {
    switch (equipmentSlot) {
      case EquipmentSlotEnum.meleeGear:
        return ItemFilterEnum.meleeWeapons;
      case EquipmentSlotEnum.armorGear:
        return ItemFilterEnum.armor;
      case EquipmentSlotEnum.rangedGear:
        return ItemFilterEnum.rangedWeapons;
      case EquipmentSlotEnum.hotbarSlot1:
      case EquipmentSlotEnum.hotbarSlot2:
      case EquipmentSlotEnum.hotbarSlot3:
        return ItemFilterEnum.artifacts;
    }
  }

  static Item createDefaultItemForFilter(ItemFilterEnum filter) {
    final itemId = defaultItemIdForFilter(filter);
    return Item.fromFields(
      markedNew: true,
      upgraded: false,
      power: 1,
      rarity: Rarity.common,
      type: itemId,
    );
  }

  static Item createDefaultItemForEquipmentSlot(EquipmentSlotEnum equipmentSlot) {
    final itemId = defaultItemIdForEquipmentSlot(equipmentSlot);
    return Item.fromFields(
      markedNew: true,
      upgraded: false,
      power: 1,
      rarity: Rarity.common,
      type: itemId,
      equipmentSlot: equipmentSlot.jsonName,
    );
  }

  // ---- Enchantment data ----

  static final Set<String> powerful = {
    'Backstabber',
    'FinalShout',
    'Chilling',
    'Protection',
    'PotionThirstMelee',
    'PotionThirstRanged',
    'GravityPulse',
    'CriticalHit',
    'Exploding',
    'RadianceMelee',
    'GravityMelee',
    'Shockwave',
    'Swirling',
    'Gravity',
    'TempoTheft',
    'ChainReaction',
    'RadianceRanged',
    'ShockWeb',
    'VoidTouchedMelee',
    'VoidTouchedRanged',
    'MultiCharge',
    'DeathBarter',
    'FireFocus',
    'LightningFocus',
    'MultiDodge',
    'PoisonFocus',
    'SoulFocus',
  };

  static final Set<String> forArmor = {
    'Swiftfooted',
    'PotionFortification',
    'Snowing',
    'SurpriseGift',
    'Burning',
    'Cowardice',
    'Deflecting',
    'Electrified',
    'Thorns',
    'Explorer',
    'Frenzied',
    'Celerity',
    'Recycler',
    'FoodReserves',
    'FireTrail',
    'HealthSynergy',
    'SpeedSynergy',
    'SpiritSpeed',
    'FinalShout',
    'Chilling',
    'Protection',
    'GravityPulse',
  };

  static final Set<String> forMelee = {
    'Weakening',
    'FireAspect',
    'Looting',
    'Chains',
    'Echo',
    'Stunning',
    'Rampaging',
    'Freezing',
    'Committed',
    'PoisonedMelee',
    'Prospector',
    'EnigmaResonatorMelee',
    'SoulSiphon',
    'Thundering',
    'Sharpness',
    'Leeching',
    'CriticalHit',
    'Exploding',
    'RadianceMelee',
    'GravityMelee',
    'Shockwave',
    'Swirling',
  };

  static final Set<String> forRanged = {
    'Accelerating',
    'Growing',
    'AnimaConduitRanged',
    'RapidFire',
    'Infinity',
    'Unchanting',
    'Piercing',
    'Power',
    'WildRage',
    'Punch',
    'Ricochet',
    'Supercharge',
    'FuseShot',
    'BonusShot',
    'FireAspect',
    'MultiShot',
    'Gravity',
    'TempoTheft',
    'ChainReaction',
    'RadianceRanged',
  };
}
