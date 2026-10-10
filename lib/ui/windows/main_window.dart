import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_model.dart';
import '../../data/constants.dart';
import '../../services/config.dart';
import '../../theme.dart';
import '../../services/event_logger.dart';
import '../../services/string_library.dart';
import '../../viewmodels/main_view_model.dart';
import '../../viewmodels/profile_view_model.dart';
import '../property_widgets.dart';
import '../tabs/chest_tab.dart';
import '../tabs/inventory_tab.dart';
import '../tabs/stats_tab.dart';
import '../widgets/busy_indicator.dart';
import '../widgets/custom_title_bar.dart';
import 'about_window.dart';

/// Ported from `UI/Windows/MainWindow.xaml(.cs)` — menu bar, tabs, keyboard
/// shortcuts, file drop, busy indicator, update check.
class MainWindow extends StatefulWidget {
  const MainWindow({super.key, required this.model, this.onRelaunch, this.onReload});

  final MainViewModel model;

  /// Called when the user picks "Relaunch to change" (game paks).
  final VoidCallback? onRelaunch;

  /// Called after a language change to rebuild the whole UI (upstream reloads
  /// the main window).
  final void Function(String? filePath)? onReload;

  @override
  State<MainWindow> createState() => MainWindowState();
}

class MainWindowState extends State<MainWindow> {
  bool _busy = false;

  MainViewModel get _model => widget.model;
  ProfileViewModel get _profileModel => _model.profileModel;

