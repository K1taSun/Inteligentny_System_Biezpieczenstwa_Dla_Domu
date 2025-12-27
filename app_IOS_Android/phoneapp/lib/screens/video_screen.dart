import 'package:flutter/material.dart';
import 'package:phoneapp/theme/app_theme.dart';
import 'package:phoneapp/utils/responsive.dart';
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
    Responsive.init(context);
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VideoHero(camera: _entryCamera),
          SizedBox(height: Responsive.padding(16)),
          _buildVideoPlayer(_entryCamera),
          SizedBox(height: Responsive.height(110)),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(_Camera camera) {
    final isSmall = Responsive.isSmallDevice;
    final containerRadius = Responsive.radius(28);
    final minHeight = Responsive.height(isSmall ? 200 : 240);
    
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: minHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(containerRadius),
              color: AppColors.navy,
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(containerRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: Responsive.sp(30),
                offset: Offset(0, Responsive.sp(18)),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(containerRadius),
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
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final isSmall = Responsive.isSmallDevice;
    
    // Responsywne wartości
    final cardPadding = Responsive.padding(isSmall ? 16 : 22);
    final cardRadius = Responsive.radius(26);
    final iconContainerPadding = Responsive.padding(isSmall ? 10 : 12);
    final iconContainerRadius = Responsive.radius(18);
    final iconSize = Responsive.iconSize(isSmall ? 26 : 32);
    final spacing = Responsive.padding(isSmall ? 12 : 16);
    
    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsywny układ nagłówka
          LayoutBuilder(
            builder: (context, constraints) {
              // Dla bardzo małych ekranów - układ pionowy
              if (Responsive.screenSize == ScreenSize.extraSmall) {
                return _buildCompactHeader(context, theme, isSmall, iconContainerPadding, iconContainerRadius, iconSize);
              }
              
              return _buildFullHeader(context, theme, isSmall, iconContainerPadding, iconContainerRadius, iconSize, spacing);
            },
          ),
          SizedBox(height: Responsive.padding(isSmall ? 16 : 20)),
          Text(
            'Steruj kamerą w czasie rzeczywistym, uruchamiaj scenariusze i przeglądaj historię nagrań.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
              fontSize: Responsive.fontSize(isSmall ? 13 : 16),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactHeader(
    BuildContext context,
    ThemeData theme,
    bool isSmall,
    double iconContainerPadding,
    double iconContainerRadius,
    double iconSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(iconContainerPadding),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(iconContainerRadius),
              ),
              child: Icon(Icons.videocam_rounded, color: Colors.white, size: iconSize),
            ),
            const Spacer(),
            _buildLiveBadge(isSmall),
          ],
        ),
        SizedBox(height: Responsive.padding(12)),
        Text(
          camera.name,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: Responsive.fontSize(18),
          ),
        ),
        SizedBox(height: Responsive.padding(4)),
        Text(
          camera.location,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            fontSize: Responsive.fontSize(13),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFullHeader(
    BuildContext context,
    ThemeData theme,
    bool isSmall,
    double iconContainerPadding,
    double iconContainerRadius,
    double iconSize,
    double spacing,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(iconContainerPadding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(iconContainerRadius),
          ),
          child: Icon(Icons.videocam_rounded, color: Colors.white, size: iconSize),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                camera.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.fontSize(isSmall ? 18 : 22),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: Responsive.padding(2)),
              Text(
                camera.location,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontSize: Responsive.fontSize(isSmall ? 13 : 14),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: Responsive.padding(8)),
        _buildLiveBadge(isSmall),
      ],
    );
  }
  
  Widget _buildLiveBadge(bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(isSmall ? 12 : 16),
        vertical: Responsive.padding(isSmall ? 6 : 8),
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(Responsive.radius(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: Responsive.iconSize(isSmall ? 8 : 10),
            color: Colors.redAccent,
          ),
          SizedBox(width: Responsive.padding(6)),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: Responsive.fontSize(isSmall ? 11 : 13),
              fontWeight: FontWeight.w600,
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
    Responsive.init(context);
    
    final isSmall = Responsive.isSmallDevice;
    final overlayPadding = Responsive.padding(isSmall ? 14 : 20);
    
    return Container(
      padding: EdgeInsets.all(overlayPadding),
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
          SizedBox(width: Responsive.padding(isSmall ? 8 : 10)),
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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.fontSize(isSmall ? 12 : 14),
                ),
              ),
              SizedBox(height: Responsive.padding(isSmall ? 4 : 6)),
              Text(
                camera.location,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: Responsive.fontSize(isSmall ? 11 : 13),
                ),
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
    Responsive.init(context);
    
    final isSmall = Responsive.isSmallDevice;
    final buttonPadding = Responsive.padding(isSmall ? 10 : 12);
    final buttonRadius = Responsive.radius(16);
    final iconSize = Responsive.iconSize(isSmall ? 20 : 24);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(buttonPadding),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(buttonRadius),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
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
