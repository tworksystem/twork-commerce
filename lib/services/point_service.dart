import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/point_transaction.dart';
import '../utils/app_config.dart';
import '../utils/logger.dart';
import '../utils/network_utils.dart';
import 'point_sync_telemetry.dart';
import 'offline_queue_service.dart';
import 'secure_prefs.dart';

/// Point service for managing user points
/// Handles API calls and local storage for offline support
class PointService {
  static const String _balanceKey = 'user_point_balance';
  static const String _transactionsKey = 'user_point_transactions';
  static bool _queueRegistered = false;
  static final SecurePrefs _securePrefs = SecurePrefs.instance;

  // Point earning rates (configurable)
  static const double pointsPerDollar = 1.0; // 1 point per $1 spent
  static const int signupBonus = 100; // Points for signing up
  static const int reviewBonus = 50; // Points for leaving a review
  static const int referralBonus = 500; // Points for referring a friend
  static const int birthdayBonus = 200; // Points for birthday

  // Point redemption rates
  static const double pointsPerDollarDiscount =
      100.0; // 100 points = $1 discount

  // Point redemption limits
  static const int minRedemptionPoints = 100; // Minimum points to redeem
  static const int maxRedemptionPercent =
      50; // Max 50% of order total can be paid with points

  // Point expiration settings
  static const int pointsExpirationDays = 365; // Points expire after 1 year
  static const int expirationWarningDays =
      30; // Warn when expiring within 30 days

  /// Get WooCommerce authentication
  static String _getWooCommerceAuth() {
    // Use WooCommerce API credentials
    return base64Encode(
        utf8.encode('${AppConfig.consumerKey}:${AppConfig.consumerSecret}'));
  }

  /// Get user's point balance from API
  static Future<PointBalance?> getPointBalance(String userId) async {
    try {
      // Use custom WordPress REST endpoint
      final response = await NetworkUtils.executeRequest(
        () => http.get(
          Uri.parse(
              '${AppConfig.backendUrl}/wp-json/twork/v1/points/balance/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic ${_getWooCommerceAuth()}',
          },
        ),
        context: 'getPointBalance',
      );

      if (NetworkUtils.isValidResponse(response)) {
        final data = json.decode(response!.body);

        final balance = PointBalance(
          userId: userId,
          currentBalance: (data['current_balance'] as num?)?.toInt() ?? 0,
          lifetimeEarned: (data['lifetime_earned'] as num?)?.toInt() ?? 0,
          lifetimeRedeemed: (data['lifetime_redeemed'] as num?)?.toInt() ?? 0,
          lifetimeExpired: (data['lifetime_expired'] as num?)?.toInt() ?? 0,
          lastUpdated: data['last_updated'] != null
              ? DateTime.parse(data['last_updated'])
              : DateTime.now(),
        );

        // Cache balance locally
        await _saveBalanceToStorage(balance);

        Logger.info(
            'Point balance loaded from API: ${balance.currentBalance} points',
            tag: 'PointService');
        return balance;
      }

      return null;
    } catch (e, stackTrace) {
      Logger.error('Error getting point balance: $e',
          tag: 'PointService', error: e, stackTrace: stackTrace);
      // Return cached balance on error
      return await getCachedBalance(userId);
    }
  }

