import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../utils/app_config.dart';
import 'in_app_notification_service.dart';
import '../providers/in_app_notification_provider.dart';

/// Background message handler (must be top-level function)
/// This handles notifications when app is terminated or in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase if not already initialized
    await Firebase.initializeApp();

    Logger.info('Background message received: ${message.notification?.title}',
        tag: 'PushNotification');
    Logger.info('Message ID: ${message.messageId}, Data: ${message.data}',
        tag: 'PushNotification');

    // Initialize local notifications plugin for background notifications
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(initSettings);

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'order_updates',
      'Order Updates',
      description: 'Notifications for order status updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Show notification in background/terminated state
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'order_updates',
      'Order Updates',
      channelDescription: 'Notifications for order status updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Order Update',
      message.notification?.body ?? 'Your order has been updated',
      notificationDetails,
      payload: json.encode(message.data),
    );

    Logger.info('Background notification displayed successfully',
        tag: 'PushNotification');
  } catch (e, stackTrace) {
    Logger.error('Error handling background message: $e',
        tag: 'PushNotification', error: e, stackTrace: stackTrace);
  }
}

/// Service for Firebase Cloud Messaging push notifications
/// Handles instant notifications from server
///
/// This service provides INSTANT notifications when WooCommerce backend updates orders
/// It integrates with OrderProvider to immediately refresh orders when notifications arrive
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _fcmToken;
  bool _isInitialized = false;

  /// Callback for refreshing orders when notification arrives
  /// Set this from main.dart or app initialization
  Function(String orderId, Map<String, dynamic> data)? onOrderUpdate;

  /// Callback for navigating to order details
  /// Set this from main.dart with navigator key
  Function(String orderId)? onNavigateToOrder;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get FCM token
  String? get fcmToken => _fcmToken;

  /// Set order update callback (called when notification arrives)
  void setOrderUpdateCallback(
      Function(String orderId, Map<String, dynamic> data) callback) {
    onOrderUpdate = callback;
  }

  /// Set navigation callback (called when notification is tapped)
  void setNavigationCallback(Function(String orderId) callback) {
    onNavigateToOrder = callback;
  }

  /// Initialize push notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.info('PushNotificationService already initialized',
          tag: 'PushNotification');
      return;
    }

    try {
      Logger.info('Initializing Firebase Cloud Messaging',
          tag: 'PushNotification');

      // Request notification permissions
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        Logger.info('User granted notification permission',
            tag: 'PushNotification');

        // Get FCM token
        await _getFCMToken();

        // Configure message handlers
        await _configureMessageHandlers();

        // Configure local notifications for foreground
        await _configureLocalNotifications();

        _isInitialized = true;
        Logger.info('PushNotificationService initialized successfully',
            tag: 'PushNotification');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        Logger.info('User granted provisional notification permission',
            tag: 'PushNotification');
        await _getFCMToken();
        await _configureMessageHandlers();
        await _configureLocalNotifications();
        _isInitialized = true;
      } else {
        Logger.warning('User declined notification permission',
            tag: 'PushNotification');
      }
    } catch (e, stackTrace) {
      Logger.error('Error initializing push notifications: $e',
          tag: 'PushNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        // Show full token for testing (will be in logs)
        Logger.info('FCM Token obtained (full): $_fcmToken',
            tag: 'PushNotification');
        Logger.info(
            'FCM Token (first 50 chars): ${_fcmToken!.substring(0, 50)}...',
            tag: 'PushNotification');

        // Send token to backend
        await _sendTokenToBackend(_fcmToken!);
      } else {
        Logger.warning('FCM token is null', tag: 'PushNotification');
      }
    } catch (e) {
      Logger.error('Failed to get FCM token: $e',
          tag: 'PushNotification', error: e);
    }
  }

  /// Send FCM token to backend server
  Future<void> _sendTokenToBackend(String token) async {
    try {
      // Get user ID from secure storage
      final userJson = await _secureStorage.read(key: 'user_data');

      if (userJson == null) {
        Logger.info('No user data found, skipping token upload',
            tag: 'PushNotification');
        return;
      }

      final userData = json.decode(userJson) as Map<String, dynamic>;
      final userId = userData['id']?.toString();

      if (userId == null || userId.isEmpty || userId == '0') {
        Logger.info('No valid user ID found, skipping token upload',
            tag: 'PushNotification');
        return;
      }

      Logger.info('Uploading FCM token to backend for user: $userId',
          tag: 'PushNotification');

      // Upload FCM token to backend server
      try {
        final backendUrl = _getBackendUrl();
        if (backendUrl == null || backendUrl.isEmpty) {
          Logger.info('Backend URL not configured, skipping token upload',
              tag: 'PushNotification');
          Logger.info('Configure backend URL in lib/utils/app_config.dart',
              tag: 'PushNotification');
          return;
        }

        final response = await http
            .post(
          Uri.parse('$backendUrl${AppConfig.backendRegisterTokenEndpoint}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': userId,
            'fcmToken': token,
            'platform': Platform.isAndroid ? 'android' : 'ios',
          }),
        )
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            Logger.warning('Backend token upload timeout',
                tag: 'PushNotification');
            throw TimeoutException('Backend request timeout');
          },
        );

        if (response.statusCode == 200) {
          Logger.info('✅ FCM token uploaded successfully to backend',
              tag: 'PushNotification');
        } else {
          Logger.warning('Failed to upload FCM token: ${response.statusCode}',
              tag: 'PushNotification');
        }
      } on TimeoutException {
        Logger.warning(
            'Backend token upload timeout - continuing without backend sync',
            tag: 'PushNotification');
      } catch (e) {
        Logger.warning(
            'Backend not available - continuing without backend sync: $e',
            tag: 'PushNotification');
        // Don't fail the entire FCM initialization if backend is not available
      }
    } catch (e) {
      Logger.error('Failed to send FCM token to backend: $e',
          tag: 'PushNotification', error: e);
    }
  }

  /// Configure message handlers
  /// This sets up listeners for FCM messages in all app states (foreground, background, terminated)
  Future<void> _configureMessageHandlers() async {
    // Handle foreground messages (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      Logger.info('Foreground message received: ${message.notification?.title}',
          tag: 'PushNotification');
      Logger.info('Message data: ${message.data}', tag: 'PushNotification');

      // Show local notification in foreground
      _handleForegroundMessage(message);

      // Trigger immediate order refresh when notification arrives
      await _handleOrderUpdateNotification(message);
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      Logger.info(
          'Notification tapped (background): ${message.notification?.title}',
          tag: 'PushNotification');
      Logger.info('Message data: ${message.data}', tag: 'PushNotification');

      // Handle notification tap and navigate
      _handleNotificationTap(message);

      // Also trigger order refresh
      await _handleOrderUpdateNotification(message);
    });

    // Handle notification tap when app was terminated
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      Logger.info(
          'Notification tapped (terminated): ${initialMessage.notification?.title}',
          tag: 'PushNotification');
      Logger.info('Message data: ${initialMessage.data}',
          tag: 'PushNotification');

      // Handle notification tap and navigate
      _handleNotificationTap(initialMessage);

      // Also trigger order refresh
      await _handleOrderUpdateNotification(initialMessage);
    }

    // Handle FCM token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      Logger.info('FCM token refreshed', tag: 'PushNotification');
      _fcmToken = newToken;
      _sendTokenToBackend(newToken);
    });

    Logger.info('Message handlers configured', tag: 'PushNotification');
  }

  /// Handle order update notification - triggers immediate order refresh
  /// This is called when FCM notification arrives to ensure orders are instantly updated
  /// Also creates in-app notification
  Future<void> _handleOrderUpdateNotification(RemoteMessage message) async {
    try {
      final data = message.data;
      final orderId = data['orderId'] ?? data['order_id'];
      final notificationType = data['type'] ?? '';

      // Only process order status update notifications
      if (notificationType == 'order_status_update' && orderId != null) {
        Logger.info('Order update notification received for order: $orderId',
            tag: 'PushNotification');

        // Create in-app notification
        try {
          final status = data['status'] ?? 'updated';
          final total = data['total'] ?? '0';
          final currency = data['currency'] ?? '\$';
          
          // Create notification in service (with deduplication)
          final notificationCreated = await InAppNotificationService().createOrderNotification(
            orderId: orderId.toString(),
            status: status.toString(),
            total: total.toString(),
            currency: currency.toString(),
          );
          
          if (notificationCreated) {
            // Update provider immediately for real-time UI update
            try {
              final notificationProvider = InAppNotificationProvider.instance;
              await notificationProvider.loadNotifications();
              Logger.info('Notification provider updated immediately for order: $orderId',
                  tag: 'PushNotification');
            } catch (e) {
              Logger.error('Error updating notification provider: $e',
                  tag: 'PushNotification', error: e);
            }
            
            Logger.info('In-app notification created for order: $orderId',
                tag: 'PushNotification');
          } else {
            Logger.info('Duplicate notification prevented for order: $orderId',
                tag: 'PushNotification');
          }
        } catch (e) {
          Logger.error('Error creating in-app notification: $e',
              tag: 'PushNotification', error: e);
        }
        Logger.info('Triggering immediate order refresh',
            tag: 'PushNotification');

        // Call the callback to refresh orders immediately
        if (onOrderUpdate != null) {
          onOrderUpdate!(orderId.toString(), data);
          Logger.info('Order refresh callback triggered for order: $orderId',
              tag: 'PushNotification');
        } else {
          Logger.warning(
              'Order update callback not set, notification received but order not refreshed',
              tag: 'PushNotification');
          Logger.warning(
              'Set callback using PushNotificationService().setOrderUpdateCallback()',
              tag: 'PushNotification');
        }
      } else {
        Logger.info(
            'Notification type is not order_status_update, skipping order refresh',
            tag: 'PushNotification');
      }
    } catch (e, stackTrace) {
      Logger.error('Error handling order update notification: $e',
          tag: 'PushNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Configure local notifications for foreground
  Future<void> _configureLocalNotifications() async {
    // Configure Android notification channel for Android 8.0+
    const androidChannel = AndroidNotificationChannel(
      'order_updates', // Same ID as in _handleForegroundMessage
      'Order Updates',
      description: 'Notifications for order status updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize with channel creation
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        Logger.info('Local notification tapped', tag: 'PushNotification');
        // Handle notification tap
      },
    );

    // Create the channel AFTER initialization
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    Logger.info(
        'Local notifications configured with channel: ${androidChannel.id}',
        tag: 'PushNotification');
  }

  /// Handle foreground message by showing local notification
  /// This displays notification when app is in foreground and triggers order refresh
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      // Extract notification data
      final data = message.data;
      final orderId = data['orderId'] ?? data['order_id'];
      final notificationType = data['type'] ?? '';

      // Prepare notification details
      const androidDetails = AndroidNotificationDetails(
        'order_updates',
        'Order Updates',
        channelDescription: 'Notifications for order status updates',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        // Enable heads-up notification for immediate visibility
        enableLights: true,
        ledColor: Color.fromARGB(255, 0, 122, 255),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show notification with payload containing order data
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Order Update',
        message.notification?.body ?? 'Your order has been updated',
        details,
        payload: json.encode(message.data),
      );

      Logger.info('Foreground notification displayed for order: $orderId',
          tag: 'PushNotification');

      // Trigger immediate order refresh and in-app notification update when notification arrives in foreground
      if (notificationType == 'order_status_update' && orderId != null) {
        Logger.info(
            'Foreground notification received, triggering immediate order refresh and in-app notification update',
            tag: 'PushNotification');
        await _handleOrderUpdateNotification(message);
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to display foreground notification: $e',
          tag: 'PushNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Handle notification tap
  /// Navigates to order details when user taps on notification
  void _handleNotificationTap(RemoteMessage message) {
    try {
      final data = message.data;
      final orderId = data['orderId'] ?? data['order_id'];
      final notificationType = data['type'] ?? '';

      if (orderId != null && notificationType == 'order_status_update') {
        Logger.info('Notification tapped for order: $orderId',
            tag: 'PushNotification');

        // Call navigation callback if set
        if (onNavigateToOrder != null) {
          onNavigateToOrder!(orderId.toString());
          Logger.info('Navigation callback triggered for order: $orderId',
              tag: 'PushNotification');
        } else {
          Logger.warning(
              'Navigation callback not set, notification tapped but navigation not handled',
              tag: 'PushNotification');
          Logger.warning(
              'Set callback using PushNotificationService().setNavigationCallback()',
              tag: 'PushNotification');
        }
      } else {
        Logger.info('Notification tapped but orderId not found or wrong type',
            tag: 'PushNotification');
      }

      Logger.info('Notification tap handled for message: ${message.messageId}',
          tag: 'PushNotification');
    } catch (e, stackTrace) {
      Logger.error('Error handling notification tap: $e',
          tag: 'PushNotification', error: e, stackTrace: stackTrace);
    }
  }

  /// Manually upload FCM token (useful when user logs in)
  Future<void> refreshToken() async {
    await _getFCMToken();
  }

  /// Subscribe to topics (optional)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      Logger.info('Subscribed to topic: $topic', tag: 'PushNotification');
    } catch (e) {
      Logger.error('Failed to subscribe to topic: $e',
          tag: 'PushNotification', error: e);
    }
  }

  /// Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      Logger.info('Unsubscribed from topic: $topic', tag: 'PushNotification');
    } catch (e) {
      Logger.error('Failed to unsubscribe from topic: $e',
          tag: 'PushNotification', error: e);
    }
  }

  /// Get backend URL from configuration
  String? _getBackendUrl() {
    try {
      final url = AppConfig.backendUrl;
      if (url.isEmpty) return null;

      // Allow localhost only for debug builds to ease development
      if (url.startsWith('http://localhost') ||
          url.startsWith('http://127.0.0.1')) {
        assert(() {
          Logger.info('Using localhost backend URL in debug mode: $url',
              tag: 'PushNotification');
          return true;
        }());
        // In release, still treat localhost as not configured
        return bool.fromEnvironment('dart.vm.product') ? null : url;
      }

      return url;
    } catch (e) {
      Logger.warning('Error getting backend URL: $e', tag: 'PushNotification');
      return null;
    }
  }
}
