import 'package:ecommerce_int2/app_properties.dart';
import 'package:ecommerce_int2/providers/auth_provider.dart';
import 'package:ecommerce_int2/providers/order_provider.dart';
import 'package:ecommerce_int2/providers/point_provider.dart';
import 'package:ecommerce_int2/screens/points/point_history_page.dart';
import 'package:ecommerce_int2/screens/auth/welcome_back_page.dart';
import 'package:ecommerce_int2/screens/main/main_page.dart';
import 'package:ecommerce_int2/screens/settings/settings_page.dart';
import 'package:ecommerce_int2/screens/wallet/wallet_page.dart';
import 'package:ecommerce_int2/screens/payment/payment_page.dart';
import 'package:ecommerce_int2/screens/tracking_page.dart';
import 'package:ecommerce_int2/screens/faq_page.dart';
import 'package:ecommerce_int2/screens/profile/my_profile_details_page.dart';
import 'package:ecommerce_int2/screens/orders/order_history_page.dart';
import 'package:ecommerce_int2/screens/orders/order_analytics_page.dart';
import 'package:ecommerce_int2/screens/address/address_list_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfilePageNew extends StatefulWidget {
  const ProfilePageNew({super.key});

  @override
  _ProfilePageNewState createState() => _ProfilePageNewState();
}

class _ProfilePageNewState extends State<ProfilePageNew> {
  @override
  void initState() {
    super.initState();
    // Ensure latest billing phone/city are merged from Woo on page open
    // Also load point balance when profile page opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pointProvider = Provider.of<PointProvider>(context, listen: false);
      
      // Refresh user data
      await authProvider.refreshUser();
      
      // Load point balance if user is authenticated (fallback if not loaded yet)
      if (authProvider.isAuthenticated && authProvider.user != null) {
        final userId = authProvider.user!.id.toString();
        // Force refresh to ensure latest balance is shown
        await pointProvider.loadBalance(userId, forceRefresh: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(mediumYellow),
              ),
            ),
          );
        }

        if (!authProvider.isAuthenticated) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 100,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Please login to view your profile',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => WelcomeBackPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mediumYellow,
                      padding:
                          EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final user = authProvider.user!;
        // User data logging removed - use Logger.debug() if needed for debugging

        return Scaffold(
          backgroundColor: Color(0xffF9F9F9),
          appBar: AppBar(
            title: Text('Profile'),
            backgroundColor: mediumYellow,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(Icons.logout),
                onPressed: () => _showLogoutDialog(context, authProvider),
              ),
            ],
          ),
          body: SafeArea(
            top: true,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                    left: 16.0, right: 16.0, top: kToolbarHeight),
                child: Column(
                  children: <Widget>[
                    CircleAvatar(
                      maxRadius: 48,
                      backgroundImage: AssetImage('assets/background.jpg'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        // Use live user name if available, else fallback
                        (user.displayName.isNotEmpty
                                ? user.displayName
                                : (user.firstName.isNotEmpty
                                    ? '${user.firstName} ${user.lastName}'
                                        .trim()
                                    : user.email))
                            .trim(),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 16.0),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8)),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: transparentYellow,
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: Offset(0, 1))
                          ]),
                      height: 150,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                IconButton(
                                  icon: Image.asset('assets/icons/wallet.png'),
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => WalletPage())),
                                ),
                                Text(
                                  'Wallet',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                IconButton(
                                  icon: Image.asset('assets/icons/truck.png'),
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => TrackingPage())),
                                ),
                                Text(
                                  'Shipped',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                IconButton(
                                  icon: Image.asset('assets/icons/card.png'),
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => PaymentPage())),
                                ),
                                Text(
                                  'Payment',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                IconButton(
                                  icon: Image.asset(
                                      'assets/icons/contact_us.png'),
                                  onPressed: () {},
                                ),
                                Text(
                                  'Support',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Order Management Section
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 16.0),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8)),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: transparentYellow,
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: Offset(0, 1))
                          ]),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text('My Orders'),
                            subtitle:
                                Text('View order history and track orders'),
                            leading: Image.asset('assets/icons/package.png',
                                width: 30, height: 30),
                            trailing: Consumer<OrderProvider>(
                              builder: (context, orderProvider, child) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (orderProvider.hasOrders)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: mediumYellow,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${orderProvider.orders.length}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    SizedBox(width: 8),
                                    Icon(Icons.chevron_right, color: yellow),
                                  ],
                                );
                              },
                            ),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => OrderHistoryPage())),
                          ),
                          Divider(height: 1),
                          ListTile(
                            title: Text('My Points'),
                            subtitle: Consumer<PointProvider>(
                              builder: (context, pointProvider, child) {
                                return Text(
                                  pointProvider.formattedBalance,
                                  style: TextStyle(
                                    color: mediumYellow,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                            leading: Icon(Icons.stars, color: mediumYellow, size: 30),
                            trailing: Icon(Icons.chevron_right, color: yellow),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => PointHistoryPage())),
                          ),
                          Divider(height: 1),
                          ListTile(
                            title: Text('Order Analytics'),
                            subtitle:
                                Text('View order statistics and insights'),
                            leading: Image.asset('assets/icons/list.png',
                                width: 30, height: 30),
                            trailing: Icon(Icons.chevron_right, color: yellow),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => OrderAnalyticsPage())),
                          ),
                          Divider(height: 1),
                          ListTile(
                            title: Text('Addresses'),
                            subtitle:
                                Text('Manage shipping and billing addresses'),
                            leading: Image.asset(
                                'assets/icons/address_home.png',
                                width: 30,
                                height: 30),
                            trailing: Icon(Icons.chevron_right, color: yellow),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => AddressListPage())),
                          ),
                        ],
                      ),
                    ),
                    // My Profile Section - Navigate to detail page
                    ListTile(
                      title: Text('My Profile'),
                      subtitle: Text('View and edit your profile information'),
                      leading: Image.asset('assets/icons/profile_icon.png',
                          width: 30, height: 30),
                      trailing: Icon(Icons.chevron_right, color: yellow),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MyProfileDetailsPage(),
                          ),
                        );
                      },
                    ),
                    // Support Section
                    ListTile(
                      title: Text('Settings'),
                      subtitle: Text('Privacy and logout'),
                      leading: Image.asset(
                        'assets/icons/settings_icon.png',
                        fit: BoxFit.scaleDown,
                        width: 30,
                        height: 30,
                      ),
                      trailing: Icon(Icons.chevron_right, color: yellow),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SettingsPage())),
                    ),
                    ListTile(
                      title: Text('Help & Support'),
                      subtitle: Text('Help center and legal support'),
                      leading: Image.asset('assets/icons/support.png'),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: yellow,
                      ),
                    ),
                    ListTile(
                      title: Text('FAQ'),
                      subtitle: Text('Questions and Answer'),
                      leading: Image.asset('assets/icons/faq.png'),
                      trailing: Icon(Icons.chevron_right, color: yellow),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => FaqPage())),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => MainPage()),
                (route) => false,
              );
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Removed unused helpers from the newer UI

  // Removed unused helpers from the newer UI
}
