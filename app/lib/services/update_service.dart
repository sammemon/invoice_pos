import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../core/network/api_client.dart';

class UpdateService {
  static final _dio = Dio();

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

  // ── Windows: download + silent install ───────────────────────
  static Future<void> _windowsUpdate(
    String downloadUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    final savePath = '${Directory.systemTemp.path}\\InvoicePOS_Update.exe';

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(receiveTimeout: const Duration(minutes: 15)),
    );

    // Run Inno Setup installer silently:
    //  /SILENT             → no wizard pages, shows only progress bar
    //  /CLOSEAPPLICATIONS  → automatically closes current running instance
    //  /RESTARTAPPLICATIONS → re-launches app after update completes
    await Process.start(
      savePath,
      ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
      runInShell: false,
    );

    // Give installer time to start, then exit so it can overwrite files
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