  /// Get point transactions from API
  static Future<List<PointTransaction>> getPointTransactions(String userId,
      {int page = 1, int perPage = 20}) async {
    try {
      // Use custom WordPress REST endpoint
      final uri = Uri.parse(
              '${AppConfig.backendUrl}/wp-json/twork/v1/points/transactions/$userId')
          .replace(queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      });

      final response = await NetworkUtils.executeRequest(
        () => http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic ${_getWooCommerceAuth()}',
          },
        ),
        context: 'getPointTransactions',
      );

      if (NetworkUtils.isValidResponse(response)) {
        final data = json.decode(response!.body);
        final transactionsData = data['transactions'] as List<dynamic>? ?? [];

        final transactions = transactionsData
            .map((item) =>
                PointTransaction.fromJson(item as Map<String, dynamic>))
            .toList();

        // Cache transactions locally
        await _cacheTransactions(userId, transactions);

        Logger.info('Loaded ${transactions.length} point transactions from API',
            tag: 'PointService');
        return transactions;
      }

      // Fallback to cached transactions
      return await getCachedTransactions(userId);
    } catch (e, stackTrace) {
      Logger.error('Error getting point transactions: $e',
          tag: 'PointService', error: e, stackTrace: stackTrace);
      return await getCachedTransactions(userId);
    }
  }

  /// Earn points (e.g., on purchase, signup, review)
  static Future<bool> earnPoints({
    required String userId,
    required int points,
    required PointTransactionType type,
    String? description,
    String? orderId,
    DateTime? expiresAt,
  }) async {
    try {
      // Check for duplicate transaction (same order ID and type within last 5 minutes)
      if (orderId != null && type == PointTransactionType.earn) {
        final existingTransactions = await getCachedTransactions(userId);
        final now = DateTime.now();
        final fiveMinutesAgo = now.subtract(Duration(minutes: 5));

        final duplicateExists = existingTransactions.any((t) {
          return t.type == PointTransactionType.earn &&
              t.orderId == orderId &&
              t.points == points &&
              t.createdAt.isAfter(fiveMinutesAgo);
        });

        if (duplicateExists) {
          Logger.warning(
              'Duplicate point earning prevented for order: $orderId',
              tag: 'PointService');
          return false; // Don't create duplicate
        }
      }

      // Create transaction
      final transaction = PointTransaction(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        type: type,
        points: points,
        description: description,
        orderId: orderId,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      // Save transaction locally first
      await _saveTransactionToStorage(transaction);

      // Update balance locally
      final currentBalance = await getCachedBalance(userId);
      if (currentBalance != null) {
        final updatedBalance = PointBalance(
          userId: userId,
          currentBalance: currentBalance.currentBalance + points,
          lifetimeEarned: currentBalance.lifetimeEarned + points,
          lifetimeRedeemed: currentBalance.lifetimeRedeemed,
          lifetimeExpired: currentBalance.lifetimeExpired,
          lastUpdated: DateTime.now(),
        );
        await _saveBalanceToStorage(updatedBalance);
      }

      // Try to sync with backend (non-blocking)
      _syncPointsToBackend(userId, transaction).catchError((e) {
        Logger.error('Error syncing points to backend: $e',
            tag: 'PointService', error: e);
      });

      Logger.info('Points earned: $points points', tag: 'PointService');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Error earning points: $e',
          tag: 'PointService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Redeem points (e.g., for discount)
  /// If waitForSync is true, waits for backend sync to complete (important for order creation)
  static Future<bool> redeemPoints({
    required String userId,
    required int points,
    String? description,
    String? orderId,
    bool waitForSync = false,
  }) async {
    try {
      // Check if user has enough points
      final currentBalance = await getCachedBalance(userId);
      if (currentBalance == null || currentBalance.currentBalance < points) {
        Logger.warning(
            'Insufficient points for redemption. Current: ${currentBalance?.currentBalance ?? 0}, Required: $points',
            tag: 'PointService');
        return false;
      }

      // Create transaction
      final transaction = PointTransaction(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        type: PointTransactionType.redeem,
        points: points,
        description: description,
        orderId: orderId,
        createdAt: DateTime.now(),
      );

      // If orderId is provided and waitForSync is true, sync to backend first
      // This ensures points are deducted on server before order completion
      if (orderId != null && waitForSync) {
        try {
          final syncSuccess =
              await _syncPointsToBackendSync(userId, transaction);
          if (!syncSuccess) {
            Logger.warning(
                'Backend sync failed for point redemption, but continuing with local update',
                tag: 'PointService');
            await _enqueuePointAdjustment(userId, transaction);
            // Continue with local update even if sync fails
          }
        } catch (e) {
          Logger.error('Error syncing points to backend (blocking): $e',
              tag: 'PointService', error: e);
          await _enqueuePointAdjustment(userId, transaction);
          // Continue with local update
        }
      }

      // Save transaction locally
      await _saveTransactionToStorage(transaction);

      // Update balance locally
      final updatedBalance = PointBalance(
        userId: userId,
        currentBalance: currentBalance.currentBalance - points,
        lifetimeEarned: currentBalance.lifetimeEarned,
        lifetimeRedeemed: currentBalance.lifetimeRedeemed + points,
        lifetimeExpired: currentBalance.lifetimeExpired,
        lastUpdated: DateTime.now(),
      );
      await _saveBalanceToStorage(updatedBalance);

      // Sync with backend (non-blocking if not already synced)
      if (!(orderId != null && waitForSync)) {
        _syncPointsToBackend(userId, transaction).catchError((e) {
          Logger.error('Error syncing points to backend: $e',
              tag: 'PointService', error: e);
        });
      }

      Logger.info(
          'Points redeemed: $points points (Order: ${orderId ?? "N/A"})',
          tag: 'PointService');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Error redeeming points: $e',
          tag: 'PointService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Sync points to backend synchronously (blocks until complete)
  /// Returns true if sync was successful
  static Future<bool> _syncPointsToBackendSync(
      String userId, PointTransaction transaction) async {
    return _syncPointsWithRetry(
      userId: userId,
      transaction: transaction,
      context: 'syncPointsToBackendSync',
    );
  }

  /// Calculate points earned from order total (with tier multiplier)
  static int calculatePointsFromOrder(double orderTotal,
      {double multiplier = 1.0}) {
    return ((orderTotal * pointsPerDollar) * multiplier).round();
  }

  /// Calculate maximum points that can be redeemed for an order
  static int calculateMaxRedeemablePoints(double orderTotal) {
    final maxDiscount = orderTotal * (maxRedemptionPercent / 100);
    return calculatePointsForDiscount(maxDiscount);
  }

  /// Calculate points needed for discount amount
  static int calculatePointsForDiscount(double discountAmount) {
    return (discountAmount * pointsPerDollarDiscount).round();
  }

  /// Validate redemption amount
  static bool isValidRedemptionAmount(
      int points, double orderTotal, int currentBalance) {
    if (points < minRedemptionPoints) return false;
    if (points > currentBalance) return false;
    final maxPoints = calculateMaxRedeemablePoints(orderTotal);
    if (points > maxPoints) return false;
    return true;
  }

  /// Calculate discount from points
  static double calculateDiscountFromPoints(int points) {
    return (points / pointsPerDollarDiscount);
  }

  /// Check for expired points and mark them
  static Future<int> checkAndMarkExpiredPoints(String userId) async {
    try {
      final transactions = await getCachedTransactions(userId);
      final now = DateTime.now();
      int expiredCount = 0;
      int totalExpiredPoints = 0;

      // Check for expired points that haven't been marked yet
      final expiredTransactions = transactions.where((transaction) {
        return transaction.expiresAt != null &&
            !transaction.isExpired &&
            transaction.type == PointTransactionType.earn &&
            now.isAfter(transaction.expiresAt!);
      }).toList();

      if (expiredTransactions.isEmpty) {
        return 0;
      }

      // Calculate total expired points
      totalExpiredPoints =
          expiredTransactions.fold(0, (sum, t) => sum + t.points);

      if (totalExpiredPoints > 0) {
        // Create expire transaction (points will be subtracted in redeemPoints logic)
        final expireTransaction = PointTransaction(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          type: PointTransactionType.expire,
          points: totalExpiredPoints,
          description:
              'Points expired (${expiredTransactions.length} transaction(s))',
          createdAt: DateTime.now(),
        );

        // Update balance locally by subtracting expired points
        final currentBalance = await getCachedBalance(userId);
        if (currentBalance != null) {
          final updatedBalance = PointBalance(
            userId: userId,
            currentBalance: currentBalance.currentBalance - totalExpiredPoints,
            lifetimeEarned: currentBalance.lifetimeEarned,
            lifetimeRedeemed: currentBalance.lifetimeRedeemed,
            lifetimeExpired:
                currentBalance.lifetimeExpired + totalExpiredPoints,
            lastUpdated: DateTime.now(),
          );
          await _saveBalanceToStorage(updatedBalance);
        }

        // Save expire transaction
        await _saveTransactionToStorage(expireTransaction);

        // Try to sync with backend
        _syncPointsToBackend(userId, expireTransaction).catchError((e) {
          Logger.error('Error syncing expired points to backend: $e',
              tag: 'PointService', error: e);
        });

        expiredCount = expiredTransactions.length;
      }

      return expiredCount;
    } catch (e) {
      Logger.error('Error checking expired points: $e',
          tag: 'PointService', error: e);
      return 0;
    }
  }

  /// Get points expiring soon
  static Future<List<PointTransaction>> getPointsExpiringSoon(
      String userId) async {
    try {
      final transactions = await getCachedTransactions(userId);
      final now = DateTime.now();
      final warningDate = now.add(Duration(days: expirationWarningDays));

      return transactions.where((transaction) {
        if (transaction.expiresAt == null || transaction.isExpired) {
          return false;
        }
        if (transaction.type != PointTransactionType.earn) return false;
        return transaction.expiresAt!.isBefore(warningDate) &&
            transaction.expiresAt!.isAfter(now);
      }).toList();
    } catch (e) {
      Logger.error('Error getting expiring points: $e',
          tag: 'PointService', error: e);
      return [];
    }
  }

  /// Award referral bonus
  static Future<bool> awardReferralBonus({
    required String userId,
    required String referredUserId,
  }) async {
    return await earnPoints(
      userId: userId,
      points: referralBonus,
      type: PointTransactionType.referral,
      description: 'Referral bonus for referring user #$referredUserId',
      expiresAt: DateTime.now().add(Duration(days: pointsExpirationDays)),
    );
  }

  /// Award birthday bonus
  static Future<bool> awardBirthdayBonus(String userId) async {
    // Check if already awarded this year
    final transactions = await getCachedTransactions(userId);
    final thisYear = DateTime.now().year;
    final alreadyAwarded = transactions.any((t) {
      return t.type == PointTransactionType.birthday &&
          t.createdAt.year == thisYear;
    });

    if (alreadyAwarded) {
      Logger.warning('Birthday bonus already awarded this year',
          tag: 'PointService');
      return false;
    }

    return await earnPoints(
      userId: userId,
      points: birthdayBonus,
      type: PointTransactionType.birthday,
      description: 'Birthday bonus',
      expiresAt: DateTime.now().add(Duration(days: pointsExpirationDays)),
    );
  }

  /// Refund points for cancelled order
  static Future<bool> refundPointsForOrder({
    required String userId,
    required String orderId,
    required int pointsToRefund,
  }) async {
    return await earnPoints(
      userId: userId,
      points: pointsToRefund,
      type: PointTransactionType.refund,
      description: 'Points refunded for cancelled order #$orderId',
      orderId: orderId,
      expiresAt: DateTime.now().add(Duration(days: pointsExpirationDays)),
    );
  }

  /// Get transactions filtered by type
  static Future<List<PointTransaction>> getTransactionsByType(
    String userId,
    PointTransactionType type,
  ) async {
    final transactions = await getCachedTransactions(userId);
    return transactions.where((t) => t.type == type).toList();
  }

  /// Get transactions filtered by date range
  static Future<List<PointTransaction>> getTransactionsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final transactions = await getCachedTransactions(userId);
    return transactions.where((t) {
      return t.createdAt.isAfter(startDate) && t.createdAt.isBefore(endDate);
    }).toList();
  }

  /// Get cached balance from local storage
  static Future<PointBalance?> getCachedBalance(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedValue = prefs.getString('$_balanceKey$userId');

      if (storedValue != null) {
        final decrypted =
            await _securePrefs.maybeDecrypt(storedValue) ?? storedValue;
        final balanceData = json.decode(decrypted);
        return PointBalance.fromJson(balanceData);
      }

      return null;
    } catch (e) {
      Logger.error('Error getting cached balance: $e',
          tag: 'PointService', error: e);
      return null;
    }
  }

  /// Get cached transactions from local storage
  static Future<List<PointTransaction>> getCachedTransactions(
      String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedValue = prefs.getString('$_transactionsKey$userId');

      if (storedValue != null) {
        final decrypted =
            await _securePrefs.maybeDecrypt(storedValue) ?? storedValue;
        final transactionsData = json.decode(decrypted) as List<dynamic>;
        return transactionsData
            .map((item) =>
                PointTransaction.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort((a, b) =>
              b.createdAt.compareTo(a.createdAt)); // Sort by newest first
      }

      return [];
    } catch (e) {
      Logger.error('Error getting cached transactions: $e',
          tag: 'PointService', error: e);
      return [];
    }
  }

  /// Save balance to local storage
  static Future<void> _saveBalanceToStorage(PointBalance balance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final balanceJson = json.encode(balance.toJson());
      final encrypted = await _securePrefs.encrypt(balanceJson);
      await prefs.setString('$_balanceKey${balance.userId}', encrypted);
    } catch (e) {
      Logger.error('Error saving balance to storage: $e',
          tag: 'PointService', error: e);
    }
  }

  /// Save transaction to local storage
  static Future<void> _saveTransactionToStorage(
      PointTransaction transaction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactions = await getCachedTransactions(transaction.userId);

      // Add new transaction
      transactions.insert(0, transaction);

      // Keep only last 100 transactions
      final limitedTransactions = transactions.take(100).toList();

      final transactionsJson =
          json.encode(limitedTransactions.map((t) => t.toJson()).toList());
      final encrypted = await _securePrefs.encrypt(transactionsJson);
      await prefs.setString(
          '$_transactionsKey${transaction.userId}', encrypted);
    } catch (e) {
      Logger.error('Error saving transaction to storage: $e',
          tag: 'PointService', error: e);
    }
  }

  /// Sync points to backend (non-blocking)
  static Future<void> _syncPointsToBackend(
      String userId, PointTransaction transaction) async {
    final success = await _syncPointsWithRetry(
      userId: userId,
      transaction: transaction,
      context: 'syncPointsToBackend',
    );
    if (!success) {
      await _enqueuePointAdjustment(userId, transaction);
    }
  }

  /// Cache transactions locally
  static Future<void> _cacheTransactions(
      String userId, List<PointTransaction> transactions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson =
          json.encode(transactions.map((t) => t.toJson()).toList());
      final encrypted = await _securePrefs.encrypt(transactionsJson);
      await prefs.setString('$_transactionsKey$userId', encrypted);
    } catch (e) {
      Logger.error('Error caching transactions: $e',
          tag: 'PointService', error: e);
    }
  }

  /// Sync all local transactions to backend
  static Future<bool> syncAllTransactions(String userId) async {
    try {
      final localTransactions = await getCachedTransactions(userId);

      if (localTransactions.isEmpty) {
        return true;
      }

      // Get existing transactions from backend to avoid duplicates
      final existingTransactions =
          await getPointTransactions(userId, page: 1, perPage: 100);
      final existingOrderIds = existingTransactions
          .where(
              (t) => t.orderId != null && t.type == PointTransactionType.earn)
          .map((t) => t.orderId!)
          .toSet();

      // Filter out transactions that already exist on backend
      final transactionsToSync = localTransactions.where((localT) {
        // Skip if this transaction already exists on backend
        if (localT.orderId != null &&
            localT.type == PointTransactionType.earn) {
          if (existingOrderIds.contains(localT.orderId)) {
            Logger.info(
                'Skipping duplicate transaction for order: ${localT.orderId}',
                tag: 'PointService');
            return false;
          }
        }
        return true;
      }).toList();

      if (transactionsToSync.isEmpty) {
        Logger.info('No new transactions to sync', tag: 'PointService');
        return true;
      }

      final response = await NetworkUtils.executeRequest(
        () => http.post(
          Uri.parse('${AppConfig.backendUrl}/wp-json/twork/v1/points/sync'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic ${_getWooCommerceAuth()}',
          },
          body: json.encode({
            'user_id': userId,
            'transactions': transactionsToSync.map((t) => t.toJson()).toList(),
          }),
        ),
        context: 'syncAllTransactions',
      );

      if (NetworkUtils.isValidResponse(response)) {
        final data = json.decode(response!.body);
        Logger.info(
            'Synced ${data['synced']} transactions to backend (${transactionsToSync.length} attempted)',
            tag: 'PointService');
        return true;
      }

      return false;
    } catch (e) {
      Logger.error('Error syncing all transactions: $e',
          tag: 'PointService', error: e);
      return false;
    }
  }

  static Future<bool> _syncPointsWithRetry({
    required String userId,
    required PointTransaction transaction,
    required String context,
  }) async {
    const int maxAttempts = 3;
    Duration backoff = const Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _sendPointsToBackendHttp(
          userId: userId,
          transaction: transaction,
          context: context,
        );
        PointSyncTelemetry.recordSuccess(
          transaction: transaction,
          attempt: attempt,
          context: context,
        );
        Logger.info(
          'Points synced to backend: ${transaction.type} ${transaction.points} points (attempt $attempt)',
          tag: 'PointService',
        );
        return true;
      } catch (e, stackTrace) {
        final isFinalAttempt = attempt == maxAttempts;
        await PointSyncTelemetry.recordFailure(
          transaction: transaction,
          attempt: attempt,
          backoff: isFinalAttempt ? Duration.zero : backoff,
          context: context,
          error: e,
          finalAttempt: isFinalAttempt,
        );
        Logger.error(
          'Error syncing points to backend (attempt $attempt/$maxAttempts): $e',
          tag: 'PointService',
          error: e,
          stackTrace: stackTrace,
        );

        if (!isFinalAttempt) {
          await Future.delayed(backoff);
          backoff *= 2;
        }
      }
    }

    return false;
  }

  static Future<void> _sendPointsToBackendHttp({
    required String userId,
    required PointTransaction transaction,
    required String context,
  }) async {
    final endpoint =
        '${AppConfig.backendUrl}/wp-json/twork/v1/points/${transaction.type == PointTransactionType.redeem ? "redeem" : "earn"}';
    final response = await NetworkUtils.executeRequest(
      () => http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${_getWooCommerceAuth()}',
        },
        body: json.encode({
          'user_id': userId,
          'points': transaction.points,
          'type': transaction.type.toValue(),
          'description': transaction.description,
          'order_id': transaction.orderId,
          'expires_at': transaction.expiresAt?.toIso8601String(),
        }),
      ),
      context: context,
    );

    if (!NetworkUtils.isValidResponse(response)) {
      throw Exception(
        'Invalid response while syncing points (status: ${response?.statusCode ?? 'null'})',
      );
    }
  }

  static Future<void> _enqueuePointAdjustment(
    String userId,
    PointTransaction transaction,
  ) async {
    final queue = OfflineQueueService();
    final payload = <String, dynamic>{
      'user_id': userId,
      'transaction': transaction.toJson(),
    };

    await queue.addToQueue(
      OfflineQueueItemType.pointAdjustment,
      payload,
      dedupeKey: 'point-${transaction.id}',
    );

    Logger.info(
      'Queued point transaction for later sync',
      tag: 'PointService',
      metadata: {'transactionId': transaction.id},
    );
  }

  static void registerOfflineQueueHandler() {
    if (_queueRegistered) {
      return;
    }
    _queueRegistered = true;
    OfflineQueueService()
        .setPointAdjustmentCallback(_processQueuedPointAdjustment);
  }

  static Future<bool> syncQueuedPointTransaction(
    String userId,
    PointTransaction transaction,
  ) {
    return _syncPointsWithRetry(
      userId: userId,
      transaction: transaction,
      context: 'offlineQueue',
    );
  }

  static Future<bool> _processQueuedPointAdjustment(
      Map<String, dynamic> payload) async {
    try {
      if (!payload.containsKey('transaction')) {
        Logger.warning('Queued point adjustment missing payload',
            tag: 'PointService');
        return false;
      }

      final transactionJson =
          Map<String, dynamic>.from(payload['transaction'] as Map);
      final transaction = PointTransaction.fromJson(transactionJson);
      final userId = (payload['user_id']?.toString().trim().isNotEmpty ?? false)
          ? payload['user_id'].toString()
          : transaction.userId;

      Logger.info(
        'Replaying queued point transaction',
        tag: 'PointService',
        metadata: {'transactionId': transaction.id},
      );

      return await syncQueuedPointTransaction(userId, transaction);
    } catch (e, stackTrace) {
      Logger.error('Failed to process queued point adjustment: $e',
          tag: 'PointService', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
