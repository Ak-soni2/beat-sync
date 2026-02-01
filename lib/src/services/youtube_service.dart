import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Gets the highest bitrate audio-only stream URL for a video.
  Future<String?> getAudioUrl(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      var audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      print("Error getting audio URL for $videoId: $e");
      return null;
    }
  }

  /// Searches for videos on YouTube.
  Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    try {
      final results = await _yt.search.search(query);
      return results.map((video) {
        return {
          'id': video.id.value,
          'title': video.title,
          'thumbnail': video.thumbnails.mediumResUrl,
          'duration_ms': video.duration?.inMilliseconds ?? 0,
        };
      }).toList();
    } catch (e) {
      print("Error searching YouTube for $query: $e");
      return [];
    }
  }

  /// Cleans up resources.
  void dispose() {
    _yt.close();
  }
}
