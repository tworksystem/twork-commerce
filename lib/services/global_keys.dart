import 'package:flutter/material.dart';

/// Central registry for application-wide navigator and scaffold keys.
///
/// Keeping the keys in a dedicated file prevents circular dependencies
/// between widgets and services that need to surface UI (e.g. snackbar
/// notifications from background services).
class AppKeys {
  AppKeys._();

  /// Global navigator key used for cross-module navigation.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Global scaffold messenger key to display snackbars from services.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
}

