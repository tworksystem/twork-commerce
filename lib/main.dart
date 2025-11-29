import 'package:ecommerce_int2/screens/splash_page.dart';
import 'package:ecommerce_int2/screens/orders/order_details_page.dart';
import 'package:ecommerce_int2/providers/auth_provider.dart';
import 'package:ecommerce_int2/providers/cart_provider.dart';
import 'package:ecommerce_int2/providers/order_provider.dart';
import 'package:ecommerce_int2/providers/address_provider.dart';
import 'package:ecommerce_int2/providers/review_provider.dart';
import 'package:ecommerce_int2/providers/wishlist_provider.dart';
import 'package:ecommerce_int2/providers/product_filter_provider.dart';
import 'package:ecommerce_int2/providers/point_provider.dart';
import 'package:ecommerce_int2/providers/category_provider.dart';
import 'package:ecommerce_int2/providers/in_app_notification_provider.dart';
import 'package:ecommerce_int2/services/notification_service.dart';
import 'package:ecommerce_int2/services/background_service.dart';
import 'package:ecommerce_int2/services/active_sync_service.dart';
import 'package:ecommerce_int2/services/push_notification_service.dart';
import 'package:ecommerce_int2/services/connectivity_service.dart';
import 'package:ecommerce_int2/services/offline_queue_service.dart';
import 'package:ecommerce_int2/services/point_service.dart';
import 'package:ecommerce_int2/services/app_logger.dart';
import 'package:ecommerce_int2/services/log_buffer_service.dart';
import 'package:ecommerce_int2/services/global_keys.dart';
import 'package:ecommerce_int2/utils/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_int2/models/order.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.initialize();
  LogBufferService.initialize();

  await AppLogger.guard(() async {
    // Initialize connectivity service first (needed by other services)
    await ConnectivityService().initialize();
    Logger.info('Connectivity service initialized', tag: 'Main');

    // Initialize offline queue service
    await OfflineQueueService().initialize();
    Logger.info('Offline queue service initialized', tag: 'Main');
    PointService.registerOfflineQueueHandler();

    // Initialize in-app notification provider (singleton instance)
    final notificationProvider = InAppNotificationProvider.instance;
    await notificationProvider.initialize();
    Logger.info('In-app notification provider initialized', tag: 'Main');

    // Initialize notification service
    await NotificationService().initialize();

    // Background service for periodic order checks (unsupported on web)
    if (!kIsWeb) {
      await BackgroundService.initialize();
      await BackgroundService.registerPeriodicTask();
    } else {
      Logger.info('Skipping background service initialization on web',
          tag: 'Main');
    }

    // Firebase Cloud Messaging (FCM) for instant push notifications
    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      Logger.info('Firebase initialized successfully', tag: 'Main');

      // Register background message handler (mobile only)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);
      }

      // Initialize push notification service
      await PushNotificationService().initialize();
      Logger.info('Push notification service initialized', tag: 'Main');
    } catch (e) {
      Logger.error('Firebase initialization failed: $e', tag: 'Main', error: e);
      // App will continue without push notifications (fallback to polling)
    }

    runApp(MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start polling after frame is built (when providers are ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startActiveSyncWithRetry();
      _setupPushNotificationCallbacks();
    });
  }

  /// Setup push notification callbacks for instant order updates
  void _setupPushNotificationCallbacks() {
    // Setup callback for order refresh when notification arrives
    PushNotificationService().setOrderUpdateCallback(
        (String orderId, Map<String, dynamic> data) async {
      try {
        Logger.info('FCM notification received, refreshing orders immediately',
            tag: 'Main');

        // Get providers from context
        final orderProvider =
            Provider.of<OrderProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        // Use singleton instance to ensure we're updating the same provider instance used in UI
        final notificationProvider = InAppNotificationProvider.instance;

        // Reload notifications to update count immediately
        await notificationProvider.loadNotifications();
        Logger.info(
            'Notification count updated after FCM notification (${notificationProvider.unreadCount} unread)',
            tag: 'Main');

        if (authProvider.isAuthenticated && authProvider.user != null) {
          final userId = authProvider.user!.id.toString();

          // Trigger immediate order sync to get latest status
          // Skip notifications during sync since push notification already created it
          Logger.info(
              'Triggering immediate order sync after FCM notification (skipping duplicate notifications)',
              tag: 'Main');
          await orderProvider.syncOrdersWithWooCommerce(userId,
              skipNotifications: true);

          Logger.info('Orders refreshed successfully after FCM notification',
              tag: 'Main');
        } else {
          Logger.warning('User not authenticated, skipping order refresh',
              tag: 'Main');
        }
      } catch (e, stackTrace) {
        Logger.error('Error refreshing orders after FCM notification: $e',
            tag: 'Main', error: e, stackTrace: stackTrace);
      }
    });

    // Setup callback for navigation when notification is tapped
    PushNotificationService().setNavigationCallback((String orderId) async {
      try {
        Logger.info('Navigating to order details: $orderId', tag: 'Main');

        // Get order provider to find the order
        final orderProvider =
            Provider.of<OrderProvider>(context, listen: false);

        // Find order by ID (handle both WC- prefix and plain ID)
        Order? order;
        try {
          // Try to find by WooCommerce ID
          order = orderProvider.orders.firstWhere(
            (o) =>
                o.metadata?['woocommerce_id']?.toString() == orderId ||
                o.id == 'WC-$orderId' ||
                o.id == orderId,
            orElse: () => throw StateError('Order not found'),
          );
        } catch (e) {
          Logger.warning(
              'Order not found in local cache, need to sync: $orderId',
              tag: 'Main');

          // If order not found, sync orders first
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.isAuthenticated && authProvider.user != null) {
            await orderProvider
                .syncOrdersWithWooCommerce(authProvider.user!.id.toString());

            // Try to find order again after sync
            try {
              order = orderProvider.orders.firstWhere(
                (o) =>
                    o.metadata?['woocommerce_id']?.toString() == orderId ||
                    o.id == 'WC-$orderId' ||
                    o.id == orderId,
                orElse: () => throw StateError('Order not found'),
              );
            } catch (e2) {
              Logger.error('Order still not found after sync: $orderId',
                  tag: 'Main');
              return;
            }
          } else {
            Logger.warning('User not authenticated, cannot navigate to order',
                tag: 'Main');
            return;
          }
        }

        // Navigate to order details page
        if (AppKeys.navigatorKey.currentContext != null) {
          Navigator.of(AppKeys.navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (context) => OrderDetailsPage(order: order!),
            ),
          );
          Logger.info('Navigated to order details: $orderId', tag: 'Main');
        } else {
          Logger.warning('Navigator context not available, cannot navigate',
              tag: 'Main');
        }
      } catch (e, stackTrace) {
        Logger.error('Error navigating to order details: $e',
            tag: 'Main', error: e, stackTrace: stackTrace);
      }
    });

    Logger.info('Push notification callbacks configured successfully',
        tag: 'Main');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - start active polling for near-instant notifications
      _startActiveSync();

      // Refresh notification count when app comes to foreground
      try {
        final notificationProvider = InAppNotificationProvider.instance;
        notificationProvider.loadNotifications();
        Logger.info('Notification count refreshed on app resume', tag: 'Main');
      } catch (e) {
        Logger.error('Error refreshing notifications on app resume: $e',
            tag: 'Main', error: e);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - stop active polling to save battery
      _stopActiveSync();
    }
  }

  /// Start active sync with retry in case auth is not ready yet
  Future<void> _startActiveSyncWithRetry({int retry = 0}) async {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isAuthenticated && authProvider.user != null) {
        await ActiveSyncService().startPolling(
          orderProvider: orderProvider,
          authProvider: authProvider,
        );
      } else if (retry < 5) {
        // Retry after 1 second if auth not ready yet
        await Future.delayed(Duration(seconds: 1));
        _startActiveSyncWithRetry(retry: retry + 1);
      }
    } catch (e, stackTrace) {
      Logger.error('Error starting active sync: $e',
          tag: 'Main', error: e, stackTrace: stackTrace);
    }
  }

  /// Start active sync polling for near-instant notifications
  Future<void> _startActiveSync() async {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isAuthenticated && authProvider.user != null) {
        await ActiveSyncService().startPolling(
          orderProvider: orderProvider,
          authProvider: authProvider,
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Error starting active sync: $e',
          tag: 'Main', error: e, stackTrace: stackTrace);
    }
  }

  /// Stop active sync polling when app goes to background
  void _stopActiveSync() {
    ActiveSyncService().stopPolling();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ProductFilterProvider()),
        ChangeNotifierProvider(create: (_) => PointProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider.value(value: InAppNotificationProvider.instance),
        // Connectivity and offline services
        ChangeNotifierProvider.value(value: ConnectivityService()),
        ChangeNotifierProvider.value(value: OfflineQueueService()),
      ],
      child: MaterialApp(
        navigatorKey: AppKeys
            .navigatorKey, // Global navigator key for navigation from anywhere
        scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
        title: 'T-Work Commerce',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          canvasColor: Colors.transparent,
          primarySwatch: Colors.blue,
          fontFamily: "Montserrat",
        ),
        home: SplashScreen(),
      ),
    );
  }
}