  final GlobalKey<InventoryTabState> _inventoryTabKey = GlobalKey();
  final GlobalKey<ChestTabState> _chestTabKey = GlobalKey();
  final GlobalKey<_TabsState> _tabsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _model.showError = _showError;
    _checkForNewVersion();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateTitle());
  }

  // ---- menus ----

  Future<void> _openFile() async {
    EventLogger.logEvent('openCommandBinding_Executed');
    final typeGroups = [
      XTypeGroup(
          label: ProfileViewModel.R_encryptedCharacterSaveFiles,
          extensions: const ['dat']),
      XTypeGroup(
          label: ProfileViewModel.R_decryptedCharacterSaveFiles,
          extensions: const ['json']),
      const XTypeGroup(
          label: ProfileViewModel.R_allFiles, extensions: ['*']),
    ];
    final file = await openFile(
        acceptedTypeGroups: typeGroups,
        initialDirectory: _initialDialogDirectory());
    if (file != null) {
      await handleFileOpenAsync(file.path);
    }
  }

  String? _initialDialogDirectory() {
    final filePath = _profileModel.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return File(filePath).parent.path;
    }
    return Constants.fileDialogInitialDirectory;
  }

  Future<void> _saveFileAs() async {
    EventLogger.logEvent('saveAsCommandBinding_Executed');
    final profile = _profileModel.profile.value;
    if (profile == null) return;
    final path = await getSaveLocation(
        suggestedName: _profileModel.filePath == null
            ? 'character.dat'
            : File(_profileModel.filePath!).uri.pathSegments.last,
        initialDirectory: _initialDialogDirectory());
    if (path != null) {
      await handleFileSaveAsync(path.path);
    }
  }

  Future<void> _saveFile() async {
    EventLogger.logEvent('saveCommandBinding_Executed');
    await handleFileSaveAsync(_profileModel.filePath);
  }

  Future<void> handleFileOpenAsync(String? fileName) async {
    if (fileName == null || fileName.isEmpty) return;
    if (!File(fileName).existsSync()) {
      _showError(R.fileDoesntExistErrorMessage);
      return;
    }
    setState(() => _busy = true);
    EventLogger.logEvent('handleFileOpenAsync',
        {'extension': fileName.split('.').last});
    await _model.handleFileOpenAsync(fileName);
    setState(() => _busy = false);
    _updateTitle();
  }

  Future<void> handleFileSaveAsync(String? fileName) async {
    final profile = _profileModel.profile.value;
    if (profile == null || fileName == null || fileName.isEmpty) return;
    setState(() => _busy = true);
    EventLogger.logEvent('handleFileSaveAsync',
        {'extension': fileName.split('.').last});
    await _model.handleFileSaveAsync(fileName, profile);
    setState(() => _busy = false);
    _updateTitle();
  }

  void _updateTitle() {
    final filePath = _profileModel.filePath;
    final title = filePath != null
        ? '${R.applicationTitle} - ${filePath.split(RegExp(r'[/\\]')).last}'
        : R.applicationTitle;
    WindowTitle.title = title;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    windowManager.setTitle(title).catchError((_) {});
  }

  void _showError(String message) {
    EventLogger.logEvent('showError', {'message': message});
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(R.error),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(R.ok)),
        ],
      ),
    );
    setState(() => _busy = false);
  }

  Future<void> _checkForNewVersion() async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    try {
      await Config.instance.downloadAsync();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _onLanguageSelected(String langSpecifier) async {
    EventLogger.logEvent('languageSelectedMenuItem_Click',
        {'langSpecifier': langSpecifier});
    AppModel.loadLanguageStrings(langSpecifier);
    widget.onReload?.call(_profileModel.filePath);
    setState(() {});
  }

  static Future<void> _close() async {
    try {
      await windowManager.destroy();
    } catch (_) {
      exit(0);
    }
  }

  void _onDropFile(DropDoneDetails details) {
    EventLogger.logEvent('window_File_Drop');
    if (details.files.isNotEmpty) {
      handleFileOpenAsync(details.files.first.path);
    } else {
      _showError(R.fileDropErrorMessage);
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final hasProfile = _profileModel.profile.value != null;
    final hasFilePath = _profileModel.filePath != null;

    return ShortcutActivatorScope(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            const _MenuIntent(_MenuAction.open),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const _MenuIntent(_MenuAction.save),
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
            const _MenuIntent(_MenuAction.exit),
        const SingleActivator(LogicalKeyboardKey.delete):
            const _MenuIntent(_MenuAction.delete),
      },
      child: Actions(
        actions: {
          _MenuIntent: CallbackAction<_MenuIntent>(onInvoke: (intent) {
            switch (intent.action) {
              case _MenuAction.open:
                _openFile();
              case _MenuAction.save:
                _saveFile();
              case _MenuAction.exit:
                EventLogger.logEvent('exitCommandBinding_Executed');
                EventLogger.dispose();
                unawaited_(_close());
              case _MenuAction.delete:
                // Only when focus isn't in a text field, and only in the
                // currently visible tab (upstream OnKeyUp else-if chain).
                final focus = FocusManager.instance.primaryFocus;
                final isTextField = focus?.context?.widget is EditableText ||
                    focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
                if (!isTextField) {
                  switch (_tabsKey.currentState?.tabIndex) {
                    case 0:
                      _inventoryTabKey.currentState
                          ?.deleteCurrentSelectedItem();
                    case 2:
                      _chestTabKey.currentState?.deleteCurrentSelectedItem();
                  }
                }
            }
            return null;
          }),
        },
        child: FocusScope(
          autofocus: true,
          child: DropTarget(
            onDragDone: _onDropFile,
            child: Stack(
              children: [
                Scaffold(
                  body: Column(
                    children: [
                      _menuBar(context, hasProfile, hasFilePath),
                      Expanded(
                        child: PropertyBuilder(
                          properties: [_profileModel.profile],
                          builder: (context) => _Tabs(
                            key: _tabsKey,
                            model: _model,
                            inventoryKey: _inventoryTabKey,
                            chestKey: _chestTabKey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: BusyIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuBar(BuildContext context, bool hasProfile, bool hasFilePath) {
    final updateAvailable = Config.instance.isNewBetaVersionAvailable() ||
        Config.instance.isNewStableVersionAvailable();

    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            // File menu.
            _menuButton(R.getString('File') ?? R.menuItemFile, [
              _menuEntry('Open...', () => _openFile(), hint: 'Ctrl+O'),
              _menuEntry('Save', hasFilePath ? _saveFile : null,
                  hint: 'Ctrl+S'),
              _menuEntry('Save As...', hasProfile ? _saveFileAs : null),
              const PopupMenuDivider(),
              if (_model.recentFiles.isEmpty)
                const PopupMenuItem(enabled: false, child: Text('Recent Files')),
              for (final path in _model.recentFiles)
                _menuEntry(path.split(RegExp(r'[/\\]')).last,
                    () => handleFileOpenAsync(path)),
              const PopupMenuDivider(),
              _menuEntry('Exit', () {
                EventLogger.logEvent('exitCommandBinding_Executed');
                EventLogger.dispose();
                unawaited_(_close());
              }, hint: 'Ctrl+Q'),
            ]),
            // Game Paks menu.
            _menuButton('Game Paks', [
              PopupMenuItem(
                  enabled: false,
                  child: Text(_model.detectedGameVersion == null
                      ? R.noGameVersionDetected
                      : R.formatMcdVersion(_model.detectedGameVersion!))),
              PopupMenuItem(
                  enabled: false,
                  child: Text(ImageResolver.instance.path ??
                      R.gameFilesWindowNoContentButton)),
              const PopupMenuDivider(),
              _menuEntry('Relaunch to change...', () {
                EventLogger.logEvent('relaunchMenuItem_Click');
                widget.onRelaunch?.call();
              }),
            ]),
            // Language menu.
            _menuButton('Language', [
              _langMenuEntry('None', ''),
              const PopupMenuDivider(),
              for (final lang in LanguageResolver.instance.localizationOptions)
                _langMenuEntry(_langDisplayName(lang), lang),
            ]),
            // Theme menu.
            _menuButton('Theme', [
              _themeMenuEntry('Light', AppTheme.light),
              _themeMenuEntry('Dark', AppTheme.dark),
              _themeMenuEntry('OLED', AppTheme.oled),
            ]),
            // About.
            _menuButton(R.menuItemAbout, null, onPressed: () {
              EventLogger.logEvent('aboutMenuItem_Click');
              AboutWindow.show(context,
                  debug: const bool.fromEnvironment('DEBUG', defaultValue: false));
            }),
            // Update (visible only when a new version exists).
            if (updateAvailable)
              _menuButton(
                  Config.instance.isNewBetaVersionAvailable()
                      ? R.betaUpdateMenuItemHeader.replaceAll('_', '')
                      : R.stableUpdateMenuItemHeader.replaceAll('_', ''),
                  null, onPressed: () {
                EventLogger.logEvent('updateMenuItem_Click');
                launchUrl(Uri.parse(Config.instance.newVersionDownloadURL()));
              }),
          ],
        ),
      ),
    );
  }

  String _langDisplayName(String lang) {
    // Upstream shows CultureInfo native name; approximate with the locale name.
    try {
      final locale = lang.replaceAll('-', '_').split('_');
      if (locale.isNotEmpty && locale[0].isNotEmpty) {
        return locale.join('_');
      }
    } catch (_) {}
    return lang;
  }

  PopupMenuEntry<String> _themeMenuEntry(String label, AppTheme theme) {
    final selected = ThemeController.theme.value == theme;
    return PopupMenuItem(
      onTap: () {
        ThemeController.setTheme(theme);
        EventLogger.logEvent('themeSelectedMenuItem_Click',
            {'theme': theme.specifier});
        setState(() {});
      },
      child: Row(
        children: [
          if (selected) const Icon(Icons.check, size: 16),
          if (selected) const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _langMenuEntry(String label, String lang) {
    final selected = AppModel.currentLangSpecifier == lang;
    return PopupMenuItem(
      onTap: () => _onLanguageSelected(lang),
      child: Row(
        children: [
          if (selected) const Icon(Icons.check, size: 16),
          if (selected) const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _menuEntry(String label, VoidCallback? onTap,
      {String? hint}) {
    return PopupMenuItem(
      onTap: onTap,
      enabled: onTap != null,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (hint != null)
            Text(hint,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _menuButton(String label, List<PopupMenuEntry<String>>? items,
      {VoidCallback? onPressed}) {
    if (items == null) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
    }
    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      itemBuilder: (_) => items,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

/// Tab row + bodies — recreated when the profile loads so tabs rebuild.
class _Tabs extends StatefulWidget {
  const _Tabs(
      {super.key,
      required this.model,
      required this.inventoryKey,
      required this.chestKey});

  final MainViewModel model;
  final GlobalKey<InventoryTabState> inventoryKey;
  final GlobalKey<ChestTabState> chestKey;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int _tabIndex = 0;

  int get tabIndex => _tabIndex;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              _tabButton(0,
                  R.getString('Quickaction_inventory') ?? R.inventory),
              _tabButton(1, R.statsCounters),
              _tabButton(2, R.getString('StorageChest') ?? R.chest),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              InventoryTab(
                  key: widget.inventoryKey,
                  model: model.profileModel),
              StatsTab(model: model.profileModel),
              ChestTab(
                  key: widget.chestKey, model: model.profileModel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = _tabIndex == index;
    return TextButton(
      onPressed: () {
        setState(() => _tabIndex = index);
        // Upstream refreshes enchantment points on tab select.
        widget.model.profileModel.mainEquipmentModel
            .updateEnchantmentPoints();
        widget.model.profileModel.storageChestEquipmentModel
            .updateEnchantmentPoints();
      },
      style: TextButton.styleFrom(
        backgroundColor:
            selected ? Colors.black.withOpacity(0.1) : Colors.transparent,
      ),
      child: Text(label),
    );
  }
}

void unawaited_(Future<void> f) {}

enum _MenuAction { open, save, exit, delete }

class _MenuIntent extends Intent {
  const _MenuIntent(this.action);
  final _MenuAction action;
}

/// Tiny helper so we can attach shortcuts to the window body.
class ShortcutActivatorScope extends StatelessWidget {
  const ShortcutActivatorScope(
      {super.key, required this.shortcuts, required this.child});

  final Map<ShortcutActivator, Intent> shortcuts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(shortcuts: shortcuts, child: child);
  }
}
