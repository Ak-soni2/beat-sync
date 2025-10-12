// lib/sync_service.dart

import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_sync/audio_player_service.dart';

/// A service to handle precise audio synchronization across devices
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  String? _currentUrl;
  Timer? _heartbeatTimer;
  Timer? _hostPositionTimer;
  bool _isSyncing = false;
  bool _wasPlaying = false; // Track previous playing state

  /// Sync a listener's player with the host's state
  Future<void> syncListenerPlayer({
    required Map<String, dynamic> roomData,
    required bool isInitialSync,
  }) async {
    final player = AudioPlayerService.instance.player;
    final newUrl = roomData['current_song_url'] as String?;
    final isPlaying = roomData['is_playing'] as bool? ?? false;
    final lastUpdatedAtStr = roomData['last_updated_at'] as String?;
    final positionNum = roomData['current_position_seconds'] as num? ?? 0;
    final positionSeconds = positionNum.toDouble();

    // If this is initial sync and there's no song, don't do anything
    if (isInitialSync && newUrl == null) {
      return;
    }

    try {
      if (newUrl != null && (_currentUrl != newUrl || isInitialSync)) {
        // Update current URL tracking
        _currentUrl = newUrl;
        
        // Load new song
        await player.setUrl(newUrl);
        
        if (lastUpdatedAtStr != null) {
          // Calculate precise position with latency compensation
          final lastUpdatedAt = DateTime.parse(lastUpdatedAtStr);
          final now = DateTime.now().toUtc();
          final latency = now.difference(lastUpdatedAt);
          
          final seekPosition = Duration(seconds: positionSeconds.toInt()) + latency;
          await player.seek(seekPosition);
        }
        
        // Set play state based on host
        if (isPlaying) {
          await player.play();
          _wasPlaying = true;
        } else {
          _wasPlaying = false;
        }
      } else if (newUrl != null) {
        // Same song, sync position and play state
        
        // Check if play state changed (host pressed play after pause)
        if (_wasPlaying != isPlaying) {
          if (isPlaying) {
            // Host pressed play, sync position and play
            if (lastUpdatedAtStr != null) {
              final lastUpdatedAt = DateTime.parse(lastUpdatedAtStr);
              final now = DateTime.now().toUtc();
              final latency = now.difference(lastUpdatedAt);
              
              final seekPosition = Duration(seconds: positionSeconds.toInt()) + latency;
              await player.seek(seekPosition);
            }
            await player.play();
          } else {
            // Host pressed pause
            await player.pause();
          }
          _wasPlaying = isPlaying;
        } else if (isPlaying) {
          // Both were playing, sync position if needed
          if (lastUpdatedAtStr != null) {
            final lastUpdatedAt = DateTime.parse(lastUpdatedAtStr);
            final now = DateTime.now().toUtc();
            final latency = now.difference(lastUpdatedAt);
            
            final seekPosition = Duration(seconds: positionSeconds.toInt()) + latency;
            
            // Only seek if difference is significant (more than 500ms)
            if ((player.position - seekPosition).abs() > const Duration(milliseconds: 500)) {
              await player.seek(seekPosition);
            }
          }
        }
      }
    } catch (e) {
      print('Error syncing listener player: $e');
      rethrow;
    }
  }

  /// Start heartbeat mechanism for continuous sync checking
  void startHeartbeatSync(String roomId) {
    // Cancel any existing heartbeat timer
    _heartbeatTimer?.cancel();
    
    // Start heartbeat timer (check every 1 second)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isSyncing) return;
      
      try {
        _isSyncing = true;
        
        // Fetch current room state
        final roomData = await Supabase.instance.client
            .from('rooms')
            .select()
            .eq('id', roomId)
            .single();
            
        // Sync with current room state
        await syncListenerPlayer(roomData: roomData, isInitialSync: false);
      } catch (e) {
        print('Heartbeat sync error: $e');
      } finally {
        _isSyncing = false;
      }
    });
  }

  /// Update host position in database
  void startHostPositionUpdates(String roomId) {
    final player = AudioPlayerService.instance.player;
    
    // Cancel any existing host timer
    _hostPositionTimer?.cancel();
    
    // Update position more frequently for better sync (every 200ms)
    _hostPositionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (player.playing) {
        Supabase.instance.client.from('rooms').update({
          'current_position_seconds': player.position.inMilliseconds / 1000.0,
          'last_updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', roomId);
      }
    });
  }
  
  /// Reset current URL tracking and cancel timers
  void reset() {
    _currentUrl = null;
    _heartbeatTimer?.cancel();
    _hostPositionTimer?.cancel();
    _isSyncing = false;
    _wasPlaying = false;
  }
  
  /// Stop heartbeat sync (for listeners when leaving room)
  void stopHeartbeatSync() {
    _heartbeatTimer?.cancel();
  }
  
  /// Stop host position updates (for hosts when leaving room)
  void stopHostPositionUpdates() {
    _hostPositionTimer?.cancel();
  }
}