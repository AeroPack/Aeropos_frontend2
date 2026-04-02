import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/sync_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/models/user.dart';
import '../../../../core/models/company.dart';

enum AuthStatus { authenticated, unauthenticated, loading, companySelection }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final User? user;
  final Company? company; // Currently active company
  final List<Company>? companies; // For company selection or "My Companies" list
  final String? pendingEmail; // Email used for login (needed to retry with companyId)
  final String? pendingPassword; // Password used for login
  final String? pendingGoogleIdToken; // For Google login retry
  final String? pendingGoogleAccessToken; // For Google login retry

  AuthState({
    required this.status,
    this.errorMessage,
    this.user,
    this.company,
    this.companies,
    this.pendingEmail,
    this.pendingPassword,
    this.pendingGoogleIdToken,
    this.pendingGoogleAccessToken,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(User user, Company? company) =>
      AuthState(status: AuthStatus.authenticated, user: user, company: company);
  factory AuthState.unauthenticated([String? error]) =>
      AuthState(status: AuthStatus.unauthenticated, errorMessage: error);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.companySelection({
    required List<Company> companies,
    String? email,
    String? password,
    String? googleIdToken,
    String? googleAccessToken,
  }) =>
      AuthState(
        status: AuthStatus.companySelection,
        companies: companies,
        pendingEmail: email,
        pendingPassword: password,
        pendingGoogleIdToken: googleIdToken,
        pendingGoogleAccessToken: googleAccessToken,
      );

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    User? user,
    Company? company,
    List<Company>? companies,
    String? pendingEmail,
    String? pendingPassword,
    String? pendingGoogleIdToken,
    String? pendingGoogleAccessToken,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      user: user ?? this.user,
      company: company ?? this.company,
      companies: companies ?? this.companies,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      pendingPassword: pendingPassword ?? this.pendingPassword,
      pendingGoogleIdToken: pendingGoogleIdToken ?? this.pendingGoogleIdToken,
      pendingGoogleAccessToken:
          pendingGoogleAccessToken ?? this.pendingGoogleAccessToken,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final SyncService _syncService;

  AuthController(this._authRepository, this._syncService)
    : super(AuthState.initial()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = AuthState.loading();
    try {
      final isLoggedIn = await _authRepository.checkAuthStatus();
      if (isLoggedIn) {
        await _completeLogin();
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (e) {
      state = AuthState.unauthenticated(_extractErrorMessage(e, "Check authentication failed"));
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final response = await _authRepository.login(email, password);

      // Check if multi-company selection is required
      if (response['requiresCompanySelection'] == true) {
        final companiesList = (response['companies'] as List)
            .map((c) => Company.fromJson(c))
            .toList();
        state = AuthState.companySelection(
          companies: companiesList,
          email: email,
          password: password,
        );
        return;
      }

      // Single company — proceed with login
      await _completeLogin();
    } catch (e) {
      state = AuthState.unauthenticated(_extractErrorMessage(e, "Login failed"));
    }
  }

  /// Select a company after multi-company login prompt
  Future<void> selectCompany(int companyId) async {
    final email = state.pendingEmail;
    final password = state.pendingPassword;
    final googleIdToken = state.pendingGoogleIdToken;
    final googleAccessToken = state.pendingGoogleAccessToken;

    state = AuthState.loading();
    try {
      if (email != null && password != null) {
        // Re-login with specific companyId
        await _authRepository.login(email, password, companyId: companyId);
      } else if (googleIdToken != null || googleAccessToken != null) {
        // Re-do Google login with specific companyId
        await _authRepository.googleLogin(
          idToken: googleIdToken,
          accessToken: googleAccessToken,
          companyId: companyId,
        );
      } else {
        throw Exception("No pending credentials for company selection");
      }

      await _completeLogin();
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, "Company selection failed"),
      );
    }
  }

  /// Switch to a different company (in-app, already authenticated)
  Future<void> switchCompany(int companyId) async {
    state = AuthState.loading();
    try {
      await _authRepository.switchCompany(companyId);
      await ServiceLocator.instance.tenantService.setTenantId(companyId);

      // Clear local data and re-sync for the new company
      final database = ServiceLocator.instance.database;
      await database.clearAllData();

      await _syncService.pull();

      // Also fetch company info if not returned by getCurrentUser (or handle both)
      // For now, let's just re-run _completeLogin which does full refresh
      await _completeLogin();
    } catch (e) {
      // On failure, try to restore previous state
      state = state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: _extractErrorMessage(e, "Company switch failed"),
      );
    }
  }

  /// Refresh the list of companies the user is part of
  Future<void> refreshCompanies() async {
    // Only refresh if authenticated
    if (state.status != AuthStatus.authenticated) return;

    try {
      final companies = await _authRepository.getMyCompanies();
      state = state.copyWith(companies: companies);
    } catch (e) {
      // Error refreshing companies
    }
  }

  /// Create a new company (Admin only)
  Future<bool> createCompany({
    required String businessName,
    String? businessAddress,
    String? companyPhone,
    String? companyEmail,
  }) async {
    final prevState = state;
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _authRepository.createCompany({
        'businessName': businessName,
        'businessAddress': businessAddress,
        'companyPhone': companyPhone,
        'companyEmail': companyEmail,
      });

      state = prevState; // Restore previous state (authenticated)
      await refreshCompanies(); // Refresh the list
      return true;
    } catch (e) {
      state = prevState.copyWith(
        errorMessage: _extractErrorMessage(e, "Failed to create company"),
      );
      return false;
    }
  }

  Future<void> signup(Map<String, dynamic> data) async {
    state = AuthState.loading();
    try {
      await _authRepository.signup(data);
      await _completeLogin();
    } catch (e) {
      state = AuthState.unauthenticated(_extractErrorMessage(e, "Signup failed"));
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthState.loading();
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        state = AuthState.unauthenticated();
        return;
      }


      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null && googleAuth.accessToken == null) {
        throw Exception("Failed to retrieve Google Sign-In Tokens");
      }

      final response = await _authRepository.googleLogin(
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      // Check if multi-company selection is required
      if (response['requiresCompanySelection'] == true) {
        final companiesList = (response['companies'] as List)
            .map((c) => Company.fromJson(c))
            .toList();
        state = AuthState.companySelection(
          companies: companiesList,
          googleIdToken: idToken,
          googleAccessToken: googleAuth.accessToken,
        );
        return;
      }

      await _completeLogin();
    } catch (e) {
      if (e.toString().contains("canceled")) {
        state = AuthState.unauthenticated();
        return;
      }
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, "Google Sign-In failed"),
      );
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    await _authRepository.logout();
    await GoogleSignIn().signOut();
    state = AuthState.unauthenticated();
  }

  Future<void> forgotPassword(String email) async {
    state = AuthState.loading();
    try {
      await _authRepository.forgotPassword(email);
      state = AuthState.unauthenticated(
        "Password reset link sent to your email",
      );
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, "Failed to send reset link"),
      );
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    state = AuthState.loading();
    try {
      await _authRepository.resendVerificationEmail(email);
      state = AuthState.unauthenticated(
        "Verification email sent! Please check your inbox.",
      );
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, "Failed to resend verification email"),
      );
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    state = AuthState.loading();
    try {
      await _authRepository.resetPassword(token, newPassword);
      state = AuthState.unauthenticated(
        "Password reset successfully. Please login.",
      );
    } catch (e) {
      state = AuthState.unauthenticated(
        _extractErrorMessage(e, "Failed to reset password"),
      );
    }
  }

  Future<void> verifyEmail(String token) async {
    state = AuthState.loading();
    try {
      await _authRepository.verifyEmail(token);
      // Update state if already logged in (pending verification)
      if (state.user != null) {
        await _completeLogin();
      } else {
        state = AuthState.unauthenticated(
          "Email verified successfully! Please login.",
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _extractErrorMessage(e, "Verification failed. The link may be expired or invalid."),
      );
    }
  }

  /// Complete login flow: sync data and load user
  Future<void> _completeLogin() async {
    await _syncService.pull();

    final response = await ServiceLocator.instance.authRemoteDataSource.getCurrentUser();
    final user = User.fromJson(response['employee'] ?? response);
    final company =
        response['company'] != null ? Company.fromJson(response['company']) : null;

    final companies = await _authRepository.getMyCompanies();

    if (company != null) {
      await ServiceLocator.instance.tenantService.setTenantId(company.id);
    }

    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
      company: company,
      companies: companies,
    );
  }

  /// Extract error message from various exception types
  String _extractErrorMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.response?.data is Map && e.response!.data['error'] != null) {
        return e.response!.data['error'].toString();
      }

      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        return "Session expired. Please log in again.";
      } else if (statusCode == 403) {
        return "You do not have permission to perform this action.";
      } else if (statusCode == 500) {
        return "Internal server error. Please try again later.";
      }

      return e.message ?? fallback;
    }
    return "$fallback: ${e.toString()}";
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      ServiceLocator.instance.authRepository,
      ServiceLocator.instance.syncService,
    );
  },
);
