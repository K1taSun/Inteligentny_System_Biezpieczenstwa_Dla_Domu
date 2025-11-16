import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:phoneapp/theme/app_theme.dart';

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

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveReadonlyScope],
  );

  final TextEditingController _searchController = TextEditingController();

  GoogleSignInAccount? _currentUser;
  List<drive.File> _recordings = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() => _currentUser = account);
      if (account != null) {
        _loadRecordings();
      }
    });
    _googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('Sign in error: $e');
    }
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.disconnect();
    setState(() {
      _recordings = [];
      _dateRange = null;
      _searchQuery = '';
      _errorMessage = null;
    });
  }

  Future<void> _loadRecordings() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final headers = await _currentUser!.authHeaders;
    final driveApi = drive.DriveApi(GoogleAuthClient(headers));
    try {
      final files = await driveApi.files.list(
        q: "mimeType='video/mp4' and trashed=false",
        orderBy: 'createdTime desc',
        spaces: 'drive',
        $fields: 'files(id, name, thumbnailLink, createdTime)',
      );
      setState(() {
        _recordings = files.files ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Nie udało się pobrać nagrań. Spróbuj ponownie.';
        _isLoading = false;
      });
    }
  }

  List<drive.File> get _filteredRecordings {
    return _recordings.where((file) {
      final matchesQuery =
          file.name?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      if (!matchesQuery) return false;
      if (_dateRange == null || file.createdTime == null) return true;
      final created = file.createdTime!;
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
    if (_currentUser == null) {
      return _buildLoginCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _buildSearchBar(),
        if (_dateRange != null) ...[
          const SizedBox(height: 12),
          _ActiveFilterChip(
            label:
                '${_dateRange!.start.day}.${_dateRange!.start.month}.${_dateRange!.start.year} - ${_dateRange!.end.day}.${_dateRange!.end.month}.${_dateRange!.end.year}',
            onClear: () => setState(() => _dateRange = null),
          ),
        ],
        const SizedBox(height: 18),
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
    if (_isLoading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _RecordingSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
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
          const SizedBox(height: 60),
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _RecordingCard(file: items[index]),
    );
  }

  Widget _buildLoginCard() {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.lock_outline, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Połącz dysk z nagraniami',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Zaloguj się kontem Google, aby zsynchronizować nagrania i zarządzać historią w aplikacji.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Zaloguj z Google'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = _currentUser;
    final initials = user?.displayName?.isNotEmpty == true
        ? user!.displayName!.substring(0, 1).toUpperCase()
        : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.accent.withValues(alpha: 0.25),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nagrania zsynchronizowane',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                user?.displayName ?? 'Użytkownik',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _handleSignOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Szukaj nagrania lub kamery...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearFilters,
              ),
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: _pickDateRange,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.file});

  final drive.File file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: file.thumbnailLink != null
                        ? Image.network(file.thumbnailLink!, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.midnight,
                            child: const Icon(Icons.movie, color: Colors.white30, size: 48),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'MP4',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name ?? 'Nagranie',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  file.createdTime != null
                      ? '${file.createdTime!.day}.${file.createdTime!.month}.${file.createdTime!.year}'
                      : 'Nieznana data',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.download_rounded, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Pobierz',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_horiz, color: Colors.white70),
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

class _RecordingSkeleton extends StatelessWidget {
  const _RecordingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1F2F52),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 140, color: Colors.white10),
                const SizedBox(height: 10),
                Container(height: 10, width: 100, color: Colors.white10),
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
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 32, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onAction,
          child: Text(actionLabel),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

