/// Pak AES keys ported from upstream `Secrets.cs`.
///
/// The upstream project ships a stub and asks builders to fill in the key.
/// The key below is the publicly-circulated Minecraft Dungeons pak key.
class AesKey {
  const AesKey(this.key, this.versions);
  final String key;
  final String versions;
}

abstract final class Secrets {
  static const List<AesKey> pakAesKeys = [
    // Current key (1.16.2.0+).
    AesKey(
      '0x7D5F892ECEBFA53CC22001DF48B871D51C0DF7C54CE41933BFB285219829B3A8',
      '1.17.0.0',
    ),
    // Launch-day key, kept for older game installs.
    AesKey(
      '0x72FA28089D1E511139E4EA804A6577B37070940DC43D72D62D2C889A728D9620',
      '1.0.0.0',
    ),
  ];
}
