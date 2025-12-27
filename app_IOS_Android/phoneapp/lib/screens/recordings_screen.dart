import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:phoneapp/theme/app_theme.dart';
import 'package:phoneapp/utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

/// Klient HTTP z nagłówkami autoryzacji Google
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

/// Model nagrania dla trybu demo i rzeczywistego użycia
class Recording {
  final String id;
  final String name;
  final String? thumbnailUrl;
  final DateTime createdTime;
  final String cameraName;
  final String? webViewLink;
  final String? webContentLink;

  Recording({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    required this.createdTime,
    required this.cameraName,
    this.webViewLink,
    this.webContentLink,
  });

  /// Tworzy Recording z pliku Google Drive
  factory Recording.fromDriveFile(drive.File file) {
    return Recording(
      id: file.id ?? '',
      name: file.name ?? 'Nagranie',
      thumbnailUrl: file.thumbnailLink,
      createdTime: file.createdTime ?? DateTime.now(),
      cameraName: 'Kamera Raspberry Pi',
      webViewLink: file.webViewLink,
      webContentLink: file.webContentLink,
    );
  }
}

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  // Google Sign-In z uprawnieniami do odczytu i usuwania plików
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveReadonlyScope,
      drive.DriveApi.driveFileScope,
    ],
  );

  final TextEditingController _searchController = TextEditingController();

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  
  bool _isConnected = false;
  List<Recording> _recordings = [];
  bool _isLoading = false;
  bool _isSigningIn = false;
  String? _errorMessage;
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  String _connectedDriveName = '';
  bool _isDemoMode = false;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen(_onUserChanged);
    _trySilentSignIn();
  }

  void _onUserChanged(GoogleSignInAccount? account) {
    if (mounted) {
      setState(() {
        _currentUser = account;
        _isSigningIn = false;
      });
      if (account != null) {
        _initDriveApi();
      }
    }
  }

  Future<void> _trySilentSignIn() async {
    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in skipped: $e');
    }
  }

  Future<void> _initDriveApi() async {
    if (_currentUser == null) return;
    
    try {
      final headers = await _currentUser!.authHeaders;
      _driveApi = drive.DriveApi(GoogleAuthClient(headers));
      
      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectedDriveName = _currentUser?.email ?? 'Google Drive';
          _isDemoMode = false;
        });
      }
      
      await _loadRecordingsFromDrive();
    } catch (e) {
      debugPrint('Error initializing Drive API: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Nie udało się połączyć z Google Drive.';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final account = await _googleSignIn.signIn();
      
      if (account == null) {
        // Użytkownik anulował logowanie
        if (mounted) {
          setState(() {
            _isSigningIn = false;
            _isLoading = false;
          });
        }
        return;
      }
      // Sukces - _onUserChanged zostanie wywołane automatycznie
    } on PlatformException catch (e) {
      debugPrint('Platform sign-in error: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _isLoading = false;
          _errorMessage = _getSignInErrorMessage(e.code);
        });
        
        // Pokaż opcję trybu demo
        _showDemoModeOption();
      }
    } catch (e) {
      debugPrint('Sign-in error: $e');
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _isLoading = false;
          _errorMessage = 'Błąd logowania. Sprawdź połączenie z internetem.';
        });
        
        _showDemoModeOption();
      }
    }
  }

  void _showDemoModeOption() {
    Responsive.init(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Nie można połączyć z Google. Uruchomić tryb demo?',
          style: TextStyle(fontSize: Responsive.fontSize(14)),
        ),
        action: SnackBarAction(
          label: 'Demo',
          onPressed: _enableDemoMode,
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Responsive.radius(12)),
        ),
        margin: EdgeInsets.all(Responsive.padding(16)),
      ),
    );
  }

  void _enableDemoMode() {
    setState(() {
      _isConnected = true;
      _isDemoMode = true;
      _connectedDriveName = 'Tryb Demo';
      _recordings = _generateDemoRecordings();
      _errorMessage = null;
    });
  }

  String _getSignInErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'sign_in_canceled':
        return 'Logowanie zostało anulowane.';
      case 'sign_in_failed':
        return 'Nie udało się zalogować. Sprawdź konfigurację Google.';
      case 'network_error':
        return 'Brak połączenia z internetem.';
      default:
        return 'Wystąpił błąd podczas logowania (kod: $errorCode).';
    }
  }

  Future<void> _handleDisconnect() async {
    try {
      if (!_isDemoMode) {
        await _googleSignIn.disconnect();
      }
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
    
    if (mounted) {
      setState(() {
        _currentUser = null;
        _driveApi = null;
        _isConnected = false;
        _isDemoMode = false;
        _recordings = [];
        _dateRange = null;
        _searchQuery = '';
        _errorMessage = null;
        _connectedDriveName = '';
      });
    }
  }

  List<Recording> _generateDemoRecordings() {
    final now = DateTime.now();
    return [
      Recording(
        id: 'demo_1',
        name: 'alarm_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_083000.mp4',
        createdTime: now.subtract(const Duration(hours: 2)),
        cameraName: 'Kamera Raspberry Pi',
      ),
      Recording(
        id: 'demo_2',
        name: 'alarm_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_121500.mp4',
        createdTime: now.subtract(const Duration(hours: 5)),
        cameraName: 'Kamera Raspberry Pi',
      ),
      Recording(
        id: 'demo_3',
        name: 'alarm_${now.year}${now.month.toString().padLeft(2, '0')}${(now.day - 1).toString().padLeft(2, '0')}_224500.mp4',
        createdTime: now.subtract(const Duration(days: 1)),
        cameraName: 'Kamera Raspberry Pi',
      ),
      Recording(
        id: 'demo_4',
        name: 'alarm_${now.year}${now.month.toString().padLeft(2, '0')}${(now.day - 2).toString().padLeft(2, '0')}_142000.mp4',
        createdTime: now.subtract(const Duration(days: 2)),
        cameraName: 'Kamera Raspberry Pi',
      ),
    ];
  }

  Future<void> _loadRecordings() async {
    if (!_isConnected) return;
    
    if (_isDemoMode) {
      setState(() {
        _recordings = _generateDemoRecordings();
      });
      return;
    }
    
    await _loadRecordingsFromDrive();
  }

  Future<void> _loadRecordingsFromDrive() async {
    if (_driveApi == null) return;
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Szukaj plików MP4 (nagrania z alarmu)
      final fileList = await _driveApi!.files.list(
        q: "mimeType='video/mp4' and trashed=false",
        orderBy: 'createdTime desc',
        spaces: 'drive',
        $fields: 'files(id, name, thumbnailLink, createdTime, webViewLink, webContentLink)',
        pageSize: 50,
      );
      
      if (mounted) {
        setState(() {
          _recordings = (fileList.files ?? [])
              .map((file) => Recording.fromDriveFile(file))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recordings: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Nie udało się pobrać nagrań z Google Drive.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRecording(Recording recording) async {
    if (_isDemoMode) {
      // W trybie demo usuwamy lokalnie
      setState(() {
        _recordings.removeWhere((r) => r.id == recording.id);
      });
      return;
    }

    if (_driveApi == null) return;

    try {
      await _driveApi!.files.delete(recording.id);
      
      if (mounted) {
        Responsive.init(context);
        
        setState(() {
          _recordings.removeWhere((r) => r.id == recording.id);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: Responsive.iconSize(20),
                ),
                SizedBox(width: Responsive.padding(12)),
                Expanded(
                  child: Text(
                    'Usunięto: ${recording.name}',
                    style: TextStyle(fontSize: Responsive.fontSize(14)),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Responsive.radius(12)),
            ),
            margin: EdgeInsets.all(Responsive.padding(16)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting recording: $e');
      if (mounted) {
        Responsive.init(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nie udało się usunąć nagrania.',
              style: TextStyle(fontSize: Responsive.fontSize(14)),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Responsive.radius(12)),
            ),
            margin: EdgeInsets.all(Responsive.padding(16)),
          ),
        );
      }
    }
  }

  List<Recording> get _filteredRecordings {
    return _recordings.where((recording) {
      final matchesQuery =
          recording.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          recording.cameraName.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesQuery) return false;
      if (_dateRange == null) return true;
      final created = recording.createdTime;
      return !created.isBefore(_dateRange!.start) &&
          !created.isAfter(_dateRange!.end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (newRange != null) {
      setState(() => _dateRange = newRange);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _dateRange = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    if (!_isConnected) {
      return _buildConnectCard();
    }

    final spacing = Responsive.padding(18);
    final smallSpacing = Responsive.padding(12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        SizedBox(height: spacing),
        _buildSearchBar(),
        if (_dateRange != null) ...[
          SizedBox(height: smallSpacing),
          _ActiveFilterChip(
            label:
                '${_dateRange!.start.day}.${_dateRange!.start.month}.${_dateRange!.start.year} - ${_dateRange!.end.day}.${_dateRange!.end.month}.${_dateRange!.end.year}',
            onClear: () => setState(() => _dateRange = null),
          ),
        ],
        SizedBox(height: spacing),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRecordings,
            child: _buildRecordingsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingsList() {
    final spacing = Responsive.padding(12);
    
    if (_isLoading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => SizedBox(height: spacing),
        itemBuilder: (_, __) => const _RecordingSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: Responsive.padding(60)),
          _CenteredMessage(
            message: _errorMessage!,
            actionLabel: 'Spróbuj ponownie',
            icon: Icons.refresh,
            onAction: _loadRecordings,
          ),
        ],
      );
    }

    final items = _filteredRecordings;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: Responsive.padding(60)),
          _CenteredMessage(
            message: 'Brak nagrań spełniających filtry.',
            actionLabel: 'Wyczyść filtry',
            icon: Icons.filter_alt_off,
            onAction: _clearFilters,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (_, index) => _RecordingCard(
        recording: items[index],
        onDelete: () => _deleteRecording(items[index]),
        isDemoMode: _isDemoMode,
      ),
    );
  }

  Widget _buildConnectCard() {
    final theme = Theme.of(context);
    final isSmall = Responsive.isSmallDevice;
    
    final cardPadding = Responsive.padding(isSmall ? 24 : 32);
    final cardRadius = Responsive.radius(28);
    final iconContainerPadding = Responsive.padding(isSmall ? 18 : 24);
    final iconSize = Responsive.iconSize(isSmall ? 48 : 64);
    
    return Align(
      alignment: const Alignment(0, -0.5),
      child: Container(
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(iconContainerPadding),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.2),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(Icons.cloud_outlined, size: iconSize, color: Colors.white),
            ),
            SizedBox(height: Responsive.padding(isSmall ? 18 : 24)),
            Text(
              _isLoading ? 'Łączenie...' : 'Połącz z Google Drive',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: Responsive.fontSize(isSmall ? 18 : 22),
              ),
            ),
            SizedBox(height: Responsive.padding(12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.padding(8)),
              child: Text(
                _isLoading
                    ? 'Trwa logowanie do Google Drive...'
                    : 'Zaloguj się kontem Google, aby przeglądać nagrania z systemu alarmowego przesłane przez Raspberry Pi.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: Responsive.fontSize(isSmall ? 13 : 14),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: Responsive.padding(16)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(16),
                  vertical: Responsive.padding(12),
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Responsive.radius(12)),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: Responsive.iconSize(20),
                    ),
                    SizedBox(width: Responsive.padding(10)),
                    Flexible(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                          fontSize: Responsive.fontSize(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: Responsive.padding(isSmall ? 18 : 24)),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleConnect,
              icon: _isLoading
                  ? SizedBox(
                      width: Responsive.sp(18),
                      height: Responsive.sp(18),
                      child: const CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.login, size: Responsive.iconSize(20)),
              label: Text(
                _isLoading ? 'Łączenie...' : 'Zaloguj przez Google',
                style: TextStyle(fontSize: Responsive.fontSize(14)),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(20),
                  vertical: Responsive.padding(12),
                ),
              ),
            ),
            SizedBox(height: Responsive.padding(16)),
            TextButton(
              onPressed: _isLoading ? null : _enableDemoMode,
              child: Text(
                'Użyj trybu demo',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: Responsive.fontSize(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isSmall = Responsive.isSmallDevice;
    final avatarSize = Responsive.sp(isSmall ? 48 : 56);
    final iconSize = Responsive.iconSize(isSmall ? 24 : 28);
    
    return Row(
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isDemoMode 
                ? Colors.orange.withValues(alpha: 0.25)
                : AppColors.accent.withValues(alpha: 0.25),
          ),
          child: Icon(
            _isDemoMode ? Icons.science : Icons.cloud,
            color: Colors.white,
            size: iconSize,
          ),
        ),
        SizedBox(width: Responsive.padding(isSmall ? 12 : 16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _isDemoMode ? 'Tryb Demo' : 'Google Drive',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: Responsive.fontSize(12),
                    ),
                  ),
                  if (_isDemoMode) ...[
                    SizedBox(width: Responsive.padding(8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(6),
                        vertical: Responsive.padding(2),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(Responsive.radius(8)),
                      ),
                      child: Text(
                        'DEMO',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: Responsive.fontSize(10),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                _connectedDriveName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.fontSize(isSmall ? 14 : 16),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadRecordings,
          icon: Icon(Icons.refresh, size: Responsive.iconSize(22)),
          tooltip: 'Odśwież',
        ),
        IconButton(
          onPressed: _handleDisconnect,
          icon: Icon(Icons.logout, size: Responsive.iconSize(22)),
          tooltip: 'Wyloguj',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final isSmall = Responsive.isSmallDevice;
    
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: TextStyle(fontSize: Responsive.fontSize(14)),
      decoration: InputDecoration(
        hintText: 'Szukaj nagrania lub kamery...',
        hintStyle: TextStyle(fontSize: Responsive.fontSize(14)),
        prefixIcon: Icon(Icons.search, size: Responsive.iconSize(22)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(16),
          vertical: Responsive.padding(isSmall ? 12 : 16),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close, size: Responsive.iconSize(20)),
                onPressed: _clearFilters,
              ),
            IconButton(
              icon: Icon(Icons.filter_alt, size: Responsive.iconSize(22)),
              onPressed: _pickDateRange,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingCard extends StatefulWidget {
  const _RecordingCard({
    required this.recording,
    required this.onDelete,
    required this.isDemoMode,
  });

  final Recording recording;
  final VoidCallback onDelete;
  final bool isDemoMode;

  @override
  State<_RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends State<_RecordingCard> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  void _handlePlay() {
    showDialog(
      context: context,
      builder: (context) => _VideoPlayerDialog(recording: widget.recording),
    );
  }

  Future<void> _handleDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    // Symulacja pobierania
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _downloadProgress = i / 100;
        });
      }
    }

    if (mounted) {
      Responsive.init(context);
      
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.white,
                size: Responsive.iconSize(20),
              ),
              SizedBox(width: Responsive.padding(12)),
              Expanded(
                child: Text(
                  'Pobrano: ${widget.recording.name}',
                  style: TextStyle(fontSize: Responsive.fontSize(14)),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.radius(12)),
          ),
          margin: EdgeInsets.all(Responsive.padding(16)),
        ),
      );
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Responsive.radius(24)),
        ),
      ),
      builder: (context) => _MoreOptionsSheet(
        recording: widget.recording,
        onDelete: widget.onDelete,
        isDemoMode: widget.isDemoMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final recording = widget.recording;
    final createdTime = recording.createdTime;
    final timeString = '${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}';
    final dateString = '${createdTime.day}.${createdTime.month}.${createdTime.year}';
    
    final isSmall = Responsive.isSmallDevice;
    final cardRadius = Responsive.radius(24);
    final thumbnailHeight = Responsive.height(isSmall ? 140 : 160);
    final contentPadding = Responsive.padding(isSmall ? 12 : 16);
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          // Thumbnail z przyciskiem play
          GestureDetector(
            onTap: _handlePlay,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
              child: SizedBox(
                height: thumbnailHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: recording.thumbnailUrl != null
                          ? Image.network(recording.thumbnailUrl!, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.midnight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.videocam,
                                    color: Colors.white30,
                                    size: Responsive.iconSize(isSmall ? 40 : 48),
                                  ),
                                  SizedBox(height: Responsive.padding(8)),
                                  Text(
                                    timeString,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      color: Colors.white24,
                                      fontWeight: FontWeight.w600,
                                      fontSize: Responsive.fontSize(isSmall ? 24 : 28),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    // Duży przycisk play na środku
                    Center(
                      child: Container(
                        width: Responsive.sp(isSmall ? 52 : 64),
                        height: Responsive.sp(isSmall ? 52 : 64),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: Responsive.iconSize(isSmall ? 32 : 40),
                        ),
                      ),
                    ),
                    Positioned(
                      top: Responsive.padding(12),
                      left: Responsive.padding(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.padding(isSmall ? 10 : 12),
                          vertical: Responsive.padding(isSmall ? 4 : 6),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(Responsive.radius(14)),
                        ),
                        child: Text(
                          'MP4',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: Responsive.fontSize(isSmall ? 11 : 13),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: Responsive.padding(12),
                      right: Responsive.padding(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.padding(isSmall ? 8 : 10),
                          vertical: Responsive.padding(isSmall ? 4 : 6),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(Responsive.radius(14)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam,
                              color: Colors.white,
                              size: Responsive.iconSize(isSmall ? 12 : 14),
                            ),
                            SizedBox(width: Responsive.padding(4)),
                            Text(
                              isSmall ? 'RPi' : recording.cameraName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Responsive.fontSize(isSmall ? 10 : 11),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Pasek postępu pobierania
          if (_isDownloading)
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: AppColors.midnight,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 3,
            ),
          Padding(
            padding: EdgeInsets.all(contentPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.fontSize(isSmall ? 14 : 16),
                  ),
                ),
                SizedBox(height: Responsive.padding(6)),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: Responsive.iconSize(isSmall ? 12 : 14),
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: Responsive.padding(6)),
                    Text(
                      dateString,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: Responsive.fontSize(isSmall ? 11 : 12),
                      ),
                    ),
                    SizedBox(width: Responsive.padding(isSmall ? 12 : 16)),
                    Icon(
                      Icons.access_time,
                      size: Responsive.iconSize(isSmall ? 12 : 14),
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: Responsive.padding(6)),
                    Text(
                      timeString,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: Responsive.fontSize(isSmall ? 11 : 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.padding(isSmall ? 10 : 14)),
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.play_circle_outline,
                      label: 'Odtwórz',
                      onTap: _handlePlay,
                    ),
                    SizedBox(width: Responsive.padding(isSmall ? 8 : 12)),
                    _ActionButton(
                      icon: _isDownloading ? Icons.hourglass_top : Icons.download_rounded,
                      label: _isDownloading 
                          ? '${(_downloadProgress * 100).toInt()}%' 
                          : 'Pobierz',
                      onTap: _handleDownload,
                      isLoading: _isDownloading,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _showMoreOptions,
                      icon: Icon(
                        Icons.more_horiz,
                        color: Colors.white70,
                        size: Responsive.iconSize(22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog odtwarzacza wideo
class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.recording});

  final Recording recording;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  final double _duration = 45.0; // Symulacja 45 sekund nagrania

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  void _startPlayback() {
    setState(() => _isPlaying = true);
    _simulatePlayback();
  }

  Future<void> _simulatePlayback() async {
    while (_isPlaying && _currentPosition < _duration && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && _isPlaying) {
        setState(() {
          _currentPosition += 0.1;
          if (_currentPosition >= _duration) {
            _currentPosition = _duration;
            _isPlaying = false;
          }
        });
      }
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        if (_currentPosition >= _duration) {
          _currentPosition = 0;
        }
        _simulatePlayback();
      }
    });
  }

  void _seekTo(double position) {
    setState(() {
      _currentPosition = position;
    });
  }

  String _formatTime(double seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds.toInt() % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final createdTime = widget.recording.createdTime;
    final dateString = '${createdTime.day}.${createdTime.month}.${createdTime.year}';
    final timeString = '${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}';
    
    final isSmall = Responsive.isSmallDevice;
    final dialogPadding = Responsive.padding(16);
    final dialogRadius = Responsive.radius(24);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(dialogPadding),
      child: Container(
        constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth),
        decoration: BoxDecoration(
          color: AppColors.midnight,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.padding(isSmall ? 16 : 20),
                Responsive.padding(isSmall ? 12 : 16),
                Responsive.padding(8),
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.recording.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: Responsive.fontSize(isSmall ? 14 : 16),
                          ),
                        ),
                        SizedBox(height: Responsive.padding(4)),
                        Text(
                          '$dateString • $timeString • ${widget.recording.cameraName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: Responsive.fontSize(isSmall ? 11 : 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: Responsive.iconSize(22),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.padding(isSmall ? 12 : 16)),
            // Video area
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: Responsive.padding(16)),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(Responsive.radius(16)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Symulacja wideo - animowany gradient
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Responsive.radius(16)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.navy.withValues(alpha: 0.8),
                            AppColors.midnight,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isPlaying ? Icons.videocam : Icons.videocam_off,
                              size: Responsive.iconSize(isSmall ? 40 : 48),
                              color: Colors.white24,
                            ),
                            SizedBox(height: Responsive.padding(8)),
                            Text(
                              _isPlaying ? 'Odtwarzanie...' : 'Wstrzymano',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white38,
                                fontSize: Responsive.fontSize(13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Overlay timestamp
                    Positioned(
                      top: Responsive.padding(12),
                      left: Responsive.padding(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.padding(8),
                          vertical: Responsive.padding(4),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(Responsive.radius(8)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: Responsive.sp(8),
                              height: Responsive.sp(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isPlaying ? Colors.red : Colors.grey,
                              ),
                            ),
                            SizedBox(width: Responsive.padding(6)),
                            Text(
                              'REC',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: Responsive.fontSize(11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: Responsive.padding(16)),
            // Controls
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.padding(20)),
              child: Column(
                children: [
                  // Progress bar
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppColors.accent,
                      trackHeight: 4,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: Responsive.sp(6),
                      ),
                    ),
                    child: Slider(
                      value: _currentPosition.clamp(0, _duration),
                      min: 0,
                      max: _duration,
                      onChanged: _seekTo,
                    ),
                  ),
                  // Time labels
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.padding(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(_currentPosition),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: Responsive.fontSize(11),
                          ),
                        ),
                        Text(
                          _formatTime(_duration),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: Responsive.fontSize(11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.padding(8)),
            // Playback controls
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.padding(20),
                0,
                Responsive.padding(20),
                Responsive.padding(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _seekTo((_currentPosition - 10).clamp(0, _duration)),
                    icon: Icon(
                      Icons.replay_10,
                      color: Colors.white70,
                      size: Responsive.iconSize(isSmall ? 28 : 32),
                    ),
                  ),
                  SizedBox(width: Responsive.padding(16)),
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: Responsive.sp(isSmall ? 56 : 64),
                      height: Responsive.sp(isSmall ? 56 : 64),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: Responsive.iconSize(isSmall ? 30 : 36),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.padding(16)),
                  IconButton(
                    onPressed: () => _seekTo((_currentPosition + 10).clamp(0, _duration)),
                    icon: Icon(
                      Icons.forward_10,
                      color: Colors.white70,
                      size: Responsive.iconSize(isSmall ? 28 : 32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet z dodatkowymi opcjami
class _MoreOptionsSheet extends StatelessWidget {
  const _MoreOptionsSheet({
    required this.recording,
    required this.onDelete,
    required this.isDemoMode,
  });

  final Recording recording;
  final VoidCallback onDelete;
  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final isSmall = Responsive.isSmallDevice;
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(Responsive.padding(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: Responsive.sp(40),
                height: Responsive.sp(4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(Responsive.radius(2)),
                ),
              ),
            ),
            SizedBox(height: Responsive.padding(20)),
            Text(
              recording.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: Responsive.fontSize(isSmall ? 14 : 16),
              ),
            ),
            SizedBox(height: Responsive.padding(4)),
            Row(
              children: [
                Text(
                  recording.cameraName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: Responsive.fontSize(12),
                  ),
                ),
                if (isDemoMode) ...[
                  SizedBox(width: Responsive.padding(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(6),
                      vertical: Responsive.padding(2),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(Responsive.radius(6)),
                    ),
                    child: Text(
                      'DEMO',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: Responsive.fontSize(10),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: Responsive.padding(24)),
            if (!isDemoMode && recording.webViewLink != null)
              _OptionTile(
                icon: Icons.open_in_browser,
                label: 'Otwórz w Google Drive',
                onTap: () async {
                  Navigator.pop(context);
                  final url = Uri.parse(recording.webViewLink!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      Responsive.init(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Nie udało się otworzyć linku',
                            style: TextStyle(fontSize: Responsive.fontSize(14)),
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Responsive.radius(12)),
                          ),
                          margin: EdgeInsets.all(Responsive.padding(16)),
                        ),
                      );
                    }
                  }
                },
              ),
            _OptionTile(
              icon: Icons.share_outlined,
              label: 'Udostępnij',
              onTap: () {
                Navigator.pop(context);
                Responsive.init(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isDemoMode 
                          ? 'Funkcja niedostępna w trybie demo'
                          : 'Funkcja udostępniania będzie dostępna wkrótce',
                      style: TextStyle(fontSize: Responsive.fontSize(14)),
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Responsive.radius(12)),
                    ),
                    margin: EdgeInsets.all(Responsive.padding(16)),
                  ),
                );
              },
            ),
            _OptionTile(
              icon: Icons.info_outline,
              label: 'Szczegóły',
              onTap: () {
                Navigator.pop(context);
                _showDetailsDialog(context, recording, isDemoMode);
              },
            ),
            _OptionTile(
              icon: Icons.delete_outline,
              label: isDemoMode ? 'Usuń (demo)' : 'Usuń z Google Drive',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, recording, onDelete, isDemoMode);
              },
            ),
            SizedBox(height: Responsive.padding(8)),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, Recording recording, bool isDemoMode) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    final createdTime = recording.createdTime;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Responsive.radius(20)),
        ),
        title: Text(
          'Szczegóły nagrania',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontSize: Responsive.fontSize(18),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Nazwa', value: recording.name),
            _DetailRow(label: 'Kamera', value: recording.cameraName),
            _DetailRow(
              label: 'Data',
              value: '${createdTime.day}.${createdTime.month}.${createdTime.year}',
            ),
            _DetailRow(
              label: 'Godzina',
              value: '${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}',
            ),
            _DetailRow(label: 'Format', value: 'MP4 (H.264)'),
            _DetailRow(label: 'Rozdzielczość', value: '1296x972'),
            _DetailRow(label: 'Czas trwania', value: '~60s'),
            if (!isDemoMode)
              _DetailRow(label: 'Lokalizacja', value: 'Google Drive'),
            if (isDemoMode)
              _DetailRow(label: 'Status', value: 'Tryb Demo'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Zamknij',
              style: TextStyle(fontSize: Responsive.fontSize(14)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Recording recording, VoidCallback onDelete, bool isDemoMode) {
    Responsive.init(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Responsive.radius(20)),
        ),
        title: Text(
          'Usuń nagranie?',
          style: TextStyle(
            color: Colors.white,
            fontSize: Responsive.fontSize(18),
          ),
        ),
        content: Text(
          isDemoMode
              ? 'Czy na pewno chcesz usunąć "${recording.name}" z listy demo?'
              : 'Czy na pewno chcesz trwale usunąć "${recording.name}" z Google Drive? Tej operacji nie można cofnąć.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: Responsive.fontSize(14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Anuluj',
              style: TextStyle(fontSize: Responsive.fontSize(14)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: Text(
              'Usuń',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: Responsive.fontSize(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final color = isDestructive ? Colors.redAccent : Colors.white;
    
    return ListTile(
      leading: Icon(icon, color: color, size: Responsive.iconSize(22)),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: Responsive.fontSize(14),
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.radius(12)),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.padding(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Responsive.sp(100),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: Responsive.fontSize(13),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: Responsive.fontSize(13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final isSmall = Responsive.isSmallDevice;
    
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(isSmall ? 10 : 12),
          vertical: Responsive.padding(isSmall ? 6 : 8),
        ),
        decoration: BoxDecoration(
          color: isLoading 
              ? AppColors.accent.withValues(alpha: 0.3)
              : AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(Responsive.radius(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.accent,
              size: Responsive.iconSize(isSmall ? 16 : 18),
            ),
            SizedBox(width: Responsive.padding(6)),
            Text(
              label,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: Responsive.fontSize(isSmall ? 11 : 13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingSkeleton extends StatelessWidget {
  const _RecordingSkeleton();

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final isSmall = Responsive.isSmallDevice;
    final height = Responsive.height(isSmall ? 190 : 220);
    final cardRadius = Responsive.radius(24);
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2F52),
                borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(Responsive.padding(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: Responsive.sp(14),
                  width: Responsive.sp(140),
                  color: Colors.white10,
                ),
                SizedBox(height: Responsive.padding(10)),
                Container(
                  height: Responsive.sp(10),
                  width: Responsive.sp(100),
                  color: Colors.white10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.message,
    required this.actionLabel,
    required this.icon,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    final theme = Theme.of(context);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: Responsive.iconSize(32),
          color: AppColors.textSecondary,
        ),
        SizedBox(height: Responsive.padding(16)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            fontSize: Responsive.fontSize(15),
          ),
        ),
        SizedBox(height: Responsive.padding(16)),
        OutlinedButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: TextStyle(fontSize: Responsive.fontSize(14)),
          ),
        ),
      ],
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(14),
        vertical: Responsive.padding(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(Responsive.radius(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: Responsive.iconSize(16),
            color: Colors.white,
          ),
          SizedBox(width: Responsive.padding(8)),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: Responsive.fontSize(13),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: Icon(
              Icons.close,
              size: Responsive.iconSize(18),
              color: Colors.white70,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: Responsive.sp(32),
              minHeight: Responsive.sp(32),
            ),
          ),
        ],
      ),
    );
  }
}
