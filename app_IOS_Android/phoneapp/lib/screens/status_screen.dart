import 'package:flutter/material.dart';
import 'package:phoneapp/theme/app_theme.dart';

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
    final theme = Theme.of(context);
    final statusColor = _isArmed ? AppColors.accent : AppColors.warning;

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
          const SizedBox(height: 24),
          Text(
            'Szybkie dane',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
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
              const SizedBox(width: 12),
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
          ),
          const SizedBox(height: 28),
          Text(
            'Ostatnie zdarzenia',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._events.map((event) => _EventTile(event: event)),

          const SizedBox(height: 110),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isArmed ? Icons.shield_rounded : Icons.shield_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      isArmed ? 'Uzbrojony' : 'Rozbrojony',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Transform.scale(
                scale: 0.9,
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
          const SizedBox(height: 24),
          Text(
            isArmed
                ? 'Wszystkie strefy są zabezpieczone. Czujniki aktywne.'
                : 'System w trybie podglądu. Aktywuj, aby chronić dom.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isArmed ? Icons.lock_rounded : Icons.lock_open_rounded,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isArmed ? 'Aktywny tryb ochrony' : 'Tryb domowy',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onToggle,
                child: Text(isArmed ? 'Rozbrój' : 'Uzbrój'),
              ),
            ],
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 18),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              chipLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
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
    final theme = Theme.of(context);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(event.icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  event.time,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24),
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

