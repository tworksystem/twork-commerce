import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/point_transaction.dart';
import '../services/point_service.dart';
import '../utils/logger.dart';
import '../services/connectivity_service.dart';
import '../services/point_sync_telemetry.dart';

/// Point provider for managing point state
/// Handles point balance, transactions, and UI updates
class PointProvider with ChangeNotifier {
  PointBalance? _balance;
  List<PointTransaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  static const String _balanceKey = 'user_point_balance';
  StreamSubscription<PointSyncEvent>? _syncSubscription;
  String? _currentUserId;
  bool _hasLoadedForCurrentUser = false;

  // Getters
  PointBalance? get balance => _balance;
  List<PointTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentBalance => _balance?.currentBalance ?? 0;
  bool get hasPoints => currentBalance > 0;
  String get formattedBalance => _balance?.formattedBalance ?? '0 points';

  PointProvider() {
    _initialize();
    _syncSubscription = PointSyncTelemetry.events.listen(_handleSyncEvent);
  }

  /// Initialize point provider
  Future<void> _initialize() async {
    _setLoading(true);
    try {
      // Load cached balance first
      await _loadCachedBalance();
      _setLoading(false);
    } catch (e) {
      Logger.error('Error initializing point provider: $e',
          tag: 'PointProvider', error: e);
      _setLoading(false);
    }
  }

  /// Handle authentication state changes
  /// Automatically loads balance when user becomes authenticated
  Future<void> handleAuthStateChange({
    required bool isAuthenticated,
    String? userId,
  }) async {
    if (isAuthenticated && userId != null) {
      // Only load if this is a new user or we haven't loaded for this user yet
      if (_currentUserId != userId || !_hasLoadedForCurrentUser) {
        _currentUserId = userId;
        Logger.info('User authenticated, loading point balance for user: $userId',
            tag: 'PointProvider');
        await loadBalance(userId);
        _hasLoadedForCurrentUser = true;
      }
    } else {
      // User logged out - clear state
      _currentUserId = null;
      _hasLoadedForCurrentUser = false;
      _balance = null;
      _transactions = [];
      notifyListeners();
      Logger.info('User logged out, cleared point data', tag: 'PointProvider');
    }
  }

  void _handleSyncEvent(PointSyncEvent event) {
    if (event.userFacing && event.userMessage != null) {
      _setError(event.userMessage!);
    }
  }

  /// Load point balance for user
  /// If forceRefresh is true, will reload even if already loaded for this user
  Future<void> loadBalance(String userId, {bool forceRefresh = false}) async {
    // Skip if already loaded for this user and not forcing refresh
    if (!forceRefresh && _currentUserId == userId && _hasLoadedForCurrentUser && _balance != null) {
      Logger.info('Balance already loaded for user $userId, skipping',
          tag: 'PointProvider');
      return;
    }

    _setLoading(true);
    _clearError();
    _currentUserId = userId;

    try {
      // Try to load from API if online
      final connectivityService = ConnectivityService();
      if (connectivityService.isConnected) {
        // Load balance from API first (source of truth)
        final balance = await PointService.getPointBalance(userId);
        if (balance != null) {
          _balance = balance;
          _hasLoadedForCurrentUser = true;
          notifyListeners();
          Logger.info(
              'Point balance loaded from API: ${balance.currentBalance} points',
              tag: 'PointProvider');

          // Cache the balance
          await _cacheBalance(balance);

          // Sync local transactions in background (non-blocking)
          PointService.syncAllTransactions(userId).catchError((e) {
            Logger.warning('Error syncing transactions: $e',
                tag: 'PointProvider', error: e);
            return false;
          });
        } else {
          // If API fails, try cache
          await _loadCachedBalance();
        }
      } else {
        // Load from cache if offline
        await _loadCachedBalance();
      }
    } catch (e, stackTrace) {
      Logger.error('Error loading point balance: $e',
          tag: 'PointProvider', error: e, stackTrace: stackTrace);
      _setError('Failed to load point balance');
      // Try to load from cache on error
      await _loadCachedBalance();
    } finally {
      _setLoading(false);
    }
  }

