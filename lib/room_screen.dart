// lib/room_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:beat_sync/audio_player_service.dart';
import 'package:beat_sync/now_playing_sheet.dart';
import 'package:beat_sync/song_selection_screen.dart';
import 'package:beat_sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  const RoomScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  RealtimeChannel? _roomChannel;
  Stream<Map<String, dynamic>>? _roomStream;
  Stream<List<Map<String, dynamic>>>? _participantsStream;
  Timer? _syncTimer;

  bool _isHost = false;
  String _currentUserId = '';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id') ?? '';

      final roomData = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('id', widget.roomId)
          .single();

      // Check if user is a participant
      final participantData = await Supabase.instance.client
          .from('room_participants')
          .select()
          .eq('room_id', widget.roomId)
          .eq('profile_id', _currentUserId)
          .maybeSingle();

      if (participantData == null && roomData['host_id'] != _currentUserId) {
        // User is not a participant and not the host
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are not authorized to join this room')),
          );
          Navigator.of(context).pop();
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isHost = roomData['host_id'] == _currentUserId;
          _isInitialized = true;
        });
      }

      // For listeners, sync immediately on join and save to recently joined
      if (!_isHost) {
        SyncService().syncListenerPlayer(roomData: roomData, isInitialSync: true);
        // Start heartbeat mechanism for continuous sync
        SyncService().startHeartbeatSync(widget.roomId);
        // Save to recently joined rooms
        _saveToRecentlyJoinedRooms();
      }

      setState(() {
        _roomStream = Supabase.instance.client
          .from('rooms')
          .stream(primaryKey: ['id'])
          .eq('id', widget.roomId)
          .map((data) => data.first);

        _participantsStream = Supabase.instance.client
          .from('room_participants')
          .stream(primaryKey: ['room_id', 'profile_id'])
          .eq('room_id', widget.roomId)
          .map((data) => data.map((e) => e as Map<String, dynamic>).toList());

        _roomChannel = Supabase.instance.client.channel('room-${widget.roomId}');
      });

      // Only listen to the stream if it's not null
      _roomStream?.listen((roomData) {
        _onRoomUpdate(roomData);
      });
      
      _roomChannel?.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.roomId,
        ),
        callback: (payload) {
          if (mounted) {
            if (!_isHost) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('The host has ended the room.')),
              );
            }
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      );
      _roomChannel?.subscribe();
    } catch (e) {
      print('Error initializing room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading room: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _onRoomUpdate(Map<String, dynamic> roomData, {bool isInitialSync = false}) {
    if (_isHost) return;
    
    // Use the sync service for better synchronization
    SyncService().syncListenerPlayer(roomData: roomData, isInitialSync: isInitialSync);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    if (_roomChannel != null) {
      Supabase.instance.client.removeChannel(_roomChannel!);
    }
    // Stop sync service timers
    if (_isHost) {
      SyncService().stopHostPositionUpdates();
    } else {
      SyncService().stopHeartbeatSync();
    }
    super.dispose();
  }

  // Function to save room to recently joined rooms
  Future<void> _saveToRecentlyJoinedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final recentlyJoinedRoomsJson = prefs.getString('recently_joined_rooms') ?? '[]';
    final List<dynamic> roomIds = jsonDecode(recentlyJoinedRoomsJson);
    final updatedList = List<String>.from(roomIds);
    
    // Add the room ID to the beginning of the list
    if (!updatedList.contains(widget.roomId)) {
      updatedList.insert(0, widget.roomId);
    } else {
      // Move to the beginning if it already exists
      updatedList.remove(widget.roomId);
      updatedList.insert(0, widget.roomId);
    }
    
    // Keep only the last 10 rooms
    if (updatedList.length > 10) {
      updatedList.removeRange(10, updatedList.length);
    }
    
    await prefs.setString('recently_joined_rooms', jsonEncode(updatedList));
  }

  Future<void> _showEndRoomDialog() async {
    final didRequestEnd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('End Room'),
              content: const Text(
                  'This will permanently delete the room for everyone. Are you sure?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('End Room')),
              ],
            ));

    if (didRequestEnd == true) {
      await Supabase.instance.client
          .from('rooms')
          .delete()
          .eq('id', widget.roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Details'),
        actions: [
          if (_isHost)
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'End Room for Everyone',
              onPressed: _showEndRoomDialog,
            ),
        ],
        elevation: 4,
      ),
      floatingActionButton: _isHost
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SongSelectionScreen(roomId: widget.roomId),
                ));
              },
              label: const Text('Select Song'),
              icon: const Icon(Icons.music_note),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildRoomInfo(),
              const SizedBox(height: 24),
              _buildNowPlaying(),
              const SizedBox(height: 32),
              const Divider(height: 48, thickness: 1.5),
              const Text('Participants',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildParticipantsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomInfo() {
    return Column(
      children: [
        Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text(
                  'Room QR Code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: widget.roomId,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Scan to join or use the ID below:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
          child: SelectableText(
            widget.roomId,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Theme.of(context).colorScheme.primary,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildNowPlaying() {
    // Handle case where _roomStream is null (not initialized yet)
    if (_roomStream == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return StreamBuilder<Map<String, dynamic>>(
      stream: _roomStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final room = snapshot.data!;
        final songName = room['current_song_name'] as String?;
        final isPlaying = room['is_playing'] as bool? ?? false;

        if (songName == null) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.music_off,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No song is playing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a song to start playing',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => NowPlayingSheet(
                  roomId: widget.roomId,
                  isHost: _isHost,
                  songName: songName,
                ),
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPlaying ? Icons.volume_up : Icons.pause,
                        color: isPlaying 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          songName.replaceAll('.mp3', ''),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isPlaying 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.expand_less, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isPlaying)
                    LinearProgressIndicator(
                      value: null, // Indeterminate progress
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantsList() {
    // Handle case where _participantsStream is null (not initialized yet)
    if (_participantsStream == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _participantsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final participantIds =
            snapshot.data!.map((e) => e['profile_id'] as String).toList();
        if (participantIds.isEmpty) {
          return Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No participants yet. Share the room ID or QR code to invite others.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client
              .from('profiles')
              .select('id, username')
              .inFilter('id', participantIds),
          builder: (context, nameSnapshot) {
            if (!nameSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final profiles = nameSnapshot.data!;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: SizedBox(
                height: profiles.length * 70.0,
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isCurrentUser = profile['id'] == _currentUserId;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrentUser
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          color: isCurrentUser ? Colors.white : Colors.grey,
                        ),
                      ),
                      title: Text(
                        profile['username'],
                        style: TextStyle(
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isCurrentUser
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
                                'You',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}