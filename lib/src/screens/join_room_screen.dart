// lib/src/screens/join_room_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_sync/src/screens/jam_room_screen.dart';
import 'package:beat_sync/src/theme/app_theme.dart';
import 'package:beat_sync/src/theme/glass_container.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen>
    with SingleTickerProviderStateMixin {
  final _roomIdController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  // Function to save room to recently joined rooms
  Future<void> _saveToRecentlyJoinedRooms(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final recentlyJoinedRoomsJson =
        prefs.getString('recently_joined_rooms') ?? '[]';
    final List<dynamic> roomIds = jsonDecode(recentlyJoinedRoomsJson);
    final updatedList = List<String>.from(roomIds);

    // Add the room ID to the beginning of the list
    if (!updatedList.contains(roomId)) {
      updatedList.insert(0, roomId);
    } else {
      // Move to the beginning if it already exists
      updatedList.remove(roomId);
      updatedList.insert(0, roomId);
    }

    // Keep only the last 10 rooms
    if (updatedList.length > 10) {
      updatedList.removeRange(10, updatedList.length);
    }

    await prefs.setString('recently_joined_rooms', jsonEncode(updatedList));
  }

  Future<void> _joinRoom(String roomId) async {
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room ID')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    try {
      // Check if room exists first
      final roomData = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('id', roomId)
          .single();

      // Add user to participants if not already a participant
      try {
        await Supabase.instance.client.from('room_participants').upsert({
          'room_id': roomId,
          'profile_id': userId,
        }, onConflict: 'room_id,profile_id');
      } catch (e) {
        // If upsert fails, try insert
        await Supabase.instance.client.from('room_participants').insert({
          'room_id': roomId,
          'profile_id': userId,
        });
      }

      // Save to recently joined rooms
      await _saveToRecentlyJoinedRooms(roomId);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => JamRoomScreen(roomId: roomId)),
      );
    } catch (e) {
      print('Error joining room: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining room: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Join a Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 80),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF1a0529)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                ScaleTransition(
                  scale: _animationController,
                  child: const Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Join a Room',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter a room ID or scan a QR code to join',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 40),

                // Room ID input
                GlassContainer(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Room ID',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _roomIdController,
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter room ID...',
                          prefixIcon: Icon(Icons.meeting_room,
                              color: AppTheme.secondary),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (value) => _joinRoom(value.trim()),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Join button
                ElevatedButton(
                  onPressed: () => _joinRoom(_roomIdController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Join by ID',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Divider(height: 48, color: Colors.white.withOpacity(0.2)),

                const SizedBox(height: 16),

                // QR Scan button
                OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code, size: 24),
                  label: const Text(
                    'Scan QR Code',
                    style: TextStyle(fontSize: 18),
                  ),
                  onPressed: () async {
                    final result = await showModalBottomSheet<String>(
                      context: context,
                      builder: (_) => const QRScanSheet(),
                      isScrollControlled: true,
                      backgroundColor:
                          Colors.transparent, // Transparent for Glass effect
                    );
                    if (result != null) {
                      _roomIdController.text = result;
                      _joinRoom(result);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                    side: const BorderSide(color: AppTheme.secondary),
                    foregroundColor: AppTheme.secondary,
                  ),
                ),

                const SizedBox(height: 24),

                // Info text
                GlassContainer(
                  color: Colors.white.withOpacity(0.02),
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'After joining, you\'ll be able to listen to music synchronized with the host and other participants.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A simple sheet for scanning QR codes
class QRScanSheet extends StatelessWidget {
  const QRScanSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 20,
      opacity: 0.1,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Scan QR Code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                onDetect: (capture) {
                  final code = capture.barcodes.first.rawValue;
                  if (code != null) {
                    Navigator.of(context).pop(code);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
