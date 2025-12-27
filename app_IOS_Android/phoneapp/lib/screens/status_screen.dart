import 'package:flutter/material.dart';
import 'package:phoneapp/theme/app_theme.dart';
import 'package:phoneapp/utils/responsive.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  bool _isArmed = true;
  final double _temperature = 21.4;
  final double _humidity = 47;
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

  void _toggleAlarm() {
    setState(() {
      _isArmed = !_isArmed;
    });
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
  });

  final bool isArmed;
  final Color statusColor;
  final VoidCallback onToggle;

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
              Transform.scale(
                scale: isSmall ? 0.8 : 0.9,
                alignment: Alignment.centerRight,
                child: Switch.adaptive(
                  value: isArmed,
                  onChanged: (_) => onToggle(),
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
            isArmed
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
                    isArmed ? 'Aktywny tryb ochrony' : 'Tryb domowy',
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
          onPressed: onToggle,
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
