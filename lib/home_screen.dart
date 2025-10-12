// lib/home_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beat_sync/create_room_screen.dart';
import 'package:beat_sync/join_room_screen.dart';
import 'package:beat_sync/room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Map<String, dynamic>>>? _hostedRoomsFuture;
  List<String> _recentlyJoinedRoomIds = [];

  @override
  void initState() {
    super.initState();
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
    });
  }

  Future<void> _saveRecentlyJoinedRoom(String roomId) async {
    // Add the room ID to the beginning of the list
    final updatedList = [_recentlyJoinedRoomIds, roomId]
        .expand((x) => x is Iterable ? x : [x])
        .toList();

    // Remove duplicates while preserving order
    final uniqueList = <String>[];
    for (final id in updatedList) {
      if (!uniqueList.contains(id)) {
        uniqueList.add(id);
      }
    }

    // Keep only the last 10 rooms
    if (uniqueList.length > 10) {
      uniqueList.removeRange(10, uniqueList.length);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recently_joined_rooms', jsonEncode(uniqueList));
    setState(() {
      _recentlyJoinedRoomIds = uniqueList;
    });
  }

  Future<void> _removeRecentlyJoinedRoom(String roomId) async {
    final updatedList = List<String>.from(_recentlyJoinedRoomIds);
    updatedList.remove(roomId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recently_joined_rooms', jsonEncode(updatedList));
    setState(() {
      _recentlyJoinedRoomIds = updatedList;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BeatSync'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            // Mobile layout
            return _buildMobileLayout();
          } else {
            // Tablet/Desktop layout
            return _buildTabletLayout();
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome section with app title
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'BeatSync',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sync your music with friends in real-time',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_box),
                  label: const Text('Create Room'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CreateRoomScreen()));
                    _loadRooms(); // Refresh when returning
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Join Room'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const JoinRoomScreen()));
                    _loadRooms(); // Refresh when returning
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Hosted Rooms section
          const Text(
            'Hosted Rooms',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: _buildHostedRoomsList(),
          ),

          const SizedBox(height: 32),

          // Recently Joined Rooms section
          const Text(
            'Recently Joined Rooms',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: _buildRecentlyJoinedRoomsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome section with app title
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BeatSync',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sync your music with friends in real-time',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_box, size: 28),
                  label: const Text(
                    'Create a New Room',
                    style: TextStyle(fontSize: 18),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CreateRoomScreen()));
                    _loadRooms(); // Refresh when returning
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text(
                    'Join a Room',
                    style: TextStyle(fontSize: 18),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const JoinRoomScreen()));
                    _loadRooms(); // Refresh when returning
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Hosted Rooms section
          const Text(
            'Hosted Rooms',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            flex: 1,
            child: _buildHostedRoomsList(),
          ),

          const SizedBox(height: 40),

          // Recently Joined Rooms section
          const Text(
            'Recently Joined Rooms',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            flex: 1,
            child: _buildRecentlyJoinedRoomsList(),
          ),
        ],
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
          return Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'You haven\'t created any rooms yet. Tap "Create Room" to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }
        final rooms = snapshot.data!;
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.key,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  room['name'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text('ID: ${room['id']}'),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () => _handleRoomTap(room['id'], isHost: true),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecentlyJoinedRoomsList() {
    if (_recentlyJoinedRoomIds.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No recently joined rooms. Join a room to see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _recentlyJoinedRoomIds.length,
          itemBuilder: (context, index) {
            final roomId = _recentlyJoinedRoomIds[index];
            return Card(
              margin: const EdgeInsets.all(12.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.room,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      roomId.substring(
                              0, roomId.length > 10 ? 10 : roomId.length) +
                          (roomId.length > 10 ? '...' : ''),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.login, size: 20),
                          onPressed: () =>
                              _handleRoomTap(roomId, isHost: false),
                          tooltip: 'Join Room',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
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
      ),
    );
  }

  // ✅ NEW: Logic to handle tapping on a room, with a check for rejoining
  Future<void> _handleRoomTap(String roomId, {required bool isHost}) async {
    if (!isHost) {
      // For listeners, check if the room still exists before trying to join
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
        _loadRooms(); // Refresh the list to remove the ended room
        _removeRecentlyJoinedRoom(roomId); // Remove from recently joined
        return;
      }

      // Save to recently joined rooms
      await _saveRecentlyJoinedRoom(roomId);
    }

    // If the room exists or if the user is the host, navigate to the screen
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomScreen(roomId: roomId)),
      );
      _loadRooms(); // Always refresh after returning from a room screen
    }
  }
}
