import 'package:flutter/foundation.dart';

/// Local stand-in for upstream's GameAnalytics-backed `EventLogger`.
/// Events are written to the debug log only — nothing is sent anywhere.
abstract final class EventLogger {
  static void init() {}

  static void dispose() {}

  static void logEvent(String eventId, [Map<String, Object>? fields]) {
    if (fields != null) {
      final fieldsStr =
          fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
      debugPrint('[EVENT] $eventId fields: $fieldsStr');
    } else {
      debugPrint('[EVENT] $eventId');
    }
  }

  static void logEventValue(String eventId, double value) {
    debugPrint('[EVENT] $eventId value=$value');
  }

  static void logError(String message) {
    debugPrint('[ERROR] $message');
  }
}
