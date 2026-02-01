import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'caching_service.dart';

enum RoomStatus { open, preparing, ready, playing }

class MusicLogicService extends ChangeNotifier {
  static final MusicLogicService _instance = MusicLogicService._internal();
  factory MusicLogicService() => _instance;
  MusicLogicService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache = CachingService();
  final AudioPlayer _player = AudioPlayer();

  String? _roomCode; // room ID
  String? _currentUserId;

  RoomStatus _status = RoomStatus.open;
  int _currentSongIndex = -1;
  bool _isPlaying = false;

  // Progress Reporting: "Step 1/3: Caching..."
  final StreamController<String> _progressController =
      StreamController.broadcast();
  Stream<String> get progressStream => _progressController.stream;

  final StreamController<void> _roomClosedController =
      StreamController<void>.broadcast();
  Stream<void> get roomClosedStream => _roomClosedController.stream;

  // Getters
  AudioPlayer get player => _player;
  bool get isPlaying => _isPlaying;
  int get currentSongIndex => _currentSongIndex;
  RoomStatus get status => _status;

  /// Call this when joining a room
  Future<void> init(String roomCode, String userId) async {
    _roomCode = roomCode;
    _currentUserId = userId;

    // Reset state
    _status = RoomStatus.open;
    _currentSongIndex = -1;
    _isPlaying = false;
    _progressController.add("0%: Connecting to Room...");

    _listenToRoomUpdates();

    // Listen to player state to trigger next song logic
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleSongFinished();
      }
    });
  }

  void _listenToRoomUpdates() {
    _supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', _roomCode!)
        .listen((data) async {
          // Handle Room Deletion
          if (data.isEmpty) {
            _roomClosedController.add(null);
            return;
          }
          final room = data.first;

          // Parse State
          final newStatusStr = room['status'] as String? ?? 'open';
          final newStatus = RoomStatus.values.firstWhere(
              (e) => e.name == newStatusStr,
              orElse: () => RoomStatus.open);

          final serverIndex = room['current_song_index'] as int? ?? -1;
          final serverIsPlaying = room['is_playing'] as bool? ?? false;
          final startTimestamp = room['start_timestamp'] as int? ?? 0;

          // 1. Status Transition Logic
          if (newStatus != _status) {
            _status = newStatus;
            notifyListeners();

            if (_status == RoomStatus.preparing) {
              await _startSmartCaching();
            } else if (_status == RoomStatus.ready) {
              _progressController.add("100%: Ready! Waiting for Host...");
            }
          }

          // 2. Playback / Join Logic
          if (_status == RoomStatus.playing) {
            // Sync Song Index
            if (serverIndex != _currentSongIndex) {
              _currentSongIndex = serverIndex;
              await _handleNewSong(serverIndex); // Plays automatically
            }

            // Sync Play/Pause
            if (serverIsPlaying && !_player.playing) {
              // Late Joiner / Sync Start
              final now = DateTime.now().millisecondsSinceEpoch;
              final elapsed = now - startTimestamp;

              // Only seek if reasonable offset (and valid timestamp)
              if (startTimestamp > 0 && elapsed > 0) {
                await _player.seek(Duration(milliseconds: elapsed));
              }
              _player.play();
              _isPlaying = true;
              notifyListeners();
            } else if (!serverIsPlaying && _player.playing) {
              _player.pause();
              _isPlaying = false;
              notifyListeners();
            }
          }
        });
  }

  Future<void> killRoom() async {
    // Cascading delete will remove playlist and participants
    await _supabase.from('rooms').delete().eq('id', _roomCode!);
  }

  /// Phase A: Caching
  Future<void> _startSmartCaching() async {
    try {
      _progressController.add("10%: Setting up environment...");

      // 1. Cache Song 1 (Index 0) - BLOCKING
      _progressController.add("50%: Caching Song 1...");
      final song0 = await _getVideoIdFromPlaylist(0);
      if (song0 != null) await _cache.cacheSong(song0, 0);

      // 2. Signal Ready Immediately
      _progressController.add("100%: Ready! (Caching more in background...)");
      await _supabase
          .from('room_participants')
          .update({'is_ready': true})
          .eq('room_id', _roomCode!)
          .eq('profile_id', _currentUserId!);

      // 3. Cache Song 2 (Index 1) - BACKGROUND (Fire & Forget)
      _cacheNextInBackground(1);
    } catch (e) {
      _progressController.add("Error: $e");
    }
  }

  Future<void> _cacheNextInBackground(int index) async {
    try {
      final song = await _getVideoIdFromPlaylist(index);
      if (song != null) await _cache.cacheSong(song, index);
    } catch (e) {
      print("Background cache error: $e");
    }
  }

  /// Host Command: "Finalize Playlist" -> Start Preparing
  Future<void> hostPrepareRoom() async {
    // Reset Readiness
    await _supabase
        .from('room_participants')
        .update({'is_ready': false}).eq('room_id', _roomCode!);

    await _supabase.from('rooms').update({
      'status': 'preparing',
      'current_song_index': 0,
    }).eq('id', _roomCode!);

    // Start Watching for All Ready
    _monitorParticipantsReadiness();
  }

  void _monitorParticipantsReadiness() {
    // Determine if I am host (already checked in UI, but good to be safe or pass a flag)
    // We can just listen regardless, but only update if we are the host.
    // For simplicity, we assume this is called by hostPrepareRoom so we are host.

    _supabase
        .from('room_participants')
        .stream(primaryKey: ['id'])
        .eq('room_id', _roomCode!)
        .listen((data) async {
          if (data.isEmpty) return;

          final total = data.length;
          final readyCount = data.where((p) => p['is_ready'] == true).length;

          if (total > 0 && readyCount == total) {
            // All Ready! Transition to 'ready'
            if (_status == RoomStatus.preparing) {
              await _supabase
                  .from('rooms')
                  .update({'status': 'ready'}).eq('id', _roomCode!);
            }
          }
        });
  }

  /// Host Command: "Play" (From Ready State)
  Future<void> hostStartSession() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _supabase.from('rooms').update({
      'status': 'playing',
      'is_playing': true,
      'start_timestamp': now,
      'current_song_index': 0,
    }).eq('id', _roomCode!);
  }

  Future<void> _handleNewSong(int index) async {
    // Rolling Cache: Delete current - 2 (User requested logic)
    if (index >= 2) {
      await _cache.deleteSong(index - 2);
    }

    // Play Current
    String? localPath = await _cache.getCachedPath(index);
    // If missing (Late joiner who missed Pre-Cache phase?), panic download
    if (localPath == null) {
      _progressController.add("Syncing: Downloading song $index...");
      String? videoId = await _getVideoIdFromPlaylist(index);
      if (videoId != null) {
        localPath = await _cache.cacheSong(videoId, index);
      }
    }

    if (localPath != null) {
      await _player.setFilePath(localPath);
      // Play is triggered by 'is_playing' check in stream listener

      // Rolling Cache: Pre-fetch Next (index + 1)
      _preFetchNextSong(index + 1);
    }
  }

  Future<void> _handleSongFinished() async {
    // Only Host dictates next song?
    // Or we assume auto-advance?
    // Best practice: Host detects finish -> Updates DB -> Everyone advances.

    // Determine if we are host
    final room = await _supabase
        .from('rooms')
        .select('host_id')
        .eq('id', _roomCode!)
        .single();

    if (room['host_id'] == _currentUserId) {
      // WAIT 1 SECOND (Sync Delay) // optional 
      // await Future.delayed(const Duration(seconds: 1));

      final nextIndex = _currentSongIndex + 1;
      // Check if next song exists
      final nextVid = await _getVideoIdFromPlaylist(nextIndex);
      if (nextVid != null) {
        // Advance Room
        final now = DateTime.now().millisecondsSinceEpoch;
        await _supabase.from('rooms').update({
          'current_song_index': nextIndex,
          'start_timestamp': now, // Reset timestamp for next song
        }).eq('id', _roomCode!);
      } else {
        // End of playlist
        await _supabase.from('rooms').update({
          'is_playing': false,
        }).eq('id', _roomCode!);
      }
    }
  }

  Future<void> _preFetchNextSong(int nextIndex) async {
    String? nextVideoId = await _getVideoIdFromPlaylist(nextIndex);
    if (nextVideoId != null) {
      print("⬇️ Pre-fetching Song $nextIndex...");
      await _cache.cacheSong(nextVideoId, nextIndex);
    }
  }

  Future<String?> _getVideoIdFromPlaylist(int index) async {
    final data = await _supabase
        .from('playlist')
        .select('video_id')
        .eq('room_id', _roomCode!)
        .eq('song_order', index)
        .maybeSingle();
    return data?['video_id'];
  }

  // Host Controls (Pause/Resume)
  Future<void> updatePlayState(bool isPlaying) async {
    _isPlaying = isPlaying;
    notifyListeners();
    // If Resuming, we might want to update timestamp?
    // For simplicity, just update is_playing.
    // Ideally, pause/resume adjusts timestamp to avoid skip.
    // But for 'Smart Cache' logic focusing on tracks, this is acceptable.

    await _supabase.from('rooms').update({
      'is_playing': isPlaying,
    }).eq('id', _roomCode!);
  }

  void dispose() {
    _player.dispose();
    _progressController.close();
    super.dispose();
  }
}
