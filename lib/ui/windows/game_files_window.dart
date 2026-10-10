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
  const GameFilesWindow._(
      {this.initialPath, required this.allowNoContent});

  final String? initialPath;
  final bool allowNoContent;

  static Future<GameFilesResult> show(BuildContext context,
      {String? initialPath, bool allowNoContent = true}) {
    return showDialog<GameFilesResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 600,
          height: 200,
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

  @override
  void initState() {
    super.initState();
    _pathController =
        TextEditingController(text: widget.initialPath ?? '');
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    EventLogger.logEvent('pathBrowseButton_Click');
    // file_selector has no folder picker; use getDirectoryPath.
    final dir = await getDirectoryPath(
        confirmButtonText: R.ok);
    if (dir != null) {
      _pathController.text = dir;
    }
  }

  static const _highPriorityFolderNames = {
    'Mojang', 'Dungeons', 'Content', 'Paks', 'dungeons', 'products'
  };

  /// Ported from upstream `isValidSelectedPath` — returns the normalized
  /// paks directory (possibly nested below the chosen path), or null.
  String? _isValidSelectedPath() {
    final testPath = _pathController.text.trim();
    if (testPath.isEmpty) return null;

    final dir = Directory(testPath);
    if (!dir.existsSync()) return null;

    if (File('${dir.path}${Platform.pathSeparator}${Constants.firstPakFilename}')
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
      final name = entry.uri.pathSegments
          .where((seg) => seg.isNotEmpty)
          .last;
      if (_highPriorityFolderNames.contains(name)) {
        final found = _foundInDirectory(entry.path);
        if (found != null) return found;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                R.gameFilesWindowMessage,
                softWrap: true,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(5),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(R.gameFilesWindowGroupboxHeader,
                    style: const TextStyle(fontSize: 12)),
                Row(
                  children: [
                    Text(R.gameFilesWindowTextboxLabel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pathController,
                        decoration: const InputDecoration(
                            isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: TextButton(
                          onPressed: _browse, child: const Text('...')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
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
                TextButton(
                  autofocus: true,
                  onPressed: () {
                    final validPath = _isValidSelectedPath();
                    EventLogger.logEvent(
                        'okButton_Click', {'isValidPath': validPath != null});
                    if (validPath != null) {
                      Navigator.of(context).pop(GameFilesResult(
                          GameFilesWindowResult.useSelectedPath, validPath));
                      return;
                    }
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(R.error),
                        content:
                            Text(R.noGameFilesFoundErrorMessage),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(R.ok)),
                        ],
                      ),
                    );
                  },
                  child: Text(R.ok),
                ),
                TextButton(
                  onPressed: () {
                    EventLogger.logEvent('noButton_Click');
                    Navigator.of(context).pop(
                        const GameFilesResult(
                            GameFilesWindowResult.noContent));
                  },
                  child: Text(widget.allowNoContent
                      ? R.gameFilesWindowNoContentButton
                      : R.cancel),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
