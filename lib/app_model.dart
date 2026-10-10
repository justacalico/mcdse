import 'dart:io';

import 'package:flutter/foundation.dart';

import 'data/constants.dart';
import 'data/secrets.dart';
import 'pak/binary_reader.dart';
import 'pak/objects.dart';
import 'pak/pak_index.dart';
import 'pak/pak_filter.dart';
import 'services/content_resolver.dart';
import 'services/local_content_resolver.dart';
import 'services/pak_content_resolver.dart';
import 'services/settings_store.dart';
import 'services/string_library.dart';
import 'viewmodels/main_view_model.dart';

/// Global image resolver — the equivalent of upstream `ImageResolver.instance`.
abstract final class ImageResolver {
  static IImageResolver instance = LocalContentResolver();
}

/// Global language resolver — upstream `LanguageResolver.instance`.
abstract final class LanguageResolver {
  static ILanguageResolver instance = LocalContentResolver();
}

/// Ported from `AppModel.cs`.
class AppModel {
  AppModel();

  final MainViewModel mainModel = MainViewModel();

  static bool gameContentLoaded = false;
  static String currentLangSpecifier = '';
  static PakContentResolver? pakContentResolver;

  String? usableGameContentIfExists() {
    String? result;
    for (final path in contentPathsToCheck()) {
      if (path != null && path.isNotEmpty && Directory(path).existsSync()) {
        debugPrint('$path exists');
        result ??= path;
      } else {
        debugPrint('$path does not exist');
      }
    }
    return result;
  }

  Iterable<String?> contentPathsToCheck() sync* {
    yield SettingsStore.getSetting(Constants.pakFileLocationKey, '');
    // Steam (Windows default).
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ??
        Platform.environment['ProgramFiles'];
    if (programFilesX86 != null) {
      yield '$programFilesX86/Steam/steamapps/common/MinecraftDungeons/Dungeons/Content/Paks';
    }
    // Launcher (Windows Store / Mojang launcher).
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      yield '$localAppData/Mojang/products/dungeons/dungeons/Dungeons/Content/Paks';
    }
    // Xbox app for Windows.
    yield 'C:/XboxGames/Minecraft Dungeons/Content/Dungeons/Content/Paks';
    // Cross-platform: look next to the executable and in the home folder.
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      yield '$exeDir/paks';
      yield '$exeDir/Paks';
    } catch (_) {}
    final home = Platform.environment['HOME'];
    if (home != null) {
      yield '$home/MCDSE/paks';
    }
  }

  /// Ported from `loadGameContentAsync`.
  Future<void> loadGameContent(String paksFolderPath) async {
    final pakIndex = await loadPakIndex(paksFolderPath);
    if (pakIndex == null) {
      throw StateError('PakIndex is null. Cannot Continue.');
    }

    pakContentResolver = PakContentResolver(pakIndex, paksFolderPath);
    pakContentResolver!.loadPakFiles(preloadBitmaps: false);
    ImageResolver.instance = pakContentResolver!;
    LanguageResolver.instance = pakContentResolver!;
    gameContentLoaded = true;

    SettingsStore.saveSetting(Constants.pakFileLocationKey, paksFolderPath);

    final lang = SettingsStore.getSetting(
        Constants.langSpecifierKey, Constants.defaultLangSpecifier);
    loadLanguageStrings(lang);
  }

  static void loadLanguageStrings(String lang) {
    if (lang == currentLangSpecifier) return;

    R.unloadExternalStrings();

    debugPrint("Extracting '$lang' language strings...");
    final stringLibrary = LanguageResolver.instance.loadLanguageStrings(lang);
    if (stringLibrary != null) {
      debugPrint("Loading '$lang' language strings...");
      R.loadExternalStrings(stringLibrary);
    }

    currentLangSpecifier = lang;
    SettingsStore.saveSetting(Constants.langSpecifierKey, lang);
  }

  Future<PakIndex?> loadPakIndex(String paksFolderPath) async {
    try {
      final filter =
          PakFilter([Constants.paksFilterString], caseSensitive: false);
      // Index loading only reads file headers + the filtered index — fast
      // enough to run on the UI isolate.
      final pakIndex = PakIndex(
          path: paksFolderPath,
          cacheFiles: true,
          caseSensitive: true,
          filter: filter);
      if (pakIndex.pakFileCount == 0) {
        throw FileSystemException(
            'No files were found', paksFolderPath);
      }
      if (!unlockPakIndex(pakIndex)) {
        throw StateError('Could not decrypt pak files at $paksFolderPath');
      }
      final versionStr =
          R.formatMcdVersion(mainModel.detectedGameVersion ?? R.error);
      debugPrint('Detected Pak Files for $versionStr');
      return pakIndex;
    } catch (e) {
      debugPrint('Could not load Minecraft Dungeons Paks: $e');
      rethrow;
    }
  }

  bool unlockPakIndex(PakIndex pakIndex) {
    for (final key in Secrets.pakAesKeys) {
      var keyStr = key.key;
      final keyBytes = hexToBytes(
          keyStr.startsWith('0x') ? keyStr.substring(2) : keyStr);
      if (keyBytes.length != 32) {
        throw StateError(
            'AES Key (${keyStr.substring(0, 3)}...) is ${keyBytes.length} bytes instead of the expected 32');
      }
      final count = pakIndex.useKey(keyBytes, FGuid.zero);
      if (count > 0) {
        mainModel.detectedGameVersion = key.versions;
        return true;
      }
    }
    mainModel.detectedGameVersion = null;
    return false;
  }

  void unloadGameContent() {
    SettingsStore.deleteSetting(Constants.pakFileLocationKey);

    if (gameContentLoaded) {
      gameContentLoaded = false;
      final local = LocalContentResolver();
      ImageResolver.instance = local;
      LanguageResolver.instance = local;
      pakContentResolver = null;
      mainModel.detectedGameVersion = null;
    }

    if (currentLangSpecifier.isNotEmpty) {
      R.unloadExternalStrings();
    }
  }
}

