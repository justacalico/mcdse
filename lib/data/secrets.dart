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
    AesKey(
      '0x72FA28089D1E511139E4EA804A6577B37070940DC43D72D62D2C889A728D9620',
      '1.17.0.0',
    ),
  ];
}
