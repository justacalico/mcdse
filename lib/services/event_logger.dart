import 'dart:developer' as developer;

/// Local stand-in for upstream's GameAnalytics-backed `EventLogger`.
/// Events are written to the debug log only — nothing is sent anywhere.
abstract final class EventLogger {
  static void init() {}

  static void dispose() {}

  static void logEvent(String eventId, [Map<String, Object>? fields]) {
    if (fields != null) {
      final fieldsStr =
          fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
      developer.log('[EVENT] $eventId fields: $fieldsStr');
    } else {
      developer.log('[EVENT] $eventId');
    }
  }

  static void logEventValue(String eventId, double value) {
    developer.log('[EVENT] $eventId value=$value');
  }

  static void logError(String message) {
    developer.log('[ERROR] $message');
  }
}
