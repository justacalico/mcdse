import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'widgets/custom_title_bar.dart';
import 'widgets/save_picker_dialog.dart';

import '../app_model.dart';
import '../data/constants.dart';
import '../services/event_logger.dart';
import '../services/local_content_resolver.dart';
import '../services/string_library.dart';
import 'windows/game_files_window.dart';
import 'windows/main_window.dart';
import 'windows/splash_window.dart';

/// Ported from `App.xaml.cs` startup: splash window → optional file load →
/// pak detection → game-files dialog → main window.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.appModel, this.args = const []});

  final AppModel appModel;
  final List<String> args;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  bool _mainWindowVisible = false;
  int _mainWindowEpoch = 0; // bumped to force rebuild on relaunch/reload
  final GlobalKey<SplashWindowState> _splashKey = GlobalKey();

  AppModel get _model => widget.appModel;

  @override
  void initState() {
    super.initState();
    EventLogger.init();
    // Fire-and-forget startup after the first frame so the splash renders.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _log(String line) {
    _splashKey.currentState?.log(line);
    debugPrint(line);
  }

  Future<void> _start() async {
    _log('${Constants.applicationName} ${Constants.currentVersionNumber}');

    // argv file open: last arg, if it exists on disk.
    final fileName = widget.args.isEmpty ? null : widget.args.last;
    if (fileName != null &&
        fileName.isNotEmpty &&
        !fileName.startsWith('-') &&
        File(fileName).existsSync()) {
      EventLogger.logEvent('handleFileOpenAsync',
          {'extension': fileName.split('.').last});
      await _model.mainModel.handleFileOpenAsync(fileName);
    }

    final skipGameContent = widget.args.contains('SKIP_GAME_CONTENT');
    final askForGameContentLocation =
        widget.args.contains('ASK_FOR_GAME_CONTENT_LOCATION');
    if (skipGameContent) {
      _showMainWindow();
    } else {
      await _load(askForGameContentLocation: askForGameContentLocation);
    }
  }

  Future<void> _load({bool askForGameContentLocation = false}) async {
    _log('Searching for pak files...');
    var canContinue = true;
    var paksFolderPath = _model.usableGameContentIfExists();

    if (askForGameContentLocation ||
        paksFolderPath == null ||
        paksFolderPath.isEmpty) {
      final result = await _showGameFilesWindow(paksFolderPath);
      switch (result.result) {
        case GameFilesWindowResult.exit:
          canContinue = false;
        case GameFilesWindowResult.useSelectedPath:
          paksFolderPath = result.selectedPath;
        case GameFilesWindowResult.noContent:
          paksFolderPath = null;
      }
    }

    if (paksFolderPath != null && paksFolderPath.isNotEmpty) {
      _log('Pak files path: $paksFolderPath');
      try {
        await _loadGameContent(paksFolderPath);
      } catch (e) {
        _model.unloadGameContent();
        final title =
            '${Constants.applicationName} ${Constants.currentVersionNumber} - ${R.error}';
        final message =
            '${R.failedToLoadGameContentErrorTitle}\n\n$e\n\n${R.pleaseHaveLatestVersion}\n\n${R.launchWithLimitedFeaturesQuestion}';
        if (mounted) {
          final answer = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Yes')),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('No')),
              ],
            ),
          );
          canContinue = answer ?? false;
        }
      }
    } else {
      _model.unloadGameContent();
    }

    if (!canContinue) {
      exit(0);
    }
    _showMainWindow();
  }

  Future<void> _loadGameContent(String paksFolderPath) async {
    _log('Loading pak index...');
    await _model.loadGameContent(paksFolderPath);
    _log('Loading UI images...');
    // Preload the bundled fallback images (upstream `preload()` calls).
    try {
      await (ImageResolver.instance as LocalContentResolver).preload();
    } catch (_) {
      await LocalContentResolver().preload();
    }
  }

  Future<GameFilesResult> _showGameFilesWindow(String? currentPath) {
    EventLogger.logEvent('showGameFilesWindow');
    return GameFilesWindow.show(context, initialPath: currentPath);
  }

  void _showMainWindow() {
    EventLogger.logEvent('showMainWindow',
        {'gameContentLoaded': AppModel.gameContentLoaded.toString()});
    _log('Loading Done');
    setState(() => _mainWindowVisible = true);
    if (Platform.environment['FLUTTER_TEST'] != 'true') {
      windowManager.setTitle(R.applicationTitle).catchError((_) {});
    }
    // If no save was opened via argv, offer the detected save files.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybePromptSaveFile());
  }

  Future<void> _maybePromptSaveFile() async {
    if (!mounted ||
        _model.mainModel.profileModel.profile.value != null ||
        Platform.environment['FLUTTER_TEST'] == 'true') {
      return;
    }
    final saves = Constants.detectedSaveFiles();
    if (saves.isEmpty) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SavePickerDialog(saves: saves),
    );
    if (picked == null || !mounted) return;
    if (picked.isEmpty) {
      final file = await openFile(acceptedTypeGroups: const [
        XTypeGroup(label: 'Save files', extensions: ['dat', 'json'])
      ]);
      if (file == null) return;
      await _model.mainModel.handleFileOpenAsync(file.path);
      return;
    }
    await _model.mainModel.handleFileOpenAsync(picked);
  }

  void _onRelaunch() {
    setState(() => _mainWindowVisible = false);
    _load(askForGameContentLocation: true);
  }

  void _onReload(String? filePath) {
    // Upstream `onReload` re-sets the profile: re-fires profile
    // subscribers (resetting filter/selection) and updates the title.
    final profile = _model.mainModel.profileModel.profile.value;
    if (filePath != null && profile != null) {
      _model.mainModel.setProfile(filePath, profile);
    }
    // Recreate the main window so localized strings refresh.
    setState(() => _mainWindowEpoch++);
  }

  @override
  Widget build(BuildContext context) {
    final content = !_mainWindowVisible
        ? SplashWindow(key: _splashKey)
        : MainWindow(
            key: ValueKey(_mainWindowEpoch),
            model: _model.mainModel,
            onRelaunch: _onRelaunch,
            onReload: _onReload,
          );
    // Custom frame: our own title bar + resize edges instead of the OS one.
    return VirtualWindowFrame(
      child: Column(
        children: [
          ValueListenableBuilder<String>(
            valueListenable: WindowTitle.notifier,
            builder: (context, title, _) =>
                CustomTitleBar(title: title),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
