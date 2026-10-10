import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../services/encryption.dart';
import '../services/event_logger.dart';
import '../services/save_file_handler.dart';

/// Ported from `Logic/FileProcessHelper.cs`.
abstract final class FileProcessHelper {
  static Future<void> processFile(File file, bool overwrite) async {
    if (!file.existsSync()) {
      EventLogger.logError('File "${file.path}" could not be found and has been skipped.');
      return;
    }

    final input = await file.readAsBytes();
    final encrypted = SaveFileHandler.isFileEncrypted(input);

    final Uint8List? processed =
        encrypted ? await decrypt(input) : await encrypt(input);
    if (processed == null) {
      EventLogger.logError(
          'Content of file "${p.basename(file.path)}" could not be converted to a supported format.');
      return;
    }

    final outputFile = getOutputFilePath(file.path, encrypted, overwrite);
    await File(outputFile).writeAsBytes(processed);
  }

  static Future<Uint8List?> decrypt(Uint8List data) async {
    // The cipher operates on the bytes after the 8-byte magic header.
    final body = SaveFileHandler.startsWithMagic(data)
        ? Uint8List.sublistView(data, 8)
        : data;
    final decrypted = await EncryptionProviders.current.decryptAsync(body);
    return SaveFileHandler.removeTrailingZeroes(decrypted);
  }

  static Future<Uint8List?> encrypt(Uint8List data) async {
    final encrypted = await EncryptionProviders.current.encryptAsync(data);
    return SaveFileHandler.prependMagicToEncrypted(encrypted);
  }

  static String getOutputFilePath(String inputPath, bool isEncrypted, bool overwrite) {
    final extension = p.extension(inputPath).toUpperCase();
    final String targetExtension;
    switch (extension) {
      case '':
        // Special case for Switch which has no file extension.
        targetExtension = isEncrypted ? '.json' : '';
      default:
        targetExtension = isEncrypted ? '.json' : '.dat';
    }

    final baseName = p.basenameWithoutExtension(inputPath);
    final dirName = p.dirname(inputPath);
    var idealFileName = '$baseName$targetExtension';
    if (p.basename(inputPath).toLowerCase() == idealFileName.toLowerCase()) {
      idealFileName =
          '${p.basenameWithoutExtension(idealFileName)}_${isEncrypted ? 'Decrypted' : 'Encrypted'}$targetExtension';
    }

    var outFileName = p.join(dirName, idealFileName);
    if (overwrite || !File(outFileName).existsSync()) {
      return outFileName;
    }

    var fileNumber = 1;
    while (File(outFileName).existsSync()) {
      final stem = idealFileName.substring(0, idealFileName.length - targetExtension.length);
      outFileName = p.join(dirName, '${stem}_$fileNumber$targetExtension');
      fileNumber++;
    }

    return outFileName;
  }
}
