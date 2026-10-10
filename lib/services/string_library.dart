import '../data/string_mismatches.dart';
import 'event_logger.dart';

/// Ported from `Services/Databases/StringLibrary.cs` (`R`).
///
/// Carries the bundled English strings plus external strings loaded from the
/// game's `.locres` files when game content is available.
abstract final class R {
  static Map<String, String> _itemType = {};
  static Map<String, String> _enchantment = {};
  static Map<String, String> _armorProperties = {};
  static Map<String, String> _mission = {};
  static Map<String, String> _clickys = {};

  static bool isStringsLoaded = false;

  static int get totalStringCount =>
      _itemType.length +
      _enchantment.length +
      _armorProperties.length +
      _mission.length +
      _clickys.length;

  static void loadExternalStrings(
      Map<String, Map<String, String>> stringLibrary) {
    final itemDict = stringLibrary['ItemType'];
    if (itemDict != null) {
      _itemType = itemDict.map((k, v) => MapEntry(k.trim(), v));
    }
    final enchantmentDict = stringLibrary['Enchantment'];
    if (enchantmentDict != null) {
      _enchantment = enchantmentDict.map((k, v) => MapEntry(k.trim(), v));
    }
    final armorPropertyDict = stringLibrary['ArmorProperties'];
    if (armorPropertyDict != null) {
      _armorProperties = armorPropertyDict.map((k, v) => MapEntry(k.trim(), v));
    }
    final missionDict = stringLibrary['Mission'];
    if (missionDict != null) {
      _mission = missionDict.map((k, v) => MapEntry(k.trim(), v));
    }

    final clickysDict = stringLibrary[''];
    final realmsDict = stringLibrary['Realms'];
    final dlcDict = stringLibrary['DLC'];
    final ancientLabelsDict = stringLibrary['AncientLabels'];
    final merchantLabelsDict = stringLibrary['MerchantLabels'];
    final missionInterestDict = stringLibrary['MissionInterest'];
    final diffDict = stringLibrary['Difficulty'];
    final towerDict =
        stringLibrary['Content_Season1/Decor/Text/TowerUILabels.csv'];
    final s2MerchantLabelsDict =
        stringLibrary['Content_Season2/Decor/Text/Season2MerchantLabels.csv'];
    final itemEffectDict = stringLibrary['ItemPowerEffect'];
    if (clickysDict != null &&
        realmsDict != null &&
        dlcDict != null &&
        ancientLabelsDict != null &&
        merchantLabelsDict != null &&
        missionInterestDict != null &&
        diffDict != null &&
        towerDict != null &&
        s2MerchantLabelsDict != null &&
        itemEffectDict != null) {
      _clickys = {
        ...clickysDict,
        ...realmsDict,
        ...dlcDict,
        ...ancientLabelsDict,
        ...merchantLabelsDict,
        ...missionInterestDict,
        ...diffDict,
        ...towerDict,
        ...s2MerchantLabelsDict,
        ...itemEffectDict,
      }.map((k, v) => MapEntry(k.trim(), v));
    }
    isStringsLoaded = true;
  }

  static void unloadExternalStrings() {
    _itemType.clear();
    _enchantment.clear();
    _armorProperties.clear();
    _mission.clear();
    _clickys.clear();
    isStringsLoaded = false;
  }

  static String formatFileInUnexpectedFormatErrorMessage(String filename) =>
      fileInUnexpectedFormatErrorMessage.replaceAll('{0}', filename);
  static String formatFileDecryptErrorMessage(String filename) =>
      fileDecryptErrorMessage.replaceAll('{0}', filename);
  static String formatItemsCountLabel(int items, int max) =>
      itemsCountLabel
          .replaceAll('{0}', '$items')
          .replaceAll('{1}', '$max');
  static String formatVersion(String versionLabel, String versionString) =>
      versionFormat
          .replaceAll('{0}', versionLabel)
          .replaceAll('{1}', versionString);
  static String formatMcdVersion(String versionString) =>
      mcdVersionFormat.replaceAll('{0}', versionString);
  static String formatNextLevelLabel(
          int nextFloor, int totalFloors, String floorType) =>
      nextLevelLabel
          .replaceAll('{0}', '$nextFloor')
          .replaceAll('{1}', '$totalFloors')
          .replaceAll('{2}', floorType);

  static String itemName(String type) => _getItemString(type) ?? type;

