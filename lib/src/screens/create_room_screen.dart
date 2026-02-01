// lib/src/screens/create_room_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_sync/src/screens/jam_room_screen.dart';
import 'package:beat_sync/src/theme/app_theme.dart';
import 'package:beat_sync/src/theme/glass_container.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen>
    with SingleTickerProviderStateMixin {
  final _roomNameController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);
    final roomName = _roomNameController.text.trim();
    if (roomName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    try {
      // 1. Create the room and get its ID
      final room = await Supabase.instance.client
          .from('rooms')
          .insert({'name': roomName, 'host_id': userId})
          .select()
          .single();

      final roomId = room['id'];

      // 2. Add the host as the first participant
      await Supabase.instance.client.from('room_participants').insert({
        'room_id': roomId,
        'profile_id': userId,
      });

      if (!mounted) return;
      // Navigate to the Room Screen, replacing the creation screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => JamRoomScreen(roomId: roomId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating room: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create a Room'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        padding: const EdgeInsets.only(
            top: 80), // compensate for extendBodyBehindAppBar
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF1a0529)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with icon
              ScaleTransition(
                scale: _animationController,
                child: const Icon(
                  Icons.music_note,
                  size: 64,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create a New Room',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a name for your music room and start syncing with friends',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),

              const SizedBox(height: 40),

              // Room name input with enhanced styling
              GlassContainer(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Room Name',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _roomNameController,
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter room name...',
                        prefixIcon:
                            Icon(Icons.meeting_room, color: AppTheme.secondary),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _createRoom(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Create button with enhanced styling
              ElevatedButton(
                onPressed: _isLoading ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Creating Room...',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_box, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Create and Join Room',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              // Info text
              GlassContainer(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white.withOpacity(0.02),
                child: Text(
                  'As the host, you\'ll be able to select songs and control playback for all participants in the room.',
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
    );
  }
}
