import 'package:flutter/foundation.dart';

import '../data/constants.dart';
import '../models/app_update.dart';
import '../utils/version_utils.dart';
import 'string_library.dart';
import 'version_checker.dart';

/// Ported + adapted from `Services/Config.cs`.
///
/// Upstream fetched `github.com/.../releases/latest` for the newest version.
/// This port checks the project's GitLab Releases instead.
class Config {
  Config({VersionChecker? versionChecker})
      : versionChecker = versionChecker ?? VersionChecker();

  static Config instance = Config();

  final VersionChecker versionChecker;

  bool isConfigsReady = false;

  bool get showInventoryIndexOrEquipmentSlot => kDebugMode;
  bool get showIDsInSelectionWindow => kDebugMode;

  String? stableReleaseVersionString;
  String? betaReleaseVersionString;
  AppUpdate? latestUpdate;

  static Version get currentVersion =>
      Version.tryParse(Constants.currentVersionNumber) ?? const Version(0, 0, 0);

  Future<void> downloadAsync() async {
    try {
      final update = await versionChecker.fetchLatestRelease();
      if (update != null) {
        latestUpdate = update;
        stableReleaseVersionString = update.latestVersion.toString();
        betaReleaseVersionString = '';
      }
      isConfigsReady = true;
    } catch (e) {
      debugPrint('$e');
    }
  }

  String newVersionDownloadURL() => Constants.latestReleaseUrl;

  String versionLabel() {
    final stable = stableReleaseVersionString;
    final beta = betaReleaseVersionString;
    if (stable != null &&
        stable.isNotEmpty &&
        currentVersion == (Version.tryParse(stable) ?? const Version(-1, 0, 0))) {
      return R.stableVersionLabel;
    }
    if (beta != null &&
        beta.isNotEmpty &&
        currentVersion == (Version.tryParse(beta) ?? const Version(-1, 0, 0))) {
      return R.betaVersionLabel;
    }
    if (beta != null &&
        beta.isNotEmpty &&
        currentVersion > (Version.tryParse(beta) ?? const Version(-1, 0, 0))) {
      return R.unreleasedVersionLabel;
    }
    return R.oldVersionLabel;
  }

  bool isNewBetaVersionAvailable() {
    final beta = betaReleaseVersionString;
    if (beta == null || beta.isEmpty) return false;
    final betaVersion = Version.tryParse(beta);
    if (betaVersion == null) return false;
    return currentVersion < betaVersion;
  }

  bool isNewStableVersionAvailable() {
    final stable = stableReleaseVersionString;
    if (stable == null || stable.isEmpty) return false;
    final stableVersion = Version.tryParse(stable);
    if (stableVersion == null) return false;
    return currentVersion < stableVersion;
  }
}
