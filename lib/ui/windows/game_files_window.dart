import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

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
                    EventLogger.logEvent('okButton_Click');
                    Navigator.of(context).pop(GameFilesResult(
                        GameFilesWindowResult.useSelectedPath,
                        _pathController.text));
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
                  child: Text(R.gameFilesWindowNoContentButton),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
