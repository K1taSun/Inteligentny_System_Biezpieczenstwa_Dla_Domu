import 'package:flutter/material.dart';
import 'package:phoneapp/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _isMuted = false;
  final _Camera _entryCamera = const _Camera(
    name: 'Wejście główne',
    location: 'Front domu',
    status: 'LIVE 4K',
    streamUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
  );

  @override
  void initState() {
    super.initState();
    _initializeController(_entryCamera.streamUrl);
  }

  void _initializeController(String url) {
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _initializeVideoPlayerFuture = _controller.initialize();
    _controller
      ..setLooping(true)
      ..setVolume(_isMuted ? 0 : 1)
      ..play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VideoHero(camera: _entryCamera),
          const SizedBox(height: 16),
          _buildVideoPlayer(_entryCamera),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(_Camera camera) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: AppColors.navy,
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                _VideoOverlay(
                  camera: camera,
                  isMuted: _isMuted,
                  isPlaying: _controller.value.isPlaying,
                  onToggleMute: _toggleMute,
                  onTogglePlayback: _togglePlayback,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VideoHero extends StatelessWidget {
  const _VideoHero({required this.camera});

  final _Camera camera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      camera.location,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.circle, size: 10, color: Colors.redAccent),
                    SizedBox(width: 6),
                    Text('LIVE', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Steruj kamerą w czasie rzeczywistym, uruchamiaj scenariusze i przeglądaj historię nagrań.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoOverlay extends StatelessWidget {
  const _VideoOverlay({
    required this.camera,
    required this.isMuted,
    required this.isPlaying,
    required this.onToggleMute,
    required this.onTogglePlayback,
  });

  final _Camera camera;
  final bool isMuted;
  final bool isPlaying;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black87],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          _OverlayButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            onTap: onTogglePlayback,
          ),
          const SizedBox(width: 10),
          _OverlayButton(
            icon: isMuted ? Icons.volume_off : Icons.volume_up,
            onTap: onToggleMute,
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                camera.status,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                camera.location,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _Camera {
  const _Camera({
    required this.name,
    required this.location,
    required this.status,
    required this.streamUrl,
  });

  final String name;
  final String location;
  final String status;
  final String streamUrl;
}


