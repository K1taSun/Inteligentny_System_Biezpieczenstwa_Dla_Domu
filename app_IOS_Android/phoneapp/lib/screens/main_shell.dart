import 'package:flutter/material.dart';
import 'package:phoneapp/screens/recordings_screen.dart';
import 'package:phoneapp/screens/status_screen.dart';
import 'package:phoneapp/screens/video_screen.dart';
import 'package:phoneapp/utils/responsive.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

// Prosty klient HTTP do autoryzacji Google (taki sam jak w recordings_screen.dart)
class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

// Singleton do zarządzania autoryzacją Google w całej aplikacji
class GoogleAuthService extends ChangeNotifier {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveReadonlyScope,
      drive.DriveApi.driveFileScope, // Potrzebne do zapisu pliku statusu
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  bool _isConnected = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  drive.DriveApi? get driveApi => _driveApi;
  bool get isConnected => _isConnected;

  Future<void> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await _handleSignInSuccess(account);
      }
    } catch (e) {
      debugPrint('Silent sign-in error: $e');
    }
  }

  Future<void> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _handleSignInSuccess(account);
      }
    } catch (e) {
      debugPrint('Sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _isConnected = false;
    notifyListeners();
  }

  Future<void> _handleSignInSuccess(GoogleSignInAccount account) async {
    _currentUser = account;
    final headers = await account.authHeaders;
    _driveApi = drive.DriveApi(GoogleAuthClient(headers));
    _isConnected = true;
    notifyListeners();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GoogleAuthService _authService = GoogleAuthService();

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
  void initState() {
    super.initState();
    // Próba cichego logowania przy starcie aplikacji
    _authService.signInSilently();
  }

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
        actions: [
          // Dodajemy ikonkę statusu połączenia z chmurą
          AnimatedBuilder(
            animation: _authService,
            builder: (context, _) {
              return IconButton(
                icon: Icon(
                  _authService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _authService.isConnected ? Colors.green : Colors.grey,
                  size: Responsive.iconSize(24),
                ),
                onPressed: () {
                  if (!_authService.isConnected) {
                    _authService.signIn();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Połączono z Google Drive')),
                    );
                  }
                },
                tooltip: _authService.isConnected ? 'Połączono z chmurą' : 'Połącz z chmurą',
              );
            },
          ),
          SizedBox(width: Responsive.padding(8)),
        ],
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
