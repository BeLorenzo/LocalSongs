import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? apkDownloadUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.apkDownloadUrl,
    required this.releaseNotes,
  });

  Map<String, dynamic> toJson() => {
        'hasUpdate': hasUpdate,
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'releaseUrl': releaseUrl,
        'apkDownloadUrl': apkDownloadUrl,
        'releaseNotes': releaseNotes,
      };

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
        hasUpdate: json['hasUpdate'] as bool? ?? false,
        currentVersion: json['currentVersion'] as String? ?? '',
        latestVersion: json['latestVersion'] as String? ?? '',
        releaseUrl: json['releaseUrl'] as String? ?? '',
        apkDownloadUrl: json['apkDownloadUrl'] as String?,
        releaseNotes: json['releaseNotes'] as String? ?? '',
      );
}

class UpdateService {
  static const String repoSlug = 'BeLorenzo/LocalSongs';
  static const String _cacheKeyData = 'localsongs_update_data';
  static const String _cacheKeyTime = 'localsongs_update_time';
  static const int _cacheNegativeTtlMs = 60 * 1000; // 1 min se no update
  static const int _cachePositiveTtlMs = 15 * 60 * 1000; // 15 min se update presente

  static List<int> _parseSemver(String v) {
    final clean = v.replaceFirst(RegExp(r'^[vV]'), '').trim();
    final parts = clean.split('.');
    return [
      if (parts.isNotEmpty) int.tryParse(parts[0]) ?? 0 else 0,
      if (parts.length > 1) int.tryParse(parts[1]) ?? 0 else 0,
      if (parts.length > 2) int.tryParse(parts[2].split('+')[0].split('-')[0]) ?? 0 else 0,
    ];
  }

  static bool isNewer(String latest, String current) {
    final l = _parseSemver(latest);
    final c = _parseSemver(current);

    if (l[0] > c[0]) return true;
    if (l[0] < c[0]) return false;
    if (l[1] > c[1]) return true;
    if (l[1] < c[1]) return false;
    return l[2] > c[2];
  }

  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.isNotEmpty ? info.version : '1.0.0';
    } catch (_) {
      return '1.0.0';
    }
  }

  static Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = await getCurrentVersion();

      if (!force) {
        final cachedJson = prefs.getString(_cacheKeyData);
        final cachedTime = prefs.getInt(_cacheKeyTime) ?? 0;
        final elapsed = DateTime.now().millisecondsSinceEpoch - cachedTime;

        if (cachedJson != null) {
          try {
            final data = UpdateInfo.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
            if (data.currentVersion == currentVersion) {
              final stillNewer = isNewer(data.latestVersion, currentVersion);
              final ttl = stillNewer ? _cachePositiveTtlMs : _cacheNegativeTtlMs;
              if (elapsed < ttl) {
                return UpdateInfo(
                  hasUpdate: stillNewer,
                  currentVersion: currentVersion,
                  latestVersion: data.latestVersion,
                  releaseUrl: data.releaseUrl,
                  apkDownloadUrl: data.apkDownloadUrl,
                  releaseNotes: data.releaseNotes,
                );
              }
            }
          } catch (_) {}
        }
      }

      final url = Uri.parse('https://api.github.com/repos/$repoSlug/releases/latest');
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'LocalSongs-Flutter-App',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final latestTag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
        final releaseUrl = json['html_url'] as String? ?? 'https://github.com/$repoSlug/releases';
        final releaseNotes = json['body'] as String? ?? '';

        String? apkDownloadUrl;
        final assets = json['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              apkDownloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }

        final hasNewerVersion = isNewer(latestTag, currentVersion);
        final updateInfo = UpdateInfo(
          hasUpdate: hasNewerVersion,
          currentVersion: currentVersion,
          latestVersion: latestTag,
          releaseUrl: releaseUrl,
          apkDownloadUrl: apkDownloadUrl,
          releaseNotes: releaseNotes,
        );

        // Salva in cache
        await prefs.setString(_cacheKeyData, jsonEncode(updateInfo.toJson()));
        await prefs.setInt(_cacheKeyTime, DateTime.now().millisecondsSinceEpoch);

        return updateInfo;
      }
    } catch (e) {
      debugPrint('[UpdateService] Errore verifica aggiornamenti: $e');
    }
    return null;
  }

  static Future<bool> openDownload(String url) async {
    final uri = Uri.parse(url);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UpdateService] Errore apertura URL: $e');
      return false;
    }
  }
}
