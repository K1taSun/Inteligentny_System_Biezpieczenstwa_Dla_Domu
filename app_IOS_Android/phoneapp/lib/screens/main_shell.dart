import 'package:flutter/material.dart';
import 'package:phoneapp/screens/recordings_screen.dart';
import 'package:phoneapp/screens/status_screen.dart';
import 'package:phoneapp/screens/video_screen.dart';
import 'package:phoneapp/utils/responsive.dart';

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
    // Inicjalizacja responsywności
    Responsive.init(context);
    
    // Responsywne wartości
    final horizontalPadding = Responsive.padding(20);
    final topPadding = Responsive.padding(16);
    final navBarPadding = Responsive.padding(16);
    final navBarBottomPadding = Responsive.padding(8);
    final navBarRadius = Responsive.radius(28);
    final navBarHeight = Responsive.navBarHeight;
    
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(
            fontSize: Responsive.fontSize(20),
            fontWeight: FontWeight.w600,
          ),
        ),
        toolbarHeight: Responsive.height(56),
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
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: topPadding,
                bottom: 0,
              ),
              child: _screens[_selectedIndex],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            navBarPadding,
            0,
            navBarPadding,
            navBarBottomPadding,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(navBarRadius),
            child: NavigationBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black26,
              elevation: 3,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              labelBehavior: Responsive.isSmallDevice
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              height: navBarHeight,
              destinations: [
                NavigationDestination(
                  icon: Icon(
                    Icons.home_outlined,
                    size: Responsive.iconSize(24),
                  ),
                  selectedIcon: Icon(
                    Icons.home_rounded,
                    size: Responsive.iconSize(24),
                  ),
                  label: 'Status',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.videocam_outlined,
                    size: Responsive.iconSize(24),
                  ),
                  selectedIcon: Icon(
                    Icons.videocam_rounded,
                    size: Responsive.iconSize(24),
                  ),
                  label: 'Video',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.folder_outlined,
                    size: Responsive.iconSize(24),
                  ),
                  selectedIcon: Icon(
                    Icons.folder_rounded,
                    size: Responsive.iconSize(24),
                  ),
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
