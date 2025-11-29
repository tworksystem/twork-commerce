/// Point transaction model
/// Represents a single point transaction (earn, redeem, expire)
class PointTransaction {
  final String id;
  final String userId;
  final PointTransactionType type;
  final int points;
  final String? description;
  final String? orderId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isExpired;

  PointTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.points,
    this.description,
    this.orderId,
    required this.createdAt,
    this.expiresAt,
    this.isExpired = false,
  });

  /// Create from JSON
  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      type: PointTransactionTypeExtension.fromString(
          json['type']?.toString() ?? 'earn'),
      points: (json['points'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString(),
      orderId: json['order_id']?.toString() ?? json['orderId']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'])
              : null,
      isExpired: json['is_expired'] ?? json['isExpired'] ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.toValue(),
      'points': points,
      'description': description,
      'order_id': orderId,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_expired': isExpired,
    };
  }

  /// Check if transaction is expired
  bool get expired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get formatted points (with + or - sign)
  String get formattedPoints {
    if (type == PointTransactionType.redeem || 
        type == PointTransactionType.expire || 
        type == PointTransactionType.refund) {
      return '-$points';
    }
    return '+$points';
  }

  /// Get days until expiration (if applicable)
  int? get daysUntilExpiration {
    if (expiresAt == null || expired) return null;
    final now = DateTime.now();
    return expiresAt!.difference(now).inDays;
  }

  /// Check if transaction is expiring soon (within 30 days)
  bool get isExpiringSoon {
    final days = daysUntilExpiration;
    return days != null && days <= 30 && days > 0;
  }
}

/// Point transaction types
enum PointTransactionType {
  earn, // Earned points (purchase, signup, review, etc.)
  redeem, // Redeemed points (used for discount)
  expire, // Expired points
  adjust, // Manual adjustment by admin
  referral, // Referral bonus
  birthday, // Birthday bonus
  refund, // Refunded points (order cancellation)
}

/// Extension for PointTransactionType
extension PointTransactionTypeExtension on PointTransactionType {
  /// Convert from string
  static PointTransactionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'earn':
      case 'earned':
        return PointTransactionType.earn;
      case 'redeem':
      case 'redeemed':
        return PointTransactionType.redeem;
      case 'expire':
      case 'expired':
        return PointTransactionType.expire;
      case 'adjust':
      case 'adjustment':
        return PointTransactionType.adjust;
      case 'referral':
      case 'refer':
        return PointTransactionType.referral;
      case 'birthday':
      case 'birthday_bonus':
        return PointTransactionType.birthday;
      case 'refund':
      case 'refunded':
        return PointTransactionType.refund;
      default:
        return PointTransactionType.earn;
    }
  }

  /// Convert to string
  String toValue() {
    switch (this) {
      case PointTransactionType.earn:
        return 'earn';
      case PointTransactionType.redeem:
        return 'redeem';
      case PointTransactionType.expire:
        return 'expire';
      case PointTransactionType.adjust:
        return 'adjust';
      case PointTransactionType.referral:
        return 'referral';
      case PointTransactionType.birthday:
        return 'birthday';
      case PointTransactionType.refund:
        return 'refund';
    }
  }
}

/// Point balance model
/// Represents user's current point balance and statistics
class PointBalance {
  final String userId;
  final int currentBalance;
  final int lifetimeEarned;
  final int lifetimeRedeemed;
  final int lifetimeExpired;
  final DateTime lastUpdated;
  final DateTime? pointsExpireAt; // When points will expire next

  PointBalance({
    required this.userId,
    required this.currentBalance,
    this.lifetimeEarned = 0,
    this.lifetimeRedeemed = 0,
    this.lifetimeExpired = 0,
    required this.lastUpdated,
    this.pointsExpireAt,
  });

  /// Create from JSON
  factory PointBalance.fromJson(Map<String, dynamic> json) {
    return PointBalance(
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      currentBalance: (json['current_balance'] as num?)?.toInt() ??
          (json['currentBalance'] as num?)?.toInt() ??
          0,
      lifetimeEarned: (json['lifetime_earned'] as num?)?.toInt() ??
          (json['lifetimeEarned'] as num?)?.toInt() ??
          0,
      lifetimeRedeemed: (json['lifetime_redeemed'] as num?)?.toInt() ??
          (json['lifetimeRedeemed'] as num?)?.toInt() ??
          0,
      lifetimeExpired: (json['lifetime_expired'] as num?)?.toInt() ??
          (json['lifetimeExpired'] as num?)?.toInt() ??
          0,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : json['lastUpdated'] != null
              ? DateTime.parse(json['lastUpdated'])
              : DateTime.now(),
      pointsExpireAt: json['points_expire_at'] != null
          ? DateTime.parse(json['points_expire_at'])
          : json['pointsExpireAt'] != null
              ? DateTime.parse(json['pointsExpireAt'])
              : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'current_balance': currentBalance,
      'lifetime_earned': lifetimeEarned,
      'lifetime_redeemed': lifetimeRedeemed,
      'lifetime_expired': lifetimeExpired,
      'last_updated': lastUpdated.toIso8601String(),
      'points_expire_at': pointsExpireAt?.toIso8601String(),
    };
  }

  /// Get formatted balance
  String get formattedBalance => '$currentBalance points';

  /// Check if user has enough points
  bool hasEnoughPoints(int requiredPoints) {
    return currentBalance >= requiredPoints;
  }

  /// Get next expiration date from available points
  DateTime? get nextExpirationDate {
    // This would be calculated from transactions
    // For now, return null - will be implemented in service
    return pointsExpireAt;
  }

  /// Get points expiring soon count
  int get pointsExpiringSoon {
    // This would be calculated from transactions
    // For now, return 0 - will be implemented in service
    return 0;
  }

  /// Get tier/level based on lifetime earned
  PointTier get tier {
    if (lifetimeEarned >= 50000) return PointTier.platinum;
    if (lifetimeEarned >= 20000) return PointTier.gold;
    if (lifetimeEarned >= 10000) return PointTier.silver;
    if (lifetimeEarned >= 5000) return PointTier.bronze;
    return PointTier.basic;
  }
}

/// Point tier/level system
enum PointTier {
  basic,
  bronze,
  silver,
  gold,
  platinum,
}

extension PointTierExtension on PointTier {
  String get name {
    switch (this) {
      case PointTier.basic:
        return 'Basic';
      case PointTier.bronze:
        return 'Bronze';
      case PointTier.silver:
        return 'Silver';
      case PointTier.gold:
        return 'Gold';
      case PointTier.platinum:
        return 'Platinum';
    }
  }

  int get minimumPoints {
    switch (this) {
      case PointTier.basic:
        return 0;
      case PointTier.bronze:
        return 5000;
      case PointTier.silver:
        return 10000;
      case PointTier.gold:
        return 20000;
      case PointTier.platinum:
        return 50000;
    }
  }

  double get earningMultiplier {
    switch (this) {
      case PointTier.basic:
        return 1.0;
      case PointTier.bronze:
        return 1.1; // 10% bonus
      case PointTier.silver:
        return 1.2; // 20% bonus
      case PointTier.gold:
        return 1.3; // 30% bonus
      case PointTier.platinum:
        return 1.5; // 50% bonus
    }
  }

  String get icon {
    switch (this) {
      case PointTier.basic:
        return '🥉';
      case PointTier.bronze:
        return '🥉';
      case PointTier.silver:
        return '🥈';
      case PointTier.gold:
        return '🥇';
      case PointTier.platinum:
        return '💎';
    }
  }
}

