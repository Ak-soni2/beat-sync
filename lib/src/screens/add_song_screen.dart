import 'package:flutter/material.dart';
import 'package:beat_sync/src/services/youtube_service.dart';
import 'package:beat_sync/src/theme/app_theme.dart';
import 'package:beat_sync/src/theme/glass_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddSongScreen extends StatefulWidget {
  final String roomCode;
  const AddSongScreen({Key? key, required this.roomCode}) : super(key: key);

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final TextEditingController _searchController = TextEditingController();
  final YouTubeService _youtubeService = YouTubeService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  void _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final results = await _youtubeService.searchVideos(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addSong(Map<String, dynamic> song) async {
    try {
      // Get current highest order to append
      final res = await Supabase.instance.client
          .from('playlist')
          .select('song_order')
          .eq('room_id', widget.roomCode)
          .order('song_order', ascending: false)
          .limit(1)
          .maybeSingle();

      int nextOrder = res == null ? 0 : (res['song_order'] as int) + 1;

      await Supabase.instance.client.from('playlist').insert({
        'room_id': widget.roomCode,
        'video_id': song['id'],
        'title': song['title'],
        'duration_ms': song['duration_ms'],
        'song_order': nextOrder,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${song['title']}"')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding song: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Add Song'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.background, Color(0xFF1a0529)]),
        ),
        child: Column(
          children: [
            const SizedBox(height: 100),
            GlassContainer(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search YouTube...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: AppTheme.secondary),
                    onPressed: _search,
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final song = _searchResults[index];
                        return ListTile(
                          leading: Image.network(song['thumbnail'],
                              width: 50,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note,
                                  color: Colors.white)),
                          title: Text(song['title'],
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                              "${(song['duration_ms'] / 1000).toStringAsFixed(0)}s",
                              style: const TextStyle(color: Colors.white54)),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: AppTheme.secondary),
                            onPressed: () => _addSong(song),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
