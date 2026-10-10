import 'dart:io';

import 'package:flutter/material.dart';

/// Dialog listing detected save files with a browse fallback.
/// Pops with the chosen path, '' for browse, or null when dismissed.
class SavePickerDialog extends StatelessWidget {
  const SavePickerDialog({super.key, required this.saves});

  final List<File> saves;

  static String _fmtDate(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Open a save file',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final f in saves)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(f.path.split(RegExp(r'[/\\]')).last),
                      subtitle: Text(
                        f.parent.path,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(_fmtDate(f.lastModifiedSync()),
                          style: const TextStyle(fontSize: 11)),
                      onTap: () => Navigator.of(context).pop(f.path),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Browse for a file…'),
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
