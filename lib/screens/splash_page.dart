import 'package:ecommerce_int2/app_properties.dart';
import 'package:ecommerce_int2/screens/auth/welcome_back_page.dart';
import 'package:ecommerce_int2/screens/main/main_page.dart';
import 'package:ecommerce_int2/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late Animation<double> opacity;
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        duration: Duration(milliseconds: 2500), vsync: this);
    opacity = Tween<double>(begin: 1.0, end: 0.0).animate(controller)
      ..addListener(() {
        setState(() {});
      });
    controller.forward().then((_) {
      _checkAuthAndNavigate();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Check authentication state and navigate accordingly
  /// This ensures users stay logged in and don't get auto-logged out
  void _checkAuthAndNavigate() {
    // Wait for AuthProvider to initialize if not ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Maximum wait time: 3 seconds to prevent infinite waiting
      const maxWaitTime = Duration(seconds: 3);
      final startTime = DateTime.now();

      void checkWithTimeout() {
        final elapsed = DateTime.now().difference(startTime);

        // If still loading and haven't exceeded max wait time, wait a bit more
        if (authProvider.isLoading && elapsed < maxWaitTime) {
          Future.delayed(Duration(milliseconds: 200), () {
            if (mounted) {
              checkWithTimeout();
            }
          });
          return;
        }

        // Navigate based on authentication state (even if still loading after timeout)
        if (authProvider.isAuthenticated) {
          // User is logged in - go to main page
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => MainPage()),
            );
          }
        } else {
          // User is not logged in - go to login page
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => WelcomeBackPage()),
            );
          }
        }
      }

      checkWithTimeout();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          image: DecorationImage(
              image: AssetImage('assets/background.jpg'), fit: BoxFit.cover)),
      child: Container(
        decoration: BoxDecoration(color: transparentYellow),
        child: SafeArea(
          child: Scaffold(
            body: Column(
              children: <Widget>[
                Expanded(
                  child: Opacity(
                      opacity: opacity.value,
                      child: Image.asset('assets/logo.png')),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RichText(
                    text: TextSpan(
                        style: TextStyle(color: Colors.black),
                        children: [
                          TextSpan(text: 'Powered by '),
                          TextSpan(
                              text: 'T-Work System Co.,Ltd.',
                              style: TextStyle(fontWeight: FontWeight.bold))
                        ]),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
