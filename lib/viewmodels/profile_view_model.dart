import '../core/property.dart';
import '../data/constants.dart';
import '../data/models/currency.dart';
import '../data/models/profile_save_file.dart';
import 'main_equipment_view_model.dart';
import 'storage_chest_equipment_view_model.dart';

/// Ported from `ViewModels/ProfileViewModel.cs`.
class ProfileViewModel {
  ProfileViewModel() {
    mainEquipmentModel = MainEquipmentViewModel(_profile);
    storageChestEquipmentModel = StorageChestEquipmentViewModel(_profile);

    emeralds = _currencyProperty(Constants.emeraldCurrencyName);
    gold = _currencyProperty(Constants.goldCurrencyName);
    eyeOfEnder = _currencyProperty(Constants.eyeOfEnderCurrencyName);

    unlockPortal = _profile.map<bool?>(
      (p) {
        final stronghold = p?.strongholdProgress;
        if (stronghold == null) return null;
        // Upstream uses LINQ `All` over the `*Unlocked` keys — an empty set
        // yields true.
        var all = true;
        stronghold.forEach((key, value) {
          if (key.endsWith('Unlocked') && !value) all = false;
        });
        return all;
      },
      (p, value) {
        if (p == null || value == null) return;
        final stronghold = p.strongholdProgress;
        if (stronghold == null) return;
        p.strongholdProgress = stronghold.map(
            (key, v) => MapEntry(key, key.endsWith('Unlocked') ? value : v));
      },
    );
  }

  static const Map<String, String> supportedFileTypesDict = {
    '*${Constants.encryptedFileExtension}': R_encryptedCharacterSaveFiles,
    '*${Constants.decryptedFileExtension}': R_decryptedCharacterSaveFiles,
    '*.*': R_allFiles,
  };

  // Resource strings duplicated here to keep this map `const`-able.
  static const String R_encryptedCharacterSaveFiles =
      'Encrypted Character Save files';
  static const String R_decryptedCharacterSaveFiles =
      'Decrypted Character Save files';
  static const String R_allFiles = 'All files';

  late final MainEquipmentViewModel mainEquipmentModel;
  late final StorageChestEquipmentViewModel storageChestEquipmentModel;

  String? filePath;

  final Property<ProfileSaveFile?> _profile = Property<ProfileSaveFile?>(null);
  IReadWriteProperty<ProfileSaveFile?> get profile => _profile;

  late final IReadWriteProperty<bool?> unlockPortal;
  late final IReadWriteProperty<int?> emeralds;
  late final IReadWriteProperty<int?> gold;
  late final IReadWriteProperty<int?> eyeOfEnder;

  IReadWriteProperty<int?> _currencyProperty(String currencyName) {
    return _profile.map<int?>(
      (p) {
        final currencies = p?.currency;
        if (currencies == null) return null;
        for (final c in currencies) {
          if (c.type == currencyName) return c.count;
        }
        return null;
      },
      (p, value) {
        if (p == null || value == null) return;
        final currencies = p.currency ?? [];
        var currency = currencies
            .where((c) => c.type == currencyName)
            .firstOrNull;
        currency ??= Currency.fromFields(type: currencyName);
        currency.count = value;
        final updated = [currency]
          ..addAll(currencies.where((c) => c.type != currencyName));
        updated.sort((a, b) => a.type.compareTo(b.type));
        p.currency = updated;
      },
    );
  }
}
