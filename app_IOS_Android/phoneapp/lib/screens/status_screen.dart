import 'package:flutter/material.dart';
import 'package:phoneapp/screens/main_shell.dart';
import 'package:phoneapp/theme/app_theme.dart';
import 'package:phoneapp/utils/responsive.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'dart:convert';
import 'dart:async';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  bool _isArmed = false;
  bool _isLoading = false;
  double _temperature = 0.0;
  double _humidity = 0.0;
  final GoogleAuthService _authService = GoogleAuthService();
  
  // Nazwa pliku do sterowania
  static const String _remoteFileName = 'remote_status.json';

  final List<_SecurityEvent> _events = const [
    _SecurityEvent(
      title: 'Ruch wykryty - Salon',
      time: '2 min temu',
      type: EventType.warning,
      icon: Icons.directions_run,
    ),
    _SecurityEvent(
      title: 'Nagranie zapisane - Kamera 2',
      time: '45 min temu',
      type: EventType.neutral,
      icon: Icons.videocam,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Nasłuchuj zmian autoryzacji
    _authService.addListener(_onAuthChanged);
    // Jeśli już połączony, sprawdź status
    if (_authService.isConnected) {
      _fetchRemoteStatus();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      if (_authService.isConnected) {
        _fetchRemoteStatus();
      } else {
        setState(() => _isArmed = false);
      }
    }
  }

  Future<void> _fetchRemoteStatus() async {
    if (!_authService.isConnected || _authService.driveApi == null) return;

    setState(() => _isLoading = true);

    try {
      final driveApi = _authService.driveApi!;
      
      // Szukaj pliku
      final fileList = await driveApi.files.list(
        q: "name = '$_remoteFileName' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        
        // Pobierz zawartość
        final media = await driveApi.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;

        final stream = media.stream;
        final content = await utf8.decodeStream(stream);
        final data = jsonDecode(content);

        if (mounted && data['armed'] != null) {
          setState(() {
            _isArmed = data['armed'];
            if (data['temp'] != null) _temperature = (data['temp'] as num).toDouble();
            if (data['humidity'] != null) _humidity = (data['humidity'] as num).toDouble();
            _isLoading = false;
          });
        }
      } else {
        // Plik nie istnieje - domyślnie rozbrojony
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching status: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAlarm() async {
    if (!_authService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zaloguj się do chmury (ikona w rogu), aby sterować alarmem.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newState = !_isArmed;
    
    // Optymistyczna aktualizacja UI
    setState(() {
      _isArmed = newState;
      _isLoading = true;
    });

    try {
      final driveApi = _authService.driveApi!;
      
      // Przygotuj JSON
      final content = jsonEncode({'armed': newState, 'timestamp': DateTime.now().toIso8601String()});
      final media = drive.Media(
        Stream.value(utf8.encode(content)),
        utf8.encode(content).length,
      );

      // Sprawdź czy plik istnieje
      final fileList = await driveApi.files.list(
        q: "name = '$_remoteFileName' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Aktualizuj istniejący
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(
          drive.File(),
          fileId,
          uploadMedia: media,
        );
      } else {
        // Utwórz nowy
        await driveApi.files.create(
          drive.File(name: _remoteFileName, parents: []), // Root folder
          uploadMedia: media,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newState ? 'Wysłano komendę UZBROJENIA' : 'Wysłano komendę ROZBROJENIA'),
            backgroundColor: newState ? AppColors.accent : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling alarm: $e');
      // Cofnij zmianę w razie błędu
      if (mounted) {
        setState(() {
          _isArmed = !newState;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Błąd komunikacji z chmurą!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final statusColor = _isArmed ? AppColors.accent : AppColors.warning;
    
    // Responsywne wartości
    final sectionSpacing = Responsive.padding(24);
    final smallSpacing = Responsive.padding(12);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(
            isArmed: _isArmed,
            statusColor: statusColor,
            onToggle: _toggleAlarm,
            isLoading: _isLoading,
            isConnected: _authService.isConnected,
          ),
          SizedBox(height: sectionSpacing),
          Text(
            'Szybkie dane',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: Responsive.fontSize(16),
            ),
          ),
          SizedBox(height: smallSpacing),
          // Responsywny układ kart statystyk
          LayoutBuilder(
            builder: (context, constraints) {
              // Dla bardzo małych ekranów - karty pionowo
              if (Responsive.screenSize == ScreenSize.extraSmall) {
                return Column(
                  children: [
                    _StatusStatCard(
                      title: 'Temperatura',
                      value: '$_temperature°C',
                      icon: Icons.thermostat_rounded,
                      chipLabel: 'W normie',
                      chipColor: AppColors.success.withValues(alpha: 0.3),
                    ),
                    SizedBox(height: smallSpacing),
                    _StatusStatCard(
                      title: 'Wilgotność',
                      value: '${_humidity.toStringAsFixed(0)}%',
                      icon: Icons.water_drop_rounded,
                      chipLabel: 'Stabilnie',
                      chipColor: AppColors.accent.withValues(alpha: 0.25),
                    ),
                  ],
                );
              }
              
              // Dla większych ekranów - karty obok siebie
              return Row(
                children: [
                  Expanded(
                    child: _StatusStatCard(
                      title: 'Temperatura',
                      value: '$_temperature°C',
                      icon: Icons.thermostat_rounded,
                      chipLabel: 'W normie',
                      chipColor: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  SizedBox(width: smallSpacing),
                  Expanded(
                    child: _StatusStatCard(
                      title: 'Wilgotność',
                      value: '${_humidity.toStringAsFixed(0)}%',
                      icon: Icons.water_drop_rounded,
                      chipLabel: 'Stabilnie',
                      chipColor: AppColors.accent.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: Responsive.padding(28)),
          Text(
            'Ostatnie zdarzenia',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: Responsive.fontSize(16),
            ),
          ),
          SizedBox(height: smallSpacing),
          ..._events.map((event) => _EventTile(event: event)),
          SizedBox(height: Responsive.height(110)),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.isArmed,
    required this.statusColor,
    required this.onToggle,
    required this.isLoading,
    required this.isConnected,
  });

  final bool isArmed;
  final Color statusColor;
  final VoidCallback onToggle;
  final bool isLoading;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final isSmall = Responsive.isSmallDevice;
    
    // Responsywne wartości
    final cardPadding = Responsive.padding(isSmall ? 18 : 24);
    final cardRadius = Responsive.radius(28);
    final iconContainerPadding = Responsive.padding(isSmall ? 10 : 12);
    final iconContainerRadius = Responsive.radius(16);
    final iconSize = Responsive.iconSize(isSmall ? 26 : 32);
    final spacing = Responsive.padding(isSmall ? 12 : 16);
    final verticalSpacing = Responsive.padding(isSmall ? 18 : 24);
    
    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(iconContainerPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(iconContainerRadius),
                ),
                child: Icon(
                  isArmed ? Icons.shield_rounded : Icons.shield_outlined,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontSize: Responsive.fontSize(14),
                      ),
                    ),
                    Text(
                      isArmed ? 'Uzbrojony' : 'Rozbrojony',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: Responsive.fontSize(isSmall ? 20 : 24),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Responsive.padding(8)),
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Transform.scale(
                  scale: isSmall ? 0.8 : 0.9,
                  alignment: Alignment.centerRight,
                  child: Switch.adaptive(
                    value: isArmed,
                    onChanged: isConnected ? (_) => onToggle() : null,
                    thumbColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.midnight
                          : Colors.white,
                    ),
                    trackColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.accent.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: verticalSpacing),
          Text(
            !isConnected
                ? 'Połącz z chmurą, aby sterować.'
                : isArmed
                    ? 'Wszystkie strefy są zabezpieczone. Czujniki aktywne.'
                    : 'System w trybie podglądu. Aktywuj, aby chronić dom.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
              fontSize: Responsive.fontSize(isSmall ? 14 : 16),
            ),
          ),
          SizedBox(height: Responsive.padding(isSmall ? 16 : 20)),
          _buildStatusRow(context, isSmall),
        ],
      ),
    );
  }
  
  Widget _buildStatusRow(BuildContext context, bool isSmall) {
    final theme = Theme.of(context);
    final chipPadding = Responsive.paddingSymmetric(
      horizontal: isSmall ? 12 : 16,
      vertical: isSmall ? 8 : 10,
    );
    final chipRadius = Responsive.radius(20);
    
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: chipPadding,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(chipRadius),
            ),
            child: Row(
              children: [
                Icon(
                  isArmed ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: statusColor,
                  size: Responsive.iconSize(isSmall ? 18 : 22),
                ),
                SizedBox(width: Responsive.padding(8)),
                Flexible(
                  child: Text(
                    !isConnected ? 'Offline' : (isArmed ? 'Aktywny tryb ochrony' : 'Tryb domowy'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: Responsive.fontSize(isSmall ? 12 : 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: Responsive.padding(12)),
        TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(isSmall ? 10 : 14),
              vertical: Responsive.padding(isSmall ? 8 : 10),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: isConnected ? onToggle : null,
          child: Text(
            isArmed ? 'Rozbrój' : 'Uzbrój',
            style: TextStyle(fontSize: Responsive.fontSize(isSmall ? 13 : 14)),
          ),
        ),
      ],
    );
  }
}

class _StatusStatCard extends StatelessWidget {
  const _StatusStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.chipLabel,
    required this.chipColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final String chipLabel;
  final Color chipColor;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final isSmall = Responsive.isSmallDevice;
    
    // Responsywne wartości
    final cardPadding = Responsive.padding(isSmall ? 16 : 20);
    final cardRadius = Responsive.radius(24);
    final iconSize = Responsive.iconSize(isSmall ? 24 : 28);
    final valueSpacing = Responsive.padding(isSmall ? 14 : 18);
    final chipPadding = Responsive.paddingSymmetric(
      horizontal: isSmall ? 10 : 14,
      vertical: isSmall ? 4 : 6,
    );
    
    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: iconSize),
          SizedBox(height: valueSpacing),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: Responsive.fontSize(isSmall ? 20 : 24),
            ),
          ),
          SizedBox(height: Responsive.padding(6)),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: Responsive.fontSize(isSmall ? 12 : 14),
            ),
          ),
          SizedBox(height: Responsive.padding(isSmall ? 10 : 14)),
          Container(
            padding: chipPadding,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(Responsive.radius(16)),
            ),
            child: Text(
              chipLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: Responsive.fontSize(isSmall ? 11 : 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final _SecurityEvent event;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final isSmall = Responsive.isSmallDevice;
    
    final Color badgeColor;
    switch (event.type) {
      case EventType.warning:
        badgeColor = AppColors.warning;
        break;
      case EventType.success:
        badgeColor = AppColors.success;
        break;
      default:
        badgeColor = AppColors.textSecondary;
    }
    
    // Responsywne wartości
    final tileMargin = Responsive.padding(12);
    final tilePadding = Responsive.padding(isSmall ? 12 : 16);
    final tileRadius = Responsive.radius(20);
    final iconContainerPadding = Responsive.padding(isSmall ? 10 : 12);
    final iconContainerRadius = Responsive.radius(16);
    final iconSize = Responsive.iconSize(isSmall ? 20 : 24);

    return Container(
      margin: EdgeInsets.only(bottom: tileMargin),
      padding: EdgeInsets.all(tilePadding),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(tileRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(iconContainerPadding),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(iconContainerRadius),
            ),
            child: Icon(
              event.icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          SizedBox(width: Responsive.padding(isSmall ? 12 : 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.fontSize(isSmall ? 14 : 16),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: Responsive.padding(isSmall ? 4 : 6)),
                Text(
                  event.time,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: Responsive.fontSize(isSmall ? 11 : 12),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white24,
            size: Responsive.iconSize(24),
          ),
        ],
      ),
    );
  }
}

class _SecurityEvent {
  const _SecurityEvent({
    required this.title,
    required this.time,
    required this.type,
    required this.icon,
  });

  final String title;
  final String time;
  final EventType type;
  final IconData icon;
}

enum EventType { warning, success, neutral }