  static String itemDesc(String type) {
    final key = 'Flavour_$type';
    return _getItemString(key) ?? type;
  }

  static String? _getItemString(String key) {
    if (!isStringsLoaded) return key;
    final mapped = StringMismatches.map[key] ?? key;
    final value = _itemType[mapped];
    if (value != null) return value;
    EventLogger.logError('Could not find string for item $key');
    return null;
  }

  static String enchantmentName(String enchantment) {
    var key = enchantment;
    if (!isStringsLoaded) return key;
    key = StringMismatches.map[key] ?? key;
    final value = _enchantment[key];
    if (value != null) {
      if (enchantment.toLowerCase().contains('ranged')) {
        final classification =
            getString('ItemTag_Ranged') ?? rangedItemsFilter;
        return '$value ($classification)';
      } else if (enchantment.toLowerCase().contains('melee')) {
        final classification =
            getString('ItemTag_Melee') ?? meleeItemsFilter;
        return '$value ($classification)';
      }
      return value;
    }
    EventLogger.logError('Could not find string for enchantment $key');
    return enchantment;
  }

  static String enchantmentDescription(String enchantment) {
    final key = '${enchantment}_desc';
    return _getEnchantmentString(key) ?? enchantment;
  }

  static String enchantmentEffect(String enchantment) {
    final key = '${enchantment}_effect';
    return _getEnchantmentString(key) ?? enchantment;
  }

  static String? _getEnchantmentString(String key) {
    if (!isStringsLoaded) return key;
    final mapped = StringMismatches.map[key] ?? key;
    final value = _enchantment[mapped];
    if (value != null) return value;
    EventLogger.logError('Could not find string for enchantment $key');
    return null;
  }

  static String armorProperty(String armorPropertyId) =>
      _getArmorPropertyString(armorPropertyId) ?? armorPropertyId;

  static String armorPropertyDescription(String armorPropertyId) {
    final key = '${armorPropertyId}_description';
    return _getArmorPropertyString(key) ?? armorPropertyId;
  }

  static String? _getArmorPropertyString(String key) {
    if (!isStringsLoaded) return key;
    final mapped = StringMismatches.map[key] ?? key;
    final value = _armorProperties[mapped];
    if (value != null) return value;
    EventLogger.logError('Could not find string for armor $key');
    return null;
  }

  static String? getMissionName(String missionId) {
    final key = '${missionId}_name';
    return _getMissionString(key) ?? missionId;
  }

  static String? _getMissionString(String key) {
    if (!isStringsLoaded) return key;
    final mapped = StringMismatches.map[key] ?? key;
    final value = _mission[mapped];
    if (value != null) return value;
    EventLogger.logError('Could not find string for mission $key');
    return null;
  }

  static String? getString(String key) {
    if (!isStringsLoaded) return null;
    final mapped = StringMismatches.map[key] ?? key;
    final value = _clickys[mapped];
    if (value != null) return value;
    EventLogger.logError('Could not find string for key -$key-');
    return null;
  }

  // ---- Bundled English resources (from Resources.resx) ----

