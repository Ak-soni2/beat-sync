// lib/src/screens/jam_room_screen.dart
import 'dart:async';
import 'package:beat_sync/src/screens/add_song_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:beat_sync/src/services/music_logic_service.dart';
import 'package:beat_sync/src/theme/app_theme.dart';
import 'package:beat_sync/src/theme/glass_container.dart';

class JamRoomScreen extends StatefulWidget {
  final String roomId;
  const JamRoomScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<JamRoomScreen> createState() => _JamRoomScreenState();
}

class _JamRoomScreenState extends State<JamRoomScreen> {
  final MusicLogicService _musicService = MusicLogicService();
  bool _isHost = false;
  String _currentUserId = '';
  bool _isInitialized = false;

  Set<String> _currentParticipantIds = {};
  int _participantCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();

    // Listen for Room Closure (Kill Room)
    _musicService.roomClosedStream.listen((_) {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("The room has been closed.")));
      }
      _musicService.dispose();
    });
  }

  void _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ?? '';

    final roomData = await Supabase.instance.client
        .from('rooms')
        .select()
        .eq('id', widget.roomId)
        .single();

    // Check Host
    _isHost = roomData['host_id'] == _currentUserId;

    // Init Logic Service
    await _musicService.init(widget.roomId, _currentUserId);

    // Setup Participant Listener
    _setupParticipantSubscription();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _setupParticipantSubscription() {
    Supabase.instance.client
        .from('room_participants')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .listen((data) {
          final newIds = data.map((e) => e['profile_id'] as String).toSet();

          // Logic to detect changes (skip initial load or if empty)
          if (_currentParticipantIds.isNotEmpty) {
            final joined = newIds.difference(_currentParticipantIds);
            final left = _currentParticipantIds.difference(newIds);

            for (var id in joined) _showParticipantToast(id, true);
            for (var id in left) _showParticipantToast(id, false);
          }

          if (mounted) {
            setState(() {
              _currentParticipantIds = newIds;
              _participantCount = newIds.length;
            });
          }
        });
  }

  Future<void> _showParticipantToast(String userId, bool joined) async {
    // Fetch name for better UX
    String name = 'User';
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();
      if (res != null) name = res['username'];
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name ${joined ? "joined" : "left"} the room'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _killRoom() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text("Destroy Room?"),
              content: const Text(
                  "This will kick everyone out and delete the room data."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel")),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("DESTROY"),
                ),
              ],
            ));

    if (confirm == true) {
      await _musicService.killRoom();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zero-Lag Jam'),
            Text('$_participantCount jamming',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white),
            onPressed: _showQrCode,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'finalize') _finalizePlaylist();
              if (value == 'participants') _showParticipantsList();
              if (value == 'copy_id') {
                await Clipboard.setData(ClipboardData(text: widget.roomId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Room ID copied!")));
                }
              }
              if (value == 'kill') _killRoom();
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                    value: 'copy_id', child: Text('Copy Room ID')),
                const PopupMenuItem(
                    value: 'participants', child: Text('Who is here?')),
                if (_isHost) ...[
                  const PopupMenuItem(
                      value: 'finalize', child: Text('Finalize Playlist')),
                  const PopupMenuItem(
                      value: 'kill',
                      child: Text('Kill Room',
                          style: TextStyle(color: Colors.red))),
                ]
              ];
            },
          ),
        ],
      ),
      floatingActionButton: _isHost
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AddSongScreen(roomCode: widget.roomId),
                ));
              },
              label: const Text('Add Song'),
              icon: const Icon(Icons.add),
              backgroundColor: AppTheme.primary,
            )
          : null,
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
            // Now Playing Area
            AnimatedBuilder(
              animation: _musicService,
              builder: (context, _) {
                return _buildNowPlaying();
              },
            ),
            const Divider(color: Colors.white24),
            Expanded(child: _buildPlaylist()),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlaying() {
    // 1. Preparing State (Overlay)
    if (_musicService.status == RoomStatus.preparing) {
      return StreamBuilder<String>(
          stream: _musicService.progressStream,
          initialData: "Initializing...",
          builder: (context, snapshot) {
            return GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(snapshot.data ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          });
    }

    // 2. Ready State (Host Start Button)
    if (_musicService.status == RoomStatus.ready) {
      return GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("All Devices Ready!",
                style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isHost)
              ElevatedButton.icon(
                onPressed: () => _musicService.hostStartSession(),
                icon: const Icon(Icons.play_arrow),
                label: const Text("START SESSION"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16)),
              )
            else
              const Text("Waiting for Host to start...",
                  style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    // 3. Play/Open State
    return GlassContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text("Now Playing", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchCurrentSongMetadata(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Text(
                  snapshot.data!['title'] ?? 'Unknown Title',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                );
              }
              return const Text("Waiting for track...",
                  style: TextStyle(color: Colors.white));
            },
          ),
          const SizedBox(height: 20),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 64,
                icon: Icon(
                  _musicService.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: AppTheme.secondary,
                ),
                onPressed: _isHost ? _togglePlay : null,
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchCurrentSongMetadata() async {
    if (_musicService.currentSongIndex < 0) return null;
    final data = await Supabase.instance.client
        .from('playlist')
        .select('title')
        .eq('room_id', widget.roomId)
        .eq('song_order', _musicService.currentSongIndex)
        .maybeSingle();
    return data;
  }

  void _togglePlay() {
    _musicService.updatePlayState(!_musicService.isPlaying);
  }

  Widget _buildPlaylist() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('playlist')
          .stream(primaryKey: ['id'])
          .eq('room_id', widget.roomId)
          .order('song_order', ascending: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final songs = snapshot.data!;
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isPlaying =
                song['song_order'] == _musicService.currentSongIndex;
            return ListTile(
              leading: Text('${song['song_order'] + 1}',
                  style: const TextStyle(color: Colors.white54)),
              title: Text(song['title'],
                  style: TextStyle(
                      color: isPlaying ? AppTheme.secondary : Colors.white,
                      fontWeight:
                          isPlaying ? FontWeight.bold : FontWeight.normal)),
              trailing: isPlaying
                  ? const Icon(Icons.equalizer, color: AppTheme.secondary)
                  : null,
            );
          },
        );
      },
    );
  }

  void _showQrCode() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Scan to Join",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                  data: widget.roomId, backgroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showParticipantsList() {
    showModalBottomSheet(
        context: context,
        builder: (_) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Participants",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                      itemCount: _currentParticipantIds.length,
                      itemBuilder: (_, index) {
                        String id = _currentParticipantIds.elementAt(index);
                        return FutureBuilder(
                            future: Supabase.instance.client
                                .from('profiles')
                                .select('username')
                                .eq('id', id)
                                .maybeSingle(),
                            builder: (_, snap) {
                              String name = snap.data?['username'] ?? 'User';
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(name),
                              );
                            });
                      }),
                )
              ],
            ),
          );
        });
  }

  Future<void> _finalizePlaylist() async {
    // Trigger Smart Sync
    try {
      await _musicService.hostPrepareRoom();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Locking Room & Starting Cache...")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
