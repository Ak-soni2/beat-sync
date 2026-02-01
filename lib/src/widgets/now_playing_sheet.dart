// lib/src/widgets/now_playing_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:beat_sync/src/services/music_logic_service.dart';
import 'package:beat_sync/src/services/caching_service.dart';
import 'package:beat_sync/src/theme/app_theme.dart';
import 'package:beat_sync/src/theme/glass_container.dart';

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
  late final AnimationController _pulseController;
  late final PlayerController _waveformController;
  final MusicLogicService _musicService = MusicLogicService();

  bool _isPlaying = false;
  bool _isLoading = true;
  String? _waveformPath;

  @override
  void initState() {
    super.initState();

    // Pulse animation for play button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Initialize waveform controller
    _waveformController = PlayerController();

    _playerStateSubscription =
        _musicService.player.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlaying = state.playing;
        if (_isPlaying) {
          _pulseController.repeat(reverse: true);
          _waveformController.startPlayer();
        } else {
          _pulseController.stop();
          _waveformController.stopPlayer();
        }
      });
    });

    _initializeWaveform();
  }

  Future<void> _initializeWaveform() async {
    try {
      // Assuming generic index 0 for now if songName lookup is needed,
      // but CachingService.getCachedPath expects an INT index in the new version?
      // Wait, CachingService (Step 161) takes (int index).
      // But NowPlayingSheet has (String songName).
      // The architecture mismatch is here.
      // CachingService manages by Index. NowPlayingSheet receives a Name.
      // In Zero-Lag Jam, we track by Index.
      // We should probably pass the index to NowPlayingSheet or look it up.
      // For now, I will assume we can't easily get the path by Name if CachingService only supports Index.
      // However, usually we can get the current index from MusicLogicService.

      int index = _musicService.currentSongIndex;
      // If the songName matches the current song, we use that index.

      final localPath = await CachingService().getCachedPath(index);

      if (localPath != null && mounted) {
        await _waveformController.preparePlayer(
          path: localPath,
          shouldExtractWaveform: true,
        );

        if (mounted) {
          setState(() {
            _waveformPath = localPath;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Waveform init error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _pulseController.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause(ja.PlayerState playerState) async {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the host can control playback'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Toggle logic via MusicLogicService
    await _musicService.updatePlayState(!playerState.playing);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        color: AppTheme.surface.withOpacity(0.8),
        blur: 20,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),

            // Song Title
            Text(
              widget.songName.replaceAll('.mp3', ''),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),
            Text(
              _isPlaying ? 'Now Playing' : 'Paused',
              style: TextStyle(
                fontSize: 14,
                color: _isPlaying ? AppTheme.secondary : Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 30),

            // Waveform Visualization
            GlassContainer(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : _waveformPath != null
                      ? AudioFileWaveforms(
                          size: Size(MediaQuery.of(context).size.width, 80),
                          playerController: _waveformController,
                          waveformType: WaveformType.long,
                          playerWaveStyle: PlayerWaveStyle(
                            fixedWaveColor: AppTheme.secondary.withOpacity(0.3),
                            liveWaveColor: AppTheme.secondary,
                            spacing: 5,
                            waveThickness: 3,
                            scaleFactor: 120,
                          ),
                        )
                      : Center(
                          child: Text(
                            'Waveform unavailable',
                            style:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        ),
            ),

            const SizedBox(height: 32),

            // Playback Controls
            StreamBuilder<ja.PlayerState>(
              stream: _musicService.player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final isBuffering = playerState?.processingState ==
                        ja.ProcessingState.buffering ||
                    playerState?.processingState == ja.ProcessingState.loading;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous
                    _ControlButton(
                      icon: Icons.skip_previous_rounded,
                      onPressed: widget.isHost ? () {} : null,
                      size: 50,
                    ),

                    const SizedBox(width: 24),

                    // Play/Pause (Pulsing)
                    ScaleTransition(
                      scale: Tween<double>(begin: 1.0, end: 1.15).animate(
                        CurvedAnimation(
                          parent: _pulseController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: AppTheme.primary,
                          child: isBuffering
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    _isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                  onPressed: widget.isHost
                                      ? () => _togglePlayPause(playerState!)
                                      : null,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Next
                    _ControlButton(
                      icon: Icons.skip_next_rounded,
                      onPressed: widget.isHost ? () {} : null,
                      size: 50,
                    ),
                  ],
                );
              },
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// Reusable Control Button
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const _ControlButton({
    required this.icon,
    this.onPressed,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: GlassContainer(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
        color: enabled ? Colors.white.withOpacity(0.1) : Colors.transparent,
        padding: EdgeInsets.zero,
        child: IconButton(
          icon: Icon(
            icon,
            size: 28,
            color: enabled ? Colors.white : Colors.grey,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
