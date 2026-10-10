import '../utils/version_utils.dart';

/// Result of an update check against the GitLab releases API.
class AppUpdate {
  const AppUpdate({
    required this.latestVersion,
    required this.tagName,
    required this.releaseUrl,
  });

  final Version latestVersion;
  final String tagName;
  final String releaseUrl;
}

enum UpdateCheckStatus { idle, checking, upToDate, updateAvailable, failed }

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.update,
    this.error,
  });

  final UpdateCheckStatus status;
  final AppUpdate? update;
  final Object? error;
}
