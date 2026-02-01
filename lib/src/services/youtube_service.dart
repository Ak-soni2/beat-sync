import 'package:dio/dio.dart';

class YouTubeService {
  final Dio _dio = Dio();
  final String _saavnUrl = "https://saavn.sumit.co";

  /// Searches for music directly via JioSaavn API
  Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    try {
      final response = await _dio.get(
        '$_saavnUrl/api/search/songs',
        queryParameters: {'query': query, 'limit': 15},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> results = response.data['data']['results'];
        return results.map((song) {
          // Get best quality image (index 2 is usually 500x500)
          String imageUrl = "";
          if (song['image'] != null && (song['image'] as List).isNotEmpty) {
            imageUrl = (song['image'] as List).length > 2
                ? song['image'][2]['url']
                : song['image'][0]['url'];
          }

          // Convert duration (seconds) to milliseconds
          int durationMs =
              (int.tryParse(song['duration'].toString()) ?? 0) * 1000;

          // Parse Artists
          String artistName = "Unknown";
          if (song['artists'] != null && song['artists']['primary'] != null) {
            final primaries = song['artists']['primary'] as List;
            if (primaries.isNotEmpty) {
              artistName = primaries.map((a) => a['name']).join(", ");
            }
          }

          return {
            'id': song['id'],
            'title': song['name'], // API uses 'name', we use 'title'
            'thumbnail': imageUrl,
            'duration_ms': durationMs,
            'artist': artistName
          };
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      print("Error searching music: $e");
      return [];
    }
  }

  void dispose() {
    _dio.close();
  }
}
