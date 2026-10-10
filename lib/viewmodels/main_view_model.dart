import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../data/models/profile_save_file.dart';
import '../data/profile_parser.dart';
import '../logic/extensions.dart';
import '../logic/file_process_helper.dart';
import '../services/event_logger.dart';
import '../services/save_file_handler.dart';
import '../services/settings_store.dart';
import '../services/string_library.dart';
import 'profile_view_model.dart';

/// Ported from `ViewModels/MainViewModel.cs`.
class MainViewModel {
  MainViewModel() {
    _loadRecentFilesList();
  }

  final ProfileViewModel profileModel = ProfileViewModel();

  void Function(String message)? showError;

  String? detectedGameVersion;

  final List<String> _recentFiles = <String>[];
  List<String> get recentFiles => List.unmodifiable(_recentFiles);

  // ---- Recent files list (registry -> settings file) ----

  void _loadRecentFilesList() {
    for (var i = 0; i < Constants.maxRecentFiles; i++) {
      final fileName = SettingsStore.getSetting('FilePath$i', '');
      if (fileName.isNotEmpty) {
        _recentFiles.add(fileName);
      }
    }
  }

  void _saveRecentFilesList() {
    for (var i = 0; i < Constants.maxRecentFiles; i++) {
      SettingsStore.deleteSetting('FilePath$i');
    }
    var index = 0;
    for (final file in _recentFiles) {
      SettingsStore.saveSetting('FilePath$index', file);
      index++;
    }
  }

  void _removeFileInfo(String fileName) {
    _recentFiles.removeWhere((path) => path == fileName);
  }

  void addRecentFile(String fileName) {
    _removeFileInfo(fileName);
    _recentFiles.insert(0, fileName);
    if (_recentFiles.length > Constants.maxRecentFiles) {
      _recentFiles.removeAt(Constants.maxRecentFiles);
    }
    _saveRecentFilesList();
  }

  void removeRecentFile(String fileName) {
    _removeFileInfo(fileName);
    _saveRecentFilesList();
  }

  // ---- Open file ----

  Future<void> handleFileOpenAsync(String filePath) async {
    final profile = await _handleGenericFileOpenAsync(filePath);
    if (profile != null) {
      addRecentFile(filePath);
      setProfile(filePath, profile);
    }
  }

  void setProfile(String filePath, ProfileSaveFile profile) {
    profileModel.filePath = filePath;
    profileModel.profile.setValue = profile;
  }

  Future<ProfileSaveFile?> _handleGenericFileOpenAsync(String filePath) {
    debugPrint('Reading file: $filePath');
    if (filePath.endsWith(Constants.decryptedFileExtension)) {
      return _handleJsonFileOpen(filePath);
    }
    return _handleDatFileOpen(filePath);
  }

  Future<ProfileSaveFile?> _handleJsonFileOpen(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return _tryParseFileBytes(bytes);
  }

  Future<ProfileSaveFile?> _handleDatFileOpen(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final encrypted = SaveFileHandler.isFileEncrypted(bytes);
    if (!encrypted) {
      EventLogger.logError(
          'The file "${filePath.split(Platform.pathSeparator).last}" was in an unexpected format.');
      showError?.call(R.formatFileInUnexpectedFormatErrorMessage(
          filePath.split(Platform.pathSeparator).last));
      return null;
    }
    final processed = await FileProcessHelper.decrypt(bytes);
    if (processed == null) {
      EventLogger.logError(
          'Content of file "${filePath.split(Platform.pathSeparator).last}" could not be converted to a supported format.');
      showError?.call(R.formatFileDecryptErrorMessage(
          filePath.split(Platform.pathSeparator).last));
      return null;
    }
    return _tryParseFileBytes(processed);
  }

  Future<ProfileSaveFile?> _tryParseFileBytes(List<int> bytes) async {
    try {
      final profile =
          ProfileParser.read(Uint8List.fromList(bytes.cast<int>()));
      if (profile == null || !profile.isValid()) {
        showError?.call(R.characterFileFormatNotRecognizedErrorMessage);
        return null;
      }
      return profile;
    } catch (e) {
      EventLogger.logError(e.toString());
      showError?.call(R.failedToParseFileErrorMessage);
    }
    return null;
  }

  // ---- Save file ----

  Future<void> handleFileSaveAsync(
      String? filePath, ProfileSaveFile profile) async {
    if (filePath == null) return;
    profile.totalGearPower = profile.computeCharacterPower();
    debugPrint('Writing file: $filePath');
    if (filePath.endsWith(Constants.decryptedFileExtension)) {
      await _handleJsonFileSave(filePath, profile);
    } else {
      await _handleDatFileSave(filePath, profile);
    }
    addRecentFile(filePath);
    profileModel.filePath = filePath;
  }

  Future<void> _handleJsonFileSave(
      String filePath, ProfileSaveFile profile) async {
    final bytes = ProfileParser.write(profile);
    await _writeBytesToFile(bytes, filePath);
  }

  Future<void> _handleDatFileSave(
      String filePath, ProfileSaveFile profile) async {
    final input = ProfileParser.write(profile);
    final processed = await FileProcessHelper.encrypt(input);
    if (processed == null) {
      EventLogger.logError('Failed to encrypt the json data.');
      showError?.call(R.failedToEncryptErrorMessage);
      return;
    }
    await _writeBytesToFile(processed, filePath);
  }

  Future<void> _writeBytesToFile(List<int> bytes, String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
  }
}
