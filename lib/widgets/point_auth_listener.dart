import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/point_provider.dart';
import '../utils/logger.dart';

/// Widget that listens to authentication state changes
/// and automatically loads point balance when user is authenticated
class PointAuthListener extends StatefulWidget {
  final Widget child;

  const PointAuthListener({
    super.key,
    required this.child,
  });

  @override
  State<PointAuthListener> createState() => _PointAuthListenerState();
}

class _PointAuthListenerState extends State<PointAuthListener> {
  String? _lastUserId;
  bool _hasInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check auth state when dependencies change (providers available)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadPoints();
    });
  }

  void _checkAuthAndLoadPoints() {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final pointProvider = Provider.of<PointProvider>(context, listen: false);

    if (authProvider.isAuthenticated && authProvider.user != null) {
      final userId = authProvider.user!.id.toString();
      
      // Only load if this is a new user or first initialization
      if (_lastUserId != userId || !_hasInitialized) {
        _lastUserId = userId;
        _hasInitialized = true;
        
        Logger.info('User authenticated, loading point balance for user: $userId',
            tag: 'PointAuthListener');
        
        // Load balance asynchronously without blocking UI
        pointProvider.handleAuthStateChange(
          isAuthenticated: true,
          userId: userId,
        ).catchError((e) {
          Logger.error('Error loading points on auth: $e',
              tag: 'PointAuthListener', error: e);
        });
      }
    } else if (_lastUserId != null) {
      // User logged out
      _lastUserId = null;
      _hasInitialized = false;
      pointProvider.handleAuthStateChange(
        isAuthenticated: false,
        userId: null,
      ).catchError((e) {
        Logger.error('Error clearing points on logout: $e',
            tag: 'PointAuthListener', error: e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth changes - this will rebuild when auth state changes
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Check if auth state changed
        final currentUserId = authProvider.user?.id.toString();
        final isAuthenticated = authProvider.isAuthenticated;
        
        // Only trigger check if state actually changed
        if ((isAuthenticated && currentUserId != _lastUserId) ||
            (!isAuthenticated && _lastUserId != null) ||
            (isAuthenticated && !_hasInitialized)) {
          // Use post-frame callback to avoid calling during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _checkAuthAndLoadPoints();
            }
          });
        }
        
        return widget.child;
      },
    );
  }
}

