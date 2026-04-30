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

  // ── Windows: download via HttpClient (handles GitHub CDN redirects)
  static Future<void> _windowsUpdate(
    String downloadUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    final savePath = '${Directory.systemTemp.path}\\InvoicePOS_Update.exe';

    // Use dart:io HttpClient for reliable redirect handling on Windows
    final client   = HttpClient();
    client.autoUncompress = false;
    var uri        = Uri.parse(downloadUrl);
    int redirects  = 0;

    while (redirects < 10) {
      final req  = await client.getUrl(uri);
      req.headers.set('User-Agent', 'InvoicePOS-Updater/1.0');
      final resp = await req.close();

      if (resp.statusCode >= 300 && resp.statusCode < 400) {
        final location = resp.headers.value('location');
        if (location == null) throw Exception('Redirect with no location');
        uri = uri.resolve(location);
        redirects++;
        continue;
      }

      if (resp.statusCode != 200) {
        throw Exception('Download failed: HTTP ${resp.statusCode}');
      }

      final total = resp.contentLength;
      var received = 0;
      final file   = File(savePath).openWrite();
      await for (final chunk in resp) {
        file.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await file.flush();
      await file.close();
      break;
    }
    client.close();

    // Launch Inno Setup installer silently — it closes & replaces the running app
    await Process.start(savePath,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        runInShell: false);
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
