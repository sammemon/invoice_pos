import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../core/network/api_client.dart';

class UpdateService {
  static final _dio = Dio(BaseOptions(
    followRedirects: true,          // GitHub Releases 302→CDN
    maxRedirects: 10,
    validateStatus: (s) => s != null && s < 400,
  ));

  static Future<Map<String, dynamic>> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final platform = Platform.isAndroid ? 'android' : 'windows';
    final res = await ApiClient.instance.get(
      '/version/check',
      params: {'platform': platform, 'currentVersion': info.version},
    );
    return Map<String, dynamic>.from(res.data);
  }

  /// Windows: download new installer to temp and run silently.
  /// Inno Setup /SILENT overwrites existing install — no uninstall needed.
  /// Android: download APK to storage and open installer.
  static Future<void> downloadAndInstall(
    String? downloadUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (downloadUrl == null || downloadUrl.isEmpty) return;
    if (Platform.isWindows) {
      await _windowsUpdate(downloadUrl, onProgress: onProgress);
    } else if (Platform.isAndroid) {
      await _androidUpdate(downloadUrl, onProgress: onProgress);
    }
  }

  // ── Windows: download via curl (built into Windows 10/11)
  // curl -L follows GitHub's 302→CDN redirect chain natively and is
  // far more reliable than dart:io HttpClient in compiled Flutter apps.
  static Future<void> _windowsUpdate(
    String downloadUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    final savePath = '${Directory.systemTemp.path}\\InvoicePOS_Update.exe';

    // Delete any stale file from a previous failed attempt
    final f = File(savePath);
    if (f.existsSync()) f.deleteSync();

    final result = await Process.run(
      'curl',
      [
        '-L',                  // follow redirects (GitHub → CDN)
        '--silent',
        '--show-error',
        '--output', savePath,
        '--retry', '3',
        '--retry-delay', '2',
        downloadUrl,
      ],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception('curl failed (${result.exitCode}): ${result.stderr}');
    }

    if (!File(savePath).existsSync()) {
      throw Exception('Downloaded file not found after curl completed');
    }

    // Launch installer with UAC elevation via PowerShell 'runas' verb.
    // /SILENT keeps the wizard hidden but still shows the progress bar.
    // Without elevation, schtasks.exe fails with "Access denied" (error code 5).
    await Process.run(
      'powershell',
      [
        '-WindowStyle', 'Hidden',
        '-Command',
        'Start-Process -FilePath "$savePath" '
            '-ArgumentList "/SILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS" '
            '-Verb RunAs',
      ],
      runInShell: false,
    );
    await Future.delayed(const Duration(seconds: 2));
    exit(0);
  }

  // ── Android: download APK + open installer ────────────────────
  static Future<void> _androidUpdate(
    String downloadUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getExternalStorageDirectory() ??
                  await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/InvoicePOS_Update.apk';

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: onProgress,
        options: Options(receiveTimeout: const Duration(minutes: 15)),
      );

      await OpenFilex.open(savePath);
    } catch (e) {
      debugPrint('APK update failed: $e');
    }
  }

  // ── Silent startup check ──────────────────────────────────────
  static Future<UpdateResult?> silentCheck() async {
    try {
      final result = await checkForUpdate();
      if (result['hasUpdate'] == true) {
        return UpdateResult(
          latestVersion: result['latestVersion'] ?? '',
          downloadUrl:   result['downloadUrl']   ?? '',
          releaseNotes:  result['releaseNotes']  ?? '',
          isForceUpdate: result['isForceUpdate'] ?? false,
        );
      }
    } catch (_) {
      // Never break the app if update check fails
    }
    return null;
  }
}

class UpdateResult {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isForceUpdate;

  const UpdateResult({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isForceUpdate,
  });
}
