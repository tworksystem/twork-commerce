import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/in_app_notification.dart';
import '../utils/logger.dart';

/// Professional in-app notification service
/// Manages notification storage, retrieval, and persistence
class InAppNotificationService {
  static final InAppNotificationService _instance =
      InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  static const String _notificationsKey = 'in_app_notifications';
  static const int _maxNotifications = 100; // Limit stored notifications

  /// Save notification to storage
  Future<void> saveNotification(InAppNotification notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await getNotifications();

      // Add new notification at the beginning
      notifications.insert(0, notification);

      // Limit to max notifications
      if (notifications.length > _maxNotifications) {
        notifications.removeRange(_maxNotifications, notifications.length);
      }

      // Save to storage
      final notificationsJson = json.encode(
        notifications.map((n) => n.toJson()).toList(),
      );
      await prefs.setString(_notificationsKey, notificationsJson);

      Logger.info('Notification saved: ${notification.id}',
          tag: 'InAppNotification');
    } catch (e, stackTrace) {
      Logger.error('Error saving notification: $e',
          tag: 'InAppNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Get all notifications
  Future<List<InAppNotification>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_notificationsKey);

      if (notificationsJson != null) {
        final List<dynamic> notificationsData = json.decode(notificationsJson);
        return notificationsData
            .map((json) => InAppNotification.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e, stackTrace) {
      Logger.error('Error getting notifications: $e',
          tag: 'InAppNotification', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      final notifications = await getNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      Logger.error('Error getting unread count: $e',
          tag: 'InAppNotification', error: e);
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final notifications = await getNotifications();
      final index = notifications.indexWhere((n) => n.id == notificationId);

      if (index != -1) {
        notifications[index] = notifications[index].copyWith(isRead: true);
        await _saveNotifications(notifications);
        Logger.info('Notification marked as read: $notificationId',
            tag: 'InAppNotification');
      }
    } catch (e, stackTrace) {
      Logger.error('Error marking notification as read: $e',
          tag: 'InAppNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications = notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      await _saveNotifications(updatedNotifications);
      Logger.info('All notifications marked as read',
          tag: 'InAppNotification');
    } catch (e, stackTrace) {
      Logger.error('Error marking all notifications as read: $e',
          tag: 'InAppNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final notifications = await getNotifications();
      notifications.removeWhere((n) => n.id == notificationId);
      await _saveNotifications(notifications);
      Logger.info('Notification deleted: $notificationId',
          tag: 'InAppNotification');
    } catch (e, stackTrace) {
      Logger.error('Error deleting notification: $e',
          tag: 'InAppNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      Logger.info('All notifications deleted', tag: 'InAppNotification');
    } catch (e, stackTrace) {
      Logger.error('Error deleting all notifications: $e',
          tag: 'InAppNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Create notification from order update
  /// Returns true if notification was created, false if duplicate was found
  Future<bool> createOrderNotification({
    required String orderId,
    required String status,
    required String total,
    String? currency,
  }) async {
    // Check for duplicate notifications (same order ID and status within last 5 minutes)
    final existingNotifications = await getNotifications();
    final now = DateTime.now();
    final fiveMinutesAgo = now.subtract(Duration(minutes: 5));
    
    final duplicateExists = existingNotifications.any((n) {
      if (n.type != NotificationType.order) return false;
      final nOrderId = n.data?['orderId']?.toString();
      final nStatus = n.data?['status']?.toString();
      
      // Check if same order ID and status, and created within last 5 minutes
      return nOrderId == orderId.toString() &&
             nStatus == status.toString() &&
             n.createdAt.isAfter(fiveMinutesAgo);
    });
    
    if (duplicateExists) {
      Logger.info('Duplicate notification prevented for order: $orderId, status: $status',
          tag: 'InAppNotificationService');
      return false;
    }
    
    final notification = InAppNotification(
      id: 'order_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Order #$orderId $status',
      body: 'Your order total is ${currency ?? '\$'} $total',
      type: NotificationType.order,
      createdAt: DateTime.now(),
      isRead: false, // New notifications are unread
      data: {
        'orderId': orderId,
        'status': status,
        'total': total,
        'currency': currency ?? '\$',
      },
      actionUrl: '/order/$orderId',
    );

    await saveNotification(notification);
    
    Logger.info('Order notification created and saved: $orderId',
        tag: 'InAppNotificationService');
    return true;
  }

  /// Create promotion notification
  Future<void> createPromotionNotification({
    required String title,
    required String body,
    String? imageUrl,
    String? actionUrl,
  }) async {
    final notification = InAppNotification(
      id: 'promo_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: NotificationType.promotion,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
      actionUrl: actionUrl,
    );

    await saveNotification(notification);
  }

  /// Create shipping notification
  Future<void> createShippingNotification({
    required String orderId,
    required String trackingNumber,
    String? carrier,
  }) async {
    final notification = InAppNotification(
      id: 'shipping_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Order #$orderId Shipped',
      body: carrier != null
          ? 'Your order has been shipped via $carrier. Tracking: $trackingNumber'
          : 'Your order has been shipped. Tracking: $trackingNumber',
      type: NotificationType.shipping,
      createdAt: DateTime.now(),
      data: {
        'orderId': orderId,
        'trackingNumber': trackingNumber,
        'carrier': carrier,
      },
      actionUrl: '/order/$orderId',
    );

    await saveNotification(notification);
  }

  /// Save notifications to storage
  Future<void> _saveNotifications(List<InAppNotification> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = json.encode(
        notifications.map((n) => n.toJson()).toList(),
      );
      await prefs.setString(_notificationsKey, notificationsJson);
    } catch (e, stackTrace) {
      Logger.error('Error saving notifications: $e',
          tag: 'InAppNotification', error: e, stackTrace: stackTrace);
    }
  }
}

