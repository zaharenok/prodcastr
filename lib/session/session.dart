import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/kaneo_client.dart';
import '../api/models.dart';

const _storage = FlutterSecureStorage();

class SessionState {
  final String? instanceUrl;
  final String? token;
  final KaneoUser? user;
  final bool loading;

  SessionState({this.instanceUrl, this.token, this.user, this.loading = false});

  bool get isAuthenticated => token != null && user != null;
  bool get hasUrl => instanceUrl != null && instanceUrl!.isNotEmpty;

  SessionState copyWith({
    String? instanceUrl,
    String? token,
    KaneoUser? user,
    bool? loading,
  }) {
    return SessionState(
      instanceUrl: instanceUrl ?? this.instanceUrl,
      token: token ?? this.token,
      user: user ?? this.user,
      loading: loading ?? this.loading,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState()) {
    _load();
  }

  Future<void> _load() async {
    final url = await _storage.read(key: 'instance_url');
    final token = await _storage.read(key: 'token');
    final userJson = await _storage.read(key: 'user_json');
    if (url != null && token != null && userJson != null) {
      final user =
          KaneoUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      state = SessionState(instanceUrl: url, token: token, user: user);
    }
  }

  Future<bool> connect(String url) async {
    state = state.copyWith(loading: true);
    try {
      final client = KaneoClient(url);
      final resp =
          await client.dio.get('/health').timeout(const Duration(seconds: 5));
      if (resp.data is Map && resp.data['status'] == 'ok') {
        state = state.copyWith(instanceUrl: url, loading: false);
        await _storage.write(key: 'instance_url', value: url);
        return true;
      }
      state = state.copyWith(loading: false);
      return false;
    } catch (_) {
      state = state.copyWith(loading: false);
      return false;
    }
  }

  Future<String?> signIn(String email, String password) async {
    if (state.instanceUrl == null) return 'No instance URL';
    state = state.copyWith(loading: true);
    try {
      final client = KaneoClient(state.instanceUrl!);
      final resp = await client.signIn(email, password);
      if (resp.containsKey('token')) {
        final token = resp['token'] as String;
        final userData = resp['user'] as Map<String, dynamic>;
        final user = KaneoUser.fromJson(userData);
        state = state.copyWith(
            instanceUrl: state.instanceUrl,
            token: token,
            user: user,
            loading: false);
        await _storage.write(key: 'token', value: token);
        await _storage.write(key: 'user_json', value: jsonEncode(user.toJson()));
        return null;
      }
      state = state.copyWith(loading: false);
      return resp['message'] as String? ?? 'Ошибка входа';
    } catch (e) {
      state = state.copyWith(loading: false);
      return 'Ошибка сети: $e';
    }
  }

  Future<void> signOut() async {
    await _storage.deleteAll();
    state = SessionState();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});

/// Provides a configured KaneoClient for the current session.
final kaneoClientProvider = Provider<KaneoClient?>((ref) {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated || session.instanceUrl == null) return null;
  final client = KaneoClient(session.instanceUrl!);
  client.setToken(session.token);
  return client;
});
