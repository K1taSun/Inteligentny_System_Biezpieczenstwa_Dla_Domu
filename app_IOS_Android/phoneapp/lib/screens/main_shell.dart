import 'package:flutter/material.dart';
import 'package:phoneapp/screens/recordings_screen.dart';
import 'package:phoneapp/screens/status_screen.dart';
import 'package:phoneapp/screens/video_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    StatusScreen(),
    VideoScreen(),
    RecordingsScreen(),
  ];

  final List<String> _titles = const [
    'Panel główny',
    'Podgląd kamer',
    'Nagrania',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: SafeArea(
        bottom: false,
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.85, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: Padding(
              key: ValueKey(_selectedIndex),
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 0),
              child: _screens[_selectedIndex],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black26,
              elevation: 3,

              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              height: 70,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Status',
                ),
                NavigationDestination(
                  icon: Icon(Icons.videocam_outlined),
                  selectedIcon: Icon(Icons.videocam_rounded),
                  label: 'Video',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder_rounded),
                  label: 'Nagrania',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

