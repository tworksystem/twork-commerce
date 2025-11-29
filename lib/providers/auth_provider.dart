import 'package:flutter/foundation.dart';
import '../models/auth_user.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider with ChangeNotifier {
  static final AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;

  AuthStatus _status = AuthStatus.initial;
  AuthUser? _user;
  String? _errorMessage;
  bool _isLoading = false;
  bool _hasInitialized = false;

  // Getters
  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;

  AuthProvider._internal() {
    _initializeAuth();
  }

  /// Initialize authentication state
  Future<void> _initializeAuth() async {
    if (_hasInitialized && _status != AuthStatus.initial) {
      return;
    }

    _hasInitialized = true;
    _setLoading(true);

    try {
      final storedUser = await AuthService.getStoredUser();
      final isLoggedIn = await AuthService.isLoggedIn();

      if (isLoggedIn && storedUser != null) {
        print('DEBUG: _initializeAuth - User is logged in, verifying token...');
        print(
            'DEBUG: _initializeAuth - Stored user: ${storedUser.firstName} ${storedUser.lastName}, Phone: ${storedUser.phone}');

        // Use stored user immediately to avoid blocking on network
        _user = storedUser;
        _status = AuthStatus.authenticated;
        _setLoading(false); // Set loading to false early to allow navigation

        // Verify token in background (non-blocking) - only if online
        try {
          // Check connectivity before making network call
          final connectivityService = _getConnectivityService();
          if (connectivityService != null && connectivityService.isConnected) {
            // Try to verify token with timeout (non-blocking)
            final currentUser = await AuthService.getCurrentUser().timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                print(
                    'DEBUG: _initializeAuth - Token verification timeout, using stored user');
                return null;
              },
            ).catchError((e) {
              print(
                  'DEBUG: _initializeAuth - Token verification error: $e, using stored user');
              return null;
            });

            if (currentUser != null) {
              print(
                  'DEBUG: _initializeAuth - Token is valid, user authenticated');
              print(
                  'DEBUG: _initializeAuth - Current user: ${currentUser.firstName} ${currentUser.lastName}, Phone: ${currentUser.phone}');
              _user = currentUser;
              _status = AuthStatus.authenticated;
              notifyListeners();
            } else {
              print(
                  'DEBUG: _initializeAuth - Token verification failed, but keeping user logged in with stored data');
            }
          } else {
            print('DEBUG: _initializeAuth - Offline, using stored user data');
          }
        } catch (e) {
          print(
              'DEBUG: _initializeAuth - Background token verification error: $e, using stored user');
          // Keep using stored user on error
        }
      } else {
        print('DEBUG: _initializeAuth - User not logged in or no stored user');
        _status = AuthStatus.unauthenticated;
        _setLoading(false);
      }
    } catch (e) {
      print('DEBUG: _initializeAuth - Error during initialization: $e');
      // On error, try to use stored user data to keep user logged in
      // This prevents auto-logout on network errors or temporary issues
      try {
        final storedUser = await AuthService.getStoredUser();
        final isLoggedIn = await AuthService.isLoggedIn();

        if (isLoggedIn && storedUser != null) {
          print(
              'DEBUG: _initializeAuth - Error occurred but keeping user logged in with stored data');
          _user = storedUser;
          _status = AuthStatus.authenticated;
        } else {
          _setError('Failed to initialize authentication: $e');
          _status = AuthStatus.unauthenticated;
        }
      } catch (fallbackError) {
        print('DEBUG: _initializeAuth - Fallback also failed: $fallbackError');
        _setError('Failed to initialize authentication: $e');
        _status = AuthStatus.unauthenticated;
      } finally {
        _setLoading(false);
      }
    }
  }

  /// Get connectivity service
  ConnectivityService? _getConnectivityService() {
    try {
      return ConnectivityService();
    } catch (e) {
      return null;
    }
  }

  /// Login user
  Future<AuthResponse> login(LoginRequest request) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await AuthService.login(request);

      if (response.success && response.user != null) {
        _user = response.user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return response;
      } else {
        _setError(response.message);
        _status = AuthStatus.unauthenticated;
        return response;
      }
    } catch (e) {
      final errorMsg = 'Login failed: $e';
      _setError(errorMsg);
      _status = AuthStatus.error;
      return AuthResponse.error(message: errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Register user
  Future<AuthResponse> register(RegisterRequest request) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await AuthService.register(request);

      if (response.success && response.user != null) {
        _user = response.user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return response;
      } else {
        _setError(response.message);
        _status = AuthStatus.unauthenticated;
        return response;
      }
    } catch (e) {
      final errorMsg = 'Registration failed: $e';
      _setError(errorMsg);
      _status = AuthStatus.error;
      return AuthResponse.error(message: errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Update user profile
  Future<AuthResponse> updateProfile(AuthUser updatedUser) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await AuthService.updateProfile(updatedUser);

      if (response.success && response.user != null) {
        _user = response.user;
        notifyListeners();
        return response;
      } else {
        _setError(response.message);
        return response;
      }
    } catch (e) {
      final errorMsg = 'Profile update failed: $e';
      _setError(errorMsg);
      return AuthResponse.error(message: errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Update WooCommerce billing details for the current user
  Future<AuthResponse> updateBilling({
    String? firstName,
    String? lastName,
    String? phone,
    Map<String, dynamic>? billingExtra,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await AuthService.updateBillingForCurrentUser(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        billingExtra: billingExtra,
      );

      if (response.success && response.user != null) {
        _user = response.user;
        notifyListeners();
      } else if (!response.success) {
        _setError(response.message);
      }

      return response;
    } catch (e) {
      final errorMsg = 'Billing update failed: $e';
      _setError(errorMsg);
      return AuthResponse.error(message: errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Change password
  Future<AuthResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await AuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!response.success) {
        _setError(response.message);
      }

      return response;
    } catch (e) {
      final errorMsg = 'Password change failed: $e';
      _setError(errorMsg);
      return AuthResponse.error(message: errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Forgot password
  Future<AuthResponse> forgotPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await AuthService.forgotPassword(email);

      if (!response.success) {
        _setError(response.message);
      }

      return response;
    } catch (e) {
      final errorMsg = 'Password reset failed: $e';
      _setError(errorMsg);
      return AuthResponse.error(message: errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  /// Logout user
  Future<void> logout() async {
    _setLoading(true);

    try {
      await AuthService.logout();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Logout failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh user data
  Future<void> refreshUser() async {
    if (!isAuthenticated) return;

    try {
      print('DEBUG: Refreshing user data...');
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser != null) {
        print(
            'DEBUG: Refreshed user data - Name: ${currentUser.firstName} ${currentUser.lastName}, Phone: ${currentUser.phone}');
        _user = currentUser;
        notifyListeners();
        print('DEBUG: Notified listeners of user data update');
      } else {
        print('DEBUG: Failed to get current user, but keeping user logged in');
        // Don't logout on refresh failure - user might still be authenticated
        // Only logout if explicitly called or during initialization
      }
    } catch (e) {
      print('DEBUG: Error refreshing user data: $e');
      _setError('Failed to refresh user data: $e');
      // Don't logout on refresh error - user might still be authenticated
    }
  }

  /// Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status =
          _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    }
  }
}