  /// Load point transactions for user
  Future<void> loadTransactions(String userId,
      {int page = 1, int perPage = 20}) async {
    _setLoading(true);
    _clearError();

    try {
      final transactions = await PointService.getPointTransactions(userId,
          page: page, perPage: perPage);
      _transactions = transactions;
      notifyListeners();
      Logger.info('Loaded ${transactions.length} point transactions',
          tag: 'PointProvider');
    } catch (e, stackTrace) {
      Logger.error('Error loading point transactions: $e',
          tag: 'PointProvider', error: e, stackTrace: stackTrace);
      _setError('Failed to load point transactions');
    } finally {
      _setLoading(false);
    }
  }

  /// Earn points (e.g., on purchase, signup, review)
  Future<bool> earnPoints({
    required String userId,
    required int points,
    required PointTransactionType type,
    String? description,
    String? orderId,
    DateTime? expiresAt,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await PointService.earnPoints(
        userId: userId,
        points: points,
        type: type,
        description: description,
        orderId: orderId,
        expiresAt: expiresAt,
      );

      if (success) {
        // Reload balance and transactions
        await loadBalance(userId);
        await loadTransactions(userId);
        Logger.info('Points earned successfully: $points points',
            tag: 'PointProvider');
      } else {
        _setError('Failed to earn points');
      }

      return success;
    } catch (e, stackTrace) {
      Logger.error('Error earning points: $e',
          tag: 'PointProvider', error: e, stackTrace: stackTrace);
      _setError('Failed to earn points');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Redeem points (e.g., for discount)
  Future<bool> redeemPoints({
    required String userId,
    required int points,
    String? description,
    String? orderId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Check if user has enough points
      if (currentBalance < points) {
        _setError('Insufficient points. You have $currentBalance points.');
        return false;
      }

      final success = await PointService.redeemPoints(
        userId: userId,
        points: points,
        description: description,
        orderId: orderId,
        waitForSync: orderId != null, // Wait for sync if order ID is provided
      );

      if (success) {
        // Reload balance and transactions
        await loadBalance(userId);
        await loadTransactions(userId);
        Logger.info('Points redeemed successfully: $points points',
            tag: 'PointProvider');
      } else {
        _setError('Failed to redeem points');
      }

      return success;
    } catch (e, stackTrace) {
      Logger.error('Error redeeming points: $e',
          tag: 'PointProvider', error: e, stackTrace: stackTrace);
      _setError('Failed to redeem points');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Calculate discount from points
  double calculateDiscountFromPoints(int points) {
    return PointService.calculateDiscountFromPoints(points);
  }

  /// Calculate points needed for discount
  int calculatePointsForDiscount(double discountAmount) {
    return PointService.calculatePointsForDiscount(discountAmount);
  }

  /// Check if user has enough points
  bool hasEnoughPoints(int requiredPoints) {
    return currentBalance >= requiredPoints;
  }

  /// Load cached balance from local storage
  Future<void> _loadCachedBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final balanceJson = prefs.getString(_balanceKey);

      if (balanceJson != null) {
        final balanceData = json.decode(balanceJson);
        _balance = PointBalance.fromJson(balanceData);
        notifyListeners();
        Logger.info(
            'Cached point balance loaded: ${_balance?.currentBalance} points',
            tag: 'PointProvider');
      }
    } catch (e) {
      Logger.error('Error loading cached balance: $e',
          tag: 'PointProvider', error: e);
    }
  }

  /// Cache balance to local storage
  Future<void> _cacheBalance(PointBalance balance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final balanceJson = json.encode(balance.toJson());
      await prefs.setString(_balanceKey, balanceJson);
      Logger.info('Point balance cached to local storage', tag: 'PointProvider');
    } catch (e) {
      Logger.error('Error caching balance: $e',
          tag: 'PointProvider', error: e);
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }
}
