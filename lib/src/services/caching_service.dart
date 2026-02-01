import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class CachingService {
  final Dio _dio = Dio();
  // Hosted Backend (Vercel)
  final String _backendUrl = "https://beat-sync-backend.vercel.app";

  /// 1. Extract & Download a Song
  /// Returns the LOCAL path of the downloaded file
  Future<String?> cacheSong(String videoId, int index,
      {Function(double)? onProgress}) async {
    try {
      // 1. Check Local Cache First
      final localPath = await getCachedPath(index);
      if (localPath != null) {
        if (onProgress != null) onProgress(1.0);
        return localPath;
      }

      print("⬇️ Asking Server for URL: $videoId...");

      // 2. Ask Node.js for the URL
      // (This bypasses the blocking because Node.js does the work)
      final response =
          await _dio.get('$_backendUrl/get-audio-url?videoId=$videoId');

      if (response.statusCode != 200) {
        print("❌ Server refused: ${response.data}");
        return null;
      }

      final String downloadUrl = response.data['url'];
      print("✅ Got URL from Server. Downloading...");

      // 3. Prepare File
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/song_$index.m4a';

      // 4. Download the File
      await _dio.download(downloadUrl, filePath,
          onReceiveProgress: (received, total) {
        if (total != -1 && onProgress != null) {
          onProgress(received / total);
        }
      });

      return filePath;
    } catch (e) {
      print("❌ Error caching song: $e");
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

  /// 3. Get Local Path if exists
  Future<String?> getCachedPath(int index) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/song_$index.m4a');
    return (await file.exists()) ? file.path : null;
  }
}
