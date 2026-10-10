import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../data/constants.dart';
import '../../services/event_logger.dart';
import '../../services/string_library.dart';

/// Result of the Game Files dialog — mirrors `GameFilesWindowResult`.
enum GameFilesWindowResult { exit, useSelectedPath, noContent }

class GameFilesResult {
  const GameFilesResult(this.result, [this.selectedPath]);
  final GameFilesWindowResult result;
  final String? selectedPath;
}

/// Ported from `UI/Windows/GameFilesWindow.xaml(.cs)` — shown at startup when
/// no pak files were found, or after choosing "Relaunch to change".
class GameFilesWindow extends StatefulWidget {
  const GameFilesWindow._({this.initialPath, this.allowNoContent = true});

  final String? initialPath;
  final bool allowNoContent;

  static Future<GameFilesResult> show(BuildContext context,
      {String? initialPath, bool allowNoContent = true}) {
    return showDialog<GameFilesResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 560,
          child: GameFilesWindow._(
              initialPath: initialPath, allowNoContent: allowNoContent),
        ),
      ),
    ).then((r) => r ?? const GameFilesResult(GameFilesWindowResult.exit));
  }

  @override
  State<GameFilesWindow> createState() => _GameFilesWindowState();
}

class _GameFilesWindowState extends State<GameFilesWindow> {
  late final TextEditingController _pathController;
  String? _error;

  static const _highPriorityFolderNames = {
    'Mojang', 'Dungeons', 'Content', 'Paks', 'dungeons', 'products'
  };

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(text: widget.initialPath ?? '');
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    EventLogger.logEvent('pathBrowseButton_Click');
    final dir = await getDirectoryPath(confirmButtonText: R.ok);
    if (dir != null) {
      _pathController.text = dir;
      setState(() => _error = null);
    }
  }

  /// Ported from upstream `isValidSelectedPath` — returns the normalized
  /// paks directory (possibly nested below the chosen path), or null.
  String? _isValidSelectedPath() {
    final testPath = _pathController.text.trim();
    if (testPath.isEmpty) return null;

    final dir = Directory(testPath);
    if (!dir.existsSync()) return null;

    if (File(
            '${dir.path}${Platform.pathSeparator}${Constants.firstPakFilename}')
        .existsSync()) {
      return dir.path;
    }

    return _foundInDirectory(dir.path);
  }

  String? _foundInDirectory(String testPath) {
    for (final entry in Directory(testPath).listSync()) {
      if (entry is! Directory) continue;
      if (File('${entry.path}${Platform.pathSeparator}${Constants.firstPakFilename}')
          .existsSync()) {
        return entry.path;
      }
      final name =
          entry.uri.pathSegments.where((seg) => seg.isNotEmpty).last;
      if (_highPriorityFolderNames.contains(name)) {
        final found = _foundInDirectory(entry.path);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _onOk() {
    final validPath = _isValidSelectedPath();
    EventLogger.logEvent(
        'okButton_Click', {'isValidPath': validPath != null});
    if (validPath != null) {
      Navigator.of(context).pop(GameFilesResult(
          GameFilesWindowResult.useSelectedPath, validPath));
    } else {
      setState(() => _error = R.noGameFilesFoundErrorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title.
          Text(R.gameFilesWindowTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(R.gameFilesWindowMessage,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 20),
          // Game files group.
          Text(R.gameFilesWindowGroupboxHeader,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                child: Text(R.gameFilesWindowTextboxLabel),
              ),
              Expanded(
                child: TextField(
                  controller: _pathController,
                  autofocus: true,
                  onSubmitted: (_) => _onOk(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '/path/to/Dungeons/Content/Paks',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    errorText: _error,
                    errorMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _browse,
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: R.gameFilesWindowTextboxLabel,
                style: IconButton.styleFrom(
                  fixedSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                          color: theme.dividerColor)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Button row.
          Row(
            children: [
              TextButton(
                onPressed: () {
                  EventLogger.logEvent('exitButton_Click');
                  Navigator.of(context).pop(
                      const GameFilesResult(GameFilesWindowResult.exit));
                },
                child: Text(R.exit),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  EventLogger.logEvent('noButton_Click');
                  Navigator.of(context).pop(const GameFilesResult(
                      GameFilesWindowResult.noContent));
                },
                child: Text(widget.allowNoContent
                    ? R.gameFilesWindowNoContentButton
                    : R.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _onOk, child: Text(R.ok)),
            ],
          ),
        ],
      ),
    );
  }
}
