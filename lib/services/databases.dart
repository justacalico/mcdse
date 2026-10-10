/// Ports of `Services/Databases/*`.
library;

abstract final class EnchantmentDatabase {
  static final Set<String> allEnchantments = <String>{};
}

abstract final class ItemDatabase {
  static final Set<String> all = <String>{};
  static final Set<String> artifacts = <String>{};
  static final Set<String> armor = <String>{};
  static final Set<String> meleeWeapons = <String>{};
  static final Set<String> rangedWeapons = <String>{};
  static final Set<String> armorProperties = <String>{};
}