  static const String aboutWindowTitle =
      'About Minecraft Dungeons Save File Editor';
  static const String allFiles = 'All files';
  static const String allItemsFilter = 'All';
  static const String applicationTitle = 'Minecraft Dungeons Save File Editor';
  static const String armorItemsFilter = 'Armor';
  static const String arrows = 'Arrows';
  static const String artifactItemsFilter = 'Artifact';
  static const String attemptsLeft = 'Attempts Left';
  static const String betaUpdateMenuItemHeader = 'Beta _Update';
  static const String betaVersionLabel = 'Beta';
  static const String bossesDefeated = 'Bosses Defeated';
  static const String cancel = 'Cancel';
  static const String characterFileFormatNotRecognizedErrorMessage =
      'Character File format not recognized. Please select a valid Character File.';
  static const String chest = 'Chest';
  static const String common = 'Common';
  static const String completedApocalypsePlus = 'Completed Apocalypse Plus:';
  static const String completedDifficulty = 'Completed Difficulty:';
  static const String completedThreatLevel = 'Completed Threat Level:';
  static const String creepingWinter = 'Creeping Winter';
  static const String currentFloor = 'Current Floor';
  static const String decryptedCharacterSaveFiles =
      'Decrypted Character Save files';
  static const String delete = 'Delete';
  static const String difficultyAdventure = 'Adventure';
  static const String difficultyApocalypse = 'Apocalypse';
  static const String difficultyDefault = 'Default';
  static const String duplicate = 'Duplicate';
  static const String emeralds = 'Emeralds';
  static const String enchantedItemsFilter = 'Enchanted';
  static const String encryptedCharacterSaveFiles =
      'Encrypted Character Save files';
  static const String error = 'Error';
  static const String exit = 'Exit';
  static const String failedToEncryptErrorMessage =
      'Failed to encrypt the json data.';
  static const String failedToLoadGameContentErrorTitle =
      'Failed to load game content.';
  static const String failedToParseFileErrorMessage =
      'File was not in an expected format.';
  static const String fileDecryptErrorMessage =
      'Content of file "{0}" could not be converted to a supported format.';
  static const String fileDoesntExistErrorMessage = "File doesn't exist.";
  static const String fileDropErrorMessage = 'Expected a file.';
  static const String fileInUnexpectedFormatErrorMessage =
      'The file "{0}" was in an unexpected format.';
  static const String finalFloor = 'Final Floor';
  static const String floorChallenges = 'Challenges';
  static const String floorRewards = 'Rewards';
  static const String floorTile = 'Tile';
  static const String floorType = 'Type';
  static const String gameFilesWindowGroupboxHeader = 'Game Files';
  static const String gameFilesWindowMessage =
      'Could not find game content files in the default install location. '
      'Please provide the path to the game files or launch with no game '
      'content and limited features.';
  static const String gameFilesWindowNoContentButton = 'No game content';
  static const String gameFilesWindowTextboxLabel = 'Path';
  static const String gameFilesWindowTitle = 'Launch using game content';
  static const String gifted = 'Gifted';
  static const String gilded = 'Gilded';
  static const String giveUpTowerRun = 'Give up Tower Run';
  static const String howlingPeaks = 'Howling Peaks';
  static const String inventory = 'Inventory';
  static const String islandRealms = 'Island Realms';
  static const String itemsCountLabel = 'Items: {0}/{1} Max';
  static const String itemWasDeletedErrorMessage = 'Item was deleted.';
  static const String jungleAwakens = 'Jungle Awakens';
  static const String launchWithLimitedFeaturesQuestion =
      'Launch with no game content and limited features?';
  static const String level = 'Level';
  static const String mainland = 'Mainland';
  static const String mcdVersionFormat = 'MCD {0}';
  static const String meleeItemsFilter = 'Melee';
  static const String menuItemAbout = 'About';
  static const String menuItemFile = 'File';
  static const String menuItemGetNewVersion = 'Get New Version';
  static const String missions = 'Missions';
  static const String mobKills = 'Mob Kills';
  static const String moveToInventory = 'Move to Inventory';
  static const String moveToStorage = 'Move to Storage';
  static const String new_ = 'New';
  static const String nextLevelLabel = 'Next Floor {0} / {1} : {2}';
  static const String none = 'None';
  static const String notCompleted = 'Not Completed';
  static const String noGameFilesFoundErrorMessage =
      'Could not find game content files at the given path.';
  static const String noGameVersionDetected = 'Unknown game version';
  static const String ok = 'OK';
  static const String oldVersionLabel = 'Old';
  static const String pleaseHaveLatestVersion =
      'Please make sure you have the latest version.';
  static const String power = 'Power';
  static const String powerful = 'Powerful';
  static const String progressStatCounters = 'Progress Stat Counters';
  static const String rangedItemsFilter = 'Ranged';
  static const String rare = 'Rare';
  static const String selectArmor = 'Select Armor';
  static const String selectArmorProperty = 'Select Armor Property';
  static const String selectArtifact = 'Select Artifact';
  static const String selectEnchantment = 'Select Enchantment';
  static const String selectItem = 'Select Item';
  static const String selectMeleeWeapon = 'Select Melee Weapon';
  static const String selectRangedWeapon = 'Select Ranged Weapon';
  static const String stableUpdateMenuItemHeader = '_Update';
  static const String stableVersionLabel = 'Stable';
  static const String startTowerRun = 'Start Tower Run';
  static const String statsCounters = 'Stats/Counters';
  static const String theTower = 'The Tower';
  static const String tier = 'Tier';
  static const String unique = 'Unique';
  static const String unreleasedVersionLabel = 'Unreleased';
  static const String upgraded = 'Upgraded';
  static const String versionFormat = 'Version: {0} {1}';
}
