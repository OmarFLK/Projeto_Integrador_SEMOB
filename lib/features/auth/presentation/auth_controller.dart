import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../../../services/api_client.dart';

enum AuthError {
  requiredFields,
  invalidCredentials,
  sessionExpired,
  serviceUnavailable,
}

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.rememberAccess = true,
    this.error,
    this.initializing = false,
  });
  final AppUser? user;
  final bool isLoading, rememberAccess, initializing;
  final AuthError? error;
  bool get isAuthenticated => user != null;
}

abstract class AuthRepository {
  Future<AppUser?> restore();
  Future<AppUser> login(String identifier, String password, bool remember);
  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.client);
  final ApiClient client;
  @override
  Future<AppUser?> restore() async {
    try {
      final response = await client.dio.get<Map<String, dynamic>>('auth/me');
      return AppUser.fromJson(response.data!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> login(
    String identifier,
    String password,
    bool remember,
  ) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      'auth/login',
      data: {
        'identifier': identifier,
        'password': password,
        'remember': remember,
      },
    );
    client.token = response.data!['token'] as String;
    return AppUser.fromJson(
      Map<String, dynamic>.from(response.data!['user'] as Map),
    );
  }

  @override
  Future<void> logout() async {
    await client.dio.post<void>('auth/logout');
    client.token = null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final client = ref.watch(apiClientProvider);
    client.onUnauthorized = expire;
    Future.microtask(_restore);
    return const AuthState(initializing: true);
  }

  Future<void> _restore() async {
    final user = await ref.read(authRepositoryProvider).restore();
    if (ref.mounted && state.initializing) state = AuthState(user: user);
  }

  Future<bool> signIn(String identifier, String password) async {
    if (identifier.trim().isEmpty || password.isEmpty) {
      state = AuthState(
        rememberAccess: state.rememberAccess,
        error: AuthError.requiredFields,
      );
      return false;
    }
    final remember = state.rememberAccess;
    state = AuthState(isLoading: true, rememberAccess: remember);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(identifier.trim(), password, remember);
      if (!ref.mounted) return false;
      state = AuthState(user: user, rememberAccess: remember);
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = AuthState(
          rememberAccess: remember,
          error: apiError(e).contains('Credenciais')
              ? AuthError.invalidCredentials
              : AuthError.serviceUnavailable,
        );
      }
      return false;
    }
  }

  void setRememberAccess(bool value) => state = AuthState(
    user: state.user,
    rememberAccess: value,
    error: state.error,
  );
  void showExpiredSession() => expire();
  void expire() {
    if (!ref.mounted) return;
    ref.read(apiClientProvider).token = null;
    if (!state.initializing) {
      state = const AuthState(error: AuthError.sessionExpired);
    }
  }

  Future<bool> signOut() async {
    try {
      await ref.read(authRepositoryProvider).logout();
      if (ref.mounted) state = const AuthState();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
