// lib/now_playing_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:beat_sync/audio_player_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NowPlayingSheet extends StatefulWidget {
  final String roomId;
  final bool isHost;
  final String songName;

  const NowPlayingSheet({
    Key? key,
    required this.roomId,
    required this.isHost,
    required this.songName,
  }) : super(key: key);

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<NowPlayingSheet>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<ja.PlayerState> _playerStateSubscription;
  late final AnimationController _animationController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    // Animation controller for waveform animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    // Listen to the audio player's state to control the play/pause button
    _playerStateSubscription =
        AudioPlayerService.instance.player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (_isPlaying) {
            _animationController.repeat();
          } else {
            _animationController.stop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause(ja.PlayerState playerState) async {
    // Only hosts can control playback
    if (!widget.isHost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the host can control playback'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final player = AudioPlayerService.instance.player;
    final isPlaying = playerState.playing;

    if (isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }

    await Supabase.instance.client
        .from('rooms')
        .update({'is_playing': !isPlaying}).eq('id', widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 320, // Reduced height to prevent overflow
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Song title with better styling
          Text(
            widget.songName.replaceAll('.mp3', ''),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),

          // Enhanced waveform visualization
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 90.0, // Reduced height
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CustomPaint(
              painter: AnimatedWaveformPainter(_isPlaying, _animationController),
            ),
          ),

          const SizedBox(height: 16),

          // Enhanced player controls
          StreamBuilder<ja.PlayerState>(
            stream: AudioPlayerService.instance.player.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final processingState = playerState?.processingState;
              final isPlaying = playerState?.playing ?? false;

              if (processingState == ja.ProcessingState.loading ||
                  processingState == ja.ProcessingState.buffering) {
                return const CircularProgressIndicator();
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous button (placeholder) - only for host
                  IconButton(
                    icon: Icon(
                      Icons.skip_previous,
                      color: widget.isHost 
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.grey,
                      size: 36, // Reduced size
                    ),
                    onPressed: widget.isHost ? () {} : null,
                  ),
                  
                  const SizedBox(width: 16),

                  // Play/Pause button with better styling
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 30, // Reduced radius
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.white,
                          size: 45, // Reduced size
                        ),
                        onPressed: widget.isHost
                            ? () => _togglePlayPause(playerState!)
                            : () {
                                // Show message to listeners that they can't control playback
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Only the host can control playback'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),

                  // Next button (placeholder) - only for host
                  IconButton(
                    icon: Icon(
                      Icons.skip_next,
                      color: widget.isHost 
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.grey,
                      size: 36, // Reduced size
                    ),
                    onPressed: widget.isHost ? () {} : null,
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 4),
          
          // Progress indicator text
          Text(
            _isPlaying ? 'Now Playing' : 'Paused',
            style: TextStyle(
              color: _isPlaying 
                  ? Theme.of(context).colorScheme.primary 
                  : Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 14, // Reduced font size
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced animated waveform painter
class AnimatedWaveformPainter extends CustomPainter {
  final bool isPlaying;
  final AnimationController animationController;
  final Paint _paint;

  AnimatedWaveformPainter(this.isPlaying, this.animationController)
      : _paint = Paint()
          ..style = PaintingStyle.fill,
        super(repaint: animationController);

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = 4.0;
    final double spacing = 3.0;
    final int barCount = (size.width / (barWidth + spacing)).floor();
    
    final double centerY = size.height / 2;
    final double maxHeight = size.height * 0.7;
    
    for (int i = 0; i < barCount; i++) {
      // Calculate animation progress
      final double animationValue = isPlaying 
          ? (animationController.value + i * 0.05) % 1.0 
          : 0.3;
      
      // Create animated effect when playing
      final double baseHeight = maxHeight * 0.3;
      final double animatedHeight = isPlaying
          ? baseHeight + (maxHeight * 0.7 * animationValue)
          : baseHeight;
      
      // Set color based on position and state
      final double hue = (i / barCount) * 360;
      _paint.color = isPlaying
          ? HSLColor.fromAHSL(1.0, hue, 0.8, 0.6).toColor()
          : Colors.grey[600]!;
      
      final double x = i * (barWidth + spacing);
      final double top = centerY - animatedHeight / 2;
      final double bottom = centerY + animatedHeight / 2;
      
      // Draw rounded rectangles for better visual appeal
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, animatedHeight),
          Radius.circular(barWidth / 2),
        ),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}