// lib/song_selection_screen.dart

import 'dart:async'; // Import async for Timer
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:beat_sync/audio_player_service.dart';
import 'package:beat_sync/music_service.dart';
import 'package:beat_sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SongSelectionScreen extends StatefulWidget {
  final String roomId;
  const SongSelectionScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<SongSelectionScreen> createState() => _SongSelectionScreenState();
}

class _SongSelectionScreenState extends State<SongSelectionScreen> {
  List<String> _songList = [];
  bool _isLoadingSongs = false;
  String? _currentlyPlayingSong;

  // Timer to periodically update the host's position
  Timer? _positionSyncTimer;

  @override
  void initState() {
    super.initState();
    _fetchSongList();
  }

  Future<void> _fetchSongList() async {
    setState(() => _isLoadingSongs = true);
    try {
      final songs = await MusicService.fetchSongs();
      setState(() => _songList = songs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching songs: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoadingSongs = false);
    }
  }

  Future<void> _onSongSelected(String songName) async {
    try {
      // Cancel any existing timer before starting a new song
      _positionSyncTimer?.cancel();

      final signedUrl = await MusicService.fetchSignedUrl(songName);
      final player = AudioPlayerService.instance.player;

      await player.setUrl(signedUrl);
      player.play();

      setState(() {
        _currentlyPlayingSong = songName;
      });

      // Initial update to Supabase to start the song for everyone
      await Supabase.instance.client.from('rooms').update({
        'current_song_name': songName,
        'current_song_url': signedUrl,
        'is_playing': true,
        'current_position_seconds': 0.0,
        'last_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.roomId);

      // Use the sync service for more precise position updates
      SyncService().startHostPositionUpdates(widget.roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing song: ${e.toString()}')));
      }
    }
  }

  @override
  void dispose() {
    // Make sure to cancel the timer when the screen is closed
    _positionSyncTimer?.cancel();
    // Stop host position updates
    SyncService().stopHostPositionUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Song'),
        elevation: 4,
      ),
      body: _isLoadingSongs
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _songList.length,
              itemBuilder: (context, index) {
                final songName = _songList[index];
                final isCurrentlyThisSong = songName == _currentlyPlayingSong;
                return StreamBuilder<PlayerState>(
                  stream: AudioPlayerService.instance.player.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data?.playing ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: ListTile(
                        leading: Icon(
                          (isPlaying && isCurrentlyThisSong)
                              ? Icons.volume_up
                              : Icons.music_note,
                          color: (isPlaying && isCurrentlyThisSong)
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: Text(
                          songName.replaceAll('.mp3', ''),
                          style: TextStyle(
                            fontWeight: isCurrentlyThisSong
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrentlyThisSong
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        trailing: isCurrentlyThisSong
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: const Text(
                                  'Playing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => _onSongSelected(songName),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}