import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class CachingService {
  final Dio _dio = Dio();
  final String _saavnUrl = "https://saavn.sumit.co";

  /// Downloads a song using the JioSaavn ID directly from the API
  Future<String?> cacheSong(String songId, int index,
      {Function(double)? onProgress}) async {
    try {
      // 1. Check Local Cache
      final localPath = await getCachedPath(index);
      if (localPath != null) {
        if (onProgress != null) onProgress(1.0);
        return localPath;
      }

      print("⬇️ Fetching Metadata for ID: $songId...");

      // 2. Fetch Song Details directly from JioSaavn API
      final response = await _dio.get('$_saavnUrl/api/songs/$songId');

      if (response.statusCode != 200 || response.data['success'] == false) {
        print("❌ API Error: ${response.data}");
        return null;
      }

      final data = response.data['data'];
      if ((data as List).isEmpty) return null;

      final songData = data[0];
      final List downloads = songData['downloadUrl'];

      // 3. Find Best Quality (320kbps > 160kbps > Last)
      String? downloadUrl;

      // Try 320kbps
      final q320 = downloads.firstWhere((d) => d['quality'] == "320kbps",
          orElse: () => null);
      if (q320 != null) downloadUrl = q320['url'];

      // Try 160kbps (Fallback 1)
      if (downloadUrl == null) {
        final q160 = downloads.firstWhere((d) => d['quality'] == "160kbps",
            orElse: () => null);
        if (q160 != null) downloadUrl = q160['url'];
      }

      // Fallback 2: Last available
      if (downloadUrl == null && downloads.isNotEmpty) {
        downloadUrl = downloads.last['url'];
      }

      if (downloadUrl == null) {
        print("❌ No download URL found.");
        return null;
      }

      print("✅ Got URL. Downloading...");

      // 4. Download the File
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/song_$index.m4a';

      await _dio.download(downloadUrl, filePath,
          onReceiveProgress: (received, total) {
        if (total != -1 && onProgress != null) {
          onProgress(received / total);
        }
      });

      print("✅ Download Complete: $filePath");
      return filePath;
    } catch (e) {
      print("❌ Error downloading: $e");
      return null;
    }
  }

  /// 2. Clear Old Cache (To save space)
  Future<void> deleteSong(int index) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/song_$index.m4a');
      if (await file.exists()) {
        await file.delete();
        print("🗑️ Song $index deleted");
      }
    } catch (e) {
      print("Error deleting song $index: $e");
    }
  }

  Future<String?> getCachedPath(int index) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/song_$index.m4a');
    return (await file.exists()) ? file.path : null;
  }
}
