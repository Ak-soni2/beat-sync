// lib/src/screens/home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beat_sync/src/screens/create_room_screen.dart';
import 'package:beat_sync/src/screens/join_room_screen.dart';
import 'package:beat_sync/src/screens/jam_room_screen.dart';
import 'package:beat_sync/src/theme/app_theme.dart';
import 'package:beat_sync/src/theme/glass_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Future<List<Map<String, dynamic>>>? _hostedRoomsFuture;
  List<String> _recentlyJoinedRoomIds = [];
  // Future for fetching full data of recently joined rooms
  Future<List<Map<String, dynamic>>>? _recentlyJoinedRoomsFuture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true); // For pulsing animations
    _loadRecentlyJoinedRooms();
    _loadRooms();
  }

  Future<void> _loadRecentlyJoinedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final recentlyJoinedRoomsJson =
        prefs.getString('recently_joined_rooms') ?? '[]';
    final List<dynamic> roomIds = jsonDecode(recentlyJoinedRoomsJson);
    setState(() {
      _recentlyJoinedRoomIds = List<String>.from(roomIds);
      // Fetch full data for the recently joined rooms
      _loadRecentlyJoinedRoomsData();
    });
  }

  // Fetches full room data (id, name) for the UI
  void _loadRecentlyJoinedRoomsData() {
    if (_recentlyJoinedRoomIds.isEmpty) {
      setState(() {
        _recentlyJoinedRoomsFuture = Future.value([]); // Return an empty future
      });
      return;
    }
    setState(() {
      _recentlyJoinedRoomsFuture = Supabase.instance.client
          .from('rooms')
          .select('id, name')
          .inFilter('id', _recentlyJoinedRoomIds);
    });
  }

  Future<void> _saveRecentlyJoinedRoom(String roomId) async {
    final updatedList = List<String>.from(_recentlyJoinedRoomIds);

    // Remove if exists, then add to the front to mark it as most recent
    updatedList.remove(roomId);
    updatedList.insert(0, roomId);

    // Keep only the last 10 rooms
    final uniqueList = updatedList.take(10).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recently_joined_rooms', jsonEncode(uniqueList));
    setState(() {
      _recentlyJoinedRoomIds = uniqueList;
      // Refresh the room data when the list changes
      _loadRecentlyJoinedRoomsData();
    });
  }

  Future<void> _removeRecentlyJoinedRoom(String roomId) async {
    final updatedList = List<String>.from(_recentlyJoinedRoomIds);
    updatedList.remove(roomId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recently_joined_rooms', jsonEncode(updatedList));
    setState(() {
      _recentlyJoinedRoomIds = updatedList;
      // Refresh the room data when the list changes
      _loadRecentlyJoinedRoomsData();
    });
  }

  Future<void> _loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId != null) {
      setState(() {
        _hostedRoomsFuture = Supabase.instance.client
            .from('rooms')
            .select()
            .eq('host_id', userId);
      });
    }
    // Refresh recently joined rooms data as well
    _loadRecentlyJoinedRoomsData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.background, Color(0xFF1a0529)],
        )),
        child: CustomScrollView(
          // For smooth scrolling
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'BeatSync',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.background],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter),
                      ),
                    ),
                    Center(
                      child: ScaleTransition(
                        scale: _animationController,
                        child: Icon(Icons.music_note,
                            size: 100, color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedScale(
                            scale: 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_box),
                              label: const Text('Create Room'),
                              onPressed: () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateRoomScreen()));
                                _loadRooms();
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Join Room'),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const JoinRoomScreen()));
                              _loadRooms();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondary,
                                foregroundColor: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Hosted Rooms',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    _buildHostedRoomsList(),
                    const SizedBox(height: 32),
                    Text('Recently Joined Rooms',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    _buildRecentlyJoinedRoomsList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostedRoomsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _hostedRoomsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return GlassContainer(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'You haven\'t created any rooms yet. Tap "Create Room" to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
        final rooms = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GlassContainer(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    child: const Icon(Icons.key, color: AppTheme.primary),
                  ),
                  title: Text(
                    room['name'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                  subtitle: Text('ID: ${room['id']}',
                      style: TextStyle(color: Colors.white.withOpacity(0.6))),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: AppTheme.primary),
                  onTap: () => _handleRoomTap(room['id'], isHost: true),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentlyJoinedRoomsList() {
    if (_recentlyJoinedRoomIds.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          'No recently joined rooms. Join a room to see it here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _recentlyJoinedRoomsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load rooms.'));
        }

        final rooms = snapshot.data!;

        final orderedRooms = <Map<String, dynamic>>[];
        for (final id in _recentlyJoinedRoomIds) {
          final room = rooms.firstWhere((r) => r['id'] == id, orElse: () => {});
          if (room.isNotEmpty) {
            orderedRooms.add(room);
          }
        }

        return SizedBox(
          height: 200, // Increased height for better layout
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: orderedRooms.length,
            itemBuilder: (context, index) {
              final room = orderedRooms[index];
              final roomId = room['id'] as String;
              final roomName = room['name'] as String;

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GlassContainer(
                  width: 160,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.room,
                          size: 30,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        roomName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.login,
                                size: 20, color: AppTheme.primary),
                            onPressed: () =>
                                _handleRoomTap(roomId, isHost: false),
                            tooltip: 'Join Room',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 20, color: Colors.grey),
                            onPressed: () => _removeRecentlyJoinedRoom(roomId),
                            tooltip: 'Remove from List',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleRoomTap(String roomId, {required bool isHost}) async {
    if (!isHost) {
      final roomResponse = await Supabase.instance.client
          .from('rooms')
          .select('id')
          .eq('id', roomId)
          .maybeSingle();

      if (roomResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('This room has been ended by the host.')),
          );
        }
        _loadRooms();
        _removeRecentlyJoinedRoom(roomId);
        return;
      }

      await _saveRecentlyJoinedRoom(roomId);
    }

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => JamRoomScreen(roomId: roomId)),
      );
      _loadRooms();
    }
  }
}
