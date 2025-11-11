import 'package:flutter/material.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  // Mock data - replace with real data later
  bool _isArmed = true;
  final double _temperature = 21.5;
  final String _lastMovement = "10:32";

  void _toggleAlarm() {
    setState(() {
      _isArmed = !_isArmed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildStatusCard(
              icon: Icons.security,
              title: 'Alarm Status',
              value: _isArmed ? 'ARMED' : 'DISARMED',
              color: _isArmed ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 16),
            _buildStatusCard(
              icon: Icons.thermostat,
              title: 'Temperature',
              value: '$_temperature °C',
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildStatusCard(
              icon: Icons.directions_run,
              title: 'Last Movement Detected',
              value: _lastMovement,
              color: Colors.orange,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleAlarm,
        tooltip: 'Toggle Alarm',
        child: const Icon(Icons.power_settings_new),
      ),
    );
  }
}

Widget _buildStatusCard({
  required IconData icon,
  required String title,
  required String value,
  required Color color,
}) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 40, color: color),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(value, style: TextStyle(fontSize: 22, color: color)),
            ],
          ),
        ],
      ),
    ),
  );
}
