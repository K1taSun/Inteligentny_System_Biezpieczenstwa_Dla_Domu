import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

// Helper class to wrap the authenticated http client
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

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
  GoogleSignInAccount? _currentUser;
  List<drive.File> _recordings = [];
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveReadonlyScope],
  );

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
      });
      if (_currentUser != null) {
        _loadRecordings();
      }
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      debugPrint('Sign in error: $error');
    }
  }

  Future<void> _handleSignOut() => _googleSignIn.disconnect();

  Future<void> _loadRecordings() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
    });

    final authHeaders = await _currentUser!.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    try {
      final fileList = await driveApi.files.list(
        q: "mimeType='video/mp4' and trashed=false", // Example query: find mp4 videos
        spaces: 'drive',
        $fields: 'files(id, name, thumbnailLink)',
      );

      setState(() {
        _recordings = fileList.files ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading recordings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleSignOut,
            ),
        ],
      ),
      body: _currentUser != null ? _buildRecordingsList() : _buildLoginButton(),
    );
  }

  Widget _buildLoginButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _handleSignIn,
        icon: const Icon(Icons.login),
        label: const Text('Sign in with Google'),
      ),
    );
  }

  Widget _buildRecordingsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recordings.isEmpty) {
      return const Center(child: Text('No recordings found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadRecordings,
      child: ListView.builder(
        itemCount: _recordings.length,
        itemBuilder: (context, index) {
          final recording = _recordings[index];
          return ListTile(
            leading: recording.thumbnailLink != null
                ? Image.network(recording.thumbnailLink!)
                : const Icon(Icons.movie),
            title: Text(recording.name ?? 'Untitled'),
            onTap: () {
              // Logic to play the recording
            },
          );
        },
      ),
    );
  }
}
