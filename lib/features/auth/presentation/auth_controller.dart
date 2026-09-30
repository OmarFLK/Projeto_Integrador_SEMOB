import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthError { requiredFields, invalidCredentials, sessionExpired }

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.rememberAccess = true,
    this.error,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final bool rememberAccess;
  final AuthError? error;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? rememberAccess,
    AuthError? error,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      rememberAccess: rememberAccess ?? this.rememberAccess,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<bool> signIn(String identifier, String password) async {
    if (identifier.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(error: AuthError.requiredFields);
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final valid =
        identifier.trim().toLowerCase() == 'admin@semob.sp.gov.br' &&
        password == 'semob2026';
    state = state.copyWith(
      isAuthenticated: valid,
      isLoading: false,
      error: valid ? null : AuthError.invalidCredentials,
      clearError: valid,
    );
    return valid;
  }

  void setRememberAccess(bool value) =>
      state = state.copyWith(rememberAccess: value);

  void showExpiredSession() =>
      state = state.copyWith(error: AuthError.sessionExpired);

  void signOut() => state = const AuthState();
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
