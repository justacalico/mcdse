import 'dart:async';
import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';

import 'save_session.dart';

/// Shared save-file MCP tools — used by both the standalone stdio server
/// (`bin/mcp_server.dart`) and the in-app HTTP server (`McpHost`).
void registerSaveTools(McpServer server, SaveSession session) {
  CallToolResult json(Object? value) => CallToolResult.fromContent(
      [TextContent(text: const JsonEncoder.withIndent('  ').convert(value))]);

  Future<CallToolResult> run(FutureOr<Object?> Function() body) async {
    try {
      return json(await body());
    } catch (e) {
      return CallToolResult(
          content: [TextContent(text: 'Error: $e')], isError: true);
    }
  }

  server.registerTool(
    'game_catalog',
    description:
        'Complete editing reference — call this FIRST: all item type ids by '
        'category, enchantment ids with names and the powerful flag, armor '
        'property ids, equipment slots, rarities, level/power/tier limits, '
        'and save-format rules for item fields.',
    inputSchema: JsonSchema.object(properties: const {}),
    callback: (args, extra) => run(() => session.catalog()),
  );

  server.registerTool(
    'detect_save_files',
    description:
        'List Minecraft Dungeons save files found on this machine (native + Steam Proton prefix locations).',
    inputSchema: JsonSchema.object(properties: const {}),
    callback: (args, extra) => run(() => session.detectedSaveFiles()),
  );

  server.registerTool(
    'open_save',
    description:
        'Open a .dat (encrypted) or .json (decrypted) character save. Returns a summary of the profile.',
    inputSchema: JsonSchema.object(
      properties: {
        'path': JsonSchema.string(description: 'Absolute path to the save file'),
      },
      required: ['path'],
    ),
    callback: (args, extra) => run(() => session.open(args['path'] as String)),
  );

  server.registerTool(
    'save_info',
    description:
        'Summary of the open save: level, xp, power, currencies, item counts, equipped items.',
    inputSchema: JsonSchema.object(properties: const {}),
    callback: (args, extra) => run(() => session.info()),
  );

  server.registerTool(
    'dump_profile_json',
    description:
        'Full decrypted save JSON — every field of the profile verbatim.',
    inputSchema: JsonSchema.object(properties: const {}),
    callback: (args, extra) async => CallToolResult.fromContent(
        [TextContent(text: session.dumpJson())]),
  );

  server.registerTool(
    'list_items',
    description:
        'List items in a location. location: "inventory", "chest", or "all".',
    inputSchema: JsonSchema.object(
      properties: {
        'location': JsonSchema.string(
            description: 'inventory | chest | all',
            enumValues: const ['inventory', 'chest', 'all']),
      },
      required: ['location'],
    ),
    callback: (args, extra) =>
        run(() => session.listItems(args['location'] as String)),
  );

  server.registerTool(
    'get_item',
    description: 'Full JSON for one item by index and location.',
    inputSchema: JsonSchema.object(
      properties: {
        'index': JsonSchema.integer(),
        'location': JsonSchema.string(
            enumValues: const ['inventory', 'chest']),
      },
      required: ['index', 'location'],
    ),
    callback: (args, extra) => run(() => session.getItem(
        (args['index'] as num).toInt(), args['location'] as String)),
  );

  server.registerTool(
    'add_item',
    description:
        'Add a new item — validated against game data when the catalog is '
        'loaded: type must exist, gear slots only accept matching categories, '
        'enchant ids and armor properties are checked. Call game_catalog '
        'first for valid ids. '
        'equipmentSlot: MeleeGear | ArmorGear | RangedGear | HotbarSlot1-3 (omit for inventory).',
    inputSchema: JsonSchema.object(
      properties: {
        'type': JsonSchema.string(),
        'location': JsonSchema.string(
            enumValues: const ['inventory', 'chest']),
        'equipmentSlot': JsonSchema.string(),
        'power': JsonSchema.number(),
        'rarity': JsonSchema.string(
            enumValues: const ['Common', 'Rare', 'Unique']),
        'markedNew': JsonSchema.boolean(),
        'upgraded': JsonSchema.boolean(),
        'gifted': JsonSchema.boolean(),
        'enchantments': JsonSchema.array(
            items: JsonSchema.object(
                properties: const {}, additionalProperties: true)),
        'netheriteEnchant': JsonSchema.object(
            properties: const {}, additionalProperties: true),
        'armorproperties': JsonSchema.array(
            items: JsonSchema.object(
                properties: const {}, additionalProperties: true)),
      },
      required: ['type'],
    ),
    callback: (args, extra) => run(() => session.addItem(
          type: args['type'] as String,
          location: (args['location'] as String?) ?? 'inventory',
          equipmentSlot: args['equipmentSlot'] as String?,
          power: (args['power'] as num?)?.toDouble() ?? 1,
          rarity: (args['rarity'] as String?) ?? 'Common',
          markedNew: (args['markedNew'] as bool?) ?? true,
          upgraded: args['upgraded'] as bool?,
          gifted: args['gifted'] as bool?,
          enchantments: (args['enchantments'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          netheriteEnchant: args['netheriteEnchant'] != null
              ? Map<String, dynamic>.from(args['netheriteEnchant'] as Map)
              : null,
          armorProperties: (args['armorproperties'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        )),
  );

  server.registerTool(
    'update_item',
    description:
        'Patch fields on an item: type, power, rarity, markedNew, upgraded, gifted, '
        'equipmentSlot, enchantments, armorproperties.',
    inputSchema: JsonSchema.object(
      properties: {
        'index': JsonSchema.integer(),
        'location': JsonSchema.string(
            enumValues: const ['inventory', 'chest']),
        'fields': JsonSchema.object(
            properties: const {}, additionalProperties: true),
      },
      required: ['index', 'location', 'fields'],
    ),
    callback: (args, extra) => run(() => session.updateItem(
        (args['index'] as num).toInt(),
        args['location'] as String,
        Map<String, dynamic>.from(args['fields'] as Map))),
  );

  server.registerTool(
    'duplicate_item',
    description: 'Duplicate an item (upstream Copy semantics: same fields).',
    inputSchema: JsonSchema.object(
      properties: {
        'index': JsonSchema.integer(),
        'location': JsonSchema.string(
            enumValues: const ['inventory', 'chest']),
      },
      required: ['index', 'location'],
    ),
    callback: (args, extra) => run(() => session.duplicateItem(
        (args['index'] as num).toInt(), args['location'] as String)),
  );

  server.registerTool(
    'move_item',
    description:
        'Move an item between inventory and storage chest (toggles location).',
    inputSchema: JsonSchema.object(
      properties: {
        'index': JsonSchema.integer(),
        'location': JsonSchema.string(
            enumValues: const ['inventory', 'chest']),
      },
      required: ['index', 'location'],
    ),
    callback: (args, extra) => run(() => session.moveItem(
        (args['index'] as num).toInt(), args['location'] as String)),
  );

  server.registerTool(
    'remove_item',
    description: 'Delete an item by index and location.',
    inputSchema: JsonSchema.object(
      properties: {
        'index': JsonSchema.integer(),
        'location': JsonSchema.string(
            enumValues: const ['inventory', 'chest']),
      },
      required: ['index', 'location'],
    ),
    callback: (args, extra) => run(() {
          session.removeItem(
              (args['index'] as num).toInt(), args['location'] as String);
          return {'removed': args['index']};
        }),
  );

  server.registerTool(
    'set_currency',
    description:
        'Set a currency count. type: Emerald | Gold | EyeOfEnder (or any custom type).',
    inputSchema: JsonSchema.object(
      properties: {
        'type': JsonSchema.string(),
        'count': JsonSchema.integer(),
      },
      required: ['type', 'count'],
    ),
    callback: (args, extra) => run(() => session.setCurrency(
        args['type'] as String, (args['count'] as num).toInt())),
  );

  server.registerTool(
    'set_level',
    description: 'Set character level (writes the corresponding xp value).',
    inputSchema: JsonSchema.object(
      properties: {'level': JsonSchema.integer()},
      required: ['level'],
    ),
    callback: (args, extra) =>
        run(() => session.setLevel((args['level'] as num).toInt())),
  );

  server.registerTool(
    'set_xp',
    description: 'Set character xp directly.',
    inputSchema: JsonSchema.object(
      properties: {'xp': JsonSchema.integer()},
      required: ['xp'],
    ),
    callback: (args, extra) =>
        run(() => session.setXp((args['xp'] as num).toInt())),
  );

  server.registerTool(
    'save',
    description:
        'Write the modified save back to disk. Extension decides format: '
        '.dat writes encrypted, .json writes decrypted. Omit path to overwrite the opened file.',
    inputSchema: JsonSchema.object(
      properties: {'path': JsonSchema.string()},
    ),
    callback: (args, extra) => run(() => session.save(args['path'] as String?)),
  );
}
