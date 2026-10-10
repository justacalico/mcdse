import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/constants.dart';
import '../models/app_update.dart';
import '../utils/version_utils.dart';

/// Checks GitLab Releases for a newer version of the app.
///
/// Paginates `GET /projects/:id/releases`, picks the highest tag that parses
/// as semver (cog tags are `vX.Y.Z`; the `v` is stripped), and compares it
/// against the installed version.
class VersionChecker {
  VersionChecker({http.Client? client, String? apiUrl, String? releasesBaseUrl})
      : _client = client ?? http.Client(),
        _apiUrl = apiUrl ?? Constants.releasesApiUrl,
        _releasesBaseUrl = releasesBaseUrl ?? Constants.latestReleaseUrl;

  final http.Client _client;
  final String _apiUrl;
  final String _releasesBaseUrl;

  Future<AppUpdate?> checkForUpdate(Version current) async {
    final latest = await _fetchLatest();
    if (latest == null) return null;
    if (latest.latestVersion > current) return latest;
    return null;
  }

  /// Returns the newest release (even when not newer than [current]).
  Future<AppUpdate?> fetchLatestRelease() => _fetchLatest();

  Future<AppUpdate?> _fetchLatest() async {
    AppUpdate? best;
    var url = _apiUrl;
    // Follow pagination via the `next` page param.
    for (var page = 1; page <= 10; page++) {
      final pageUrl = '$url&page=$page';
      final response = await _client.get(Uri.parse(pageUrl));
      if (response.statusCode != 200) {
        throw Exception('releases API returned ${response.statusCode}');
      }
      final body = json.decode(response.body);
      if (body is! List || body.isEmpty) break;
      var sawRelease = false;
      for (final entry in body) {
        if (entry is! Map<String, dynamic>) continue;
        final tagName = entry['tag_name'] as String?;
        if (tagName == null) continue;
        final version = Version.tryParse(tagName);
        if (version == null) continue;
        sawRelease = true;
        if (best == null || version > best.latestVersion) {
          best = AppUpdate(
            latestVersion: version,
            tagName: tagName,
            releaseUrl: '$_releasesBaseUrl/$tagName',
          );
        }
      }
      if (body.length < 100 || !sawRelease) break;
    }
    return best;
  }
}
