import 'dart:convert';
import 'dart:math' as math;
import 'package:ecommerce_int2/app_properties.dart';
import 'package:ecommerce_int2/custom_background.dart';
import 'package:ecommerce_int2/models/product.dart';
import 'package:ecommerce_int2/woocommerce_service.dart';
import 'package:ecommerce_int2/screens/category/category_list_page.dart';
import 'package:ecommerce_int2/screens/notifications_page.dart';
import 'package:ecommerce_int2/widgets/notification_badge.dart';
import 'package:ecommerce_int2/widgets/network_status_banner.dart';
import 'package:ecommerce_int2/services/connectivity_service.dart';
import 'package:ecommerce_int2/screens/profile/profile_page_new.dart';
import 'package:ecommerce_int2/screens/search_page.dart';
import 'package:ecommerce_int2/screens/shop/check_out_page.dart';
import 'package:ecommerce_int2/screens/orders/order_dashboard_page.dart';
import 'package:ecommerce_int2/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/custom_bottom_bar.dart';
import 'components/tab_view.dart';
import 'components/weekly_featured_showcase.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with TickerProviderStateMixin<MainPage> {
  late TabController tabController;
  late TabController bottomTabController;
  List<Product> products = [];
  bool isLoading = true;
  bool _isDisposed = false;
  static const String _cachedProductsKey = 'cached_products';

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 5, vsync: this);
    bottomTabController = TabController(length: 4, vsync: this);
    // Load cached products first, then fetch fresh data if online
    _initializeProducts();
  }

  /// Initialize products: load cache first, then fetch fresh if online
  Future<void> _initializeProducts() async {
    // Load cached products first (synchronous-like behavior)
    await _loadCachedProducts();

    // Then try to fetch fresh products if online
    // This ensures cached products are shown immediately even if offline
    _loadProducts();
  }

  @override
  void dispose() {
    _isDisposed = true;
    tabController.dispose();
    bottomTabController.dispose();
    super.dispose();
  }

  /// Load cached products from local storage
  Future<void> _loadCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cachedProductsKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> cachedData = json.decode(cachedJson);
        final cachedProducts = cachedData
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList();

        if (cachedProducts.isNotEmpty) {
          if (mounted) {
            setState(() {
              products = cachedProducts;
              isLoading = false; // Set loading to false when cache is loaded
            });
          }
          Logger.info('Loaded ${cachedProducts.length} cached products',
              tag: 'MainPage');
        } else {
          Logger.info('Cached products list is empty', tag: 'MainPage');
        }
      } else {
        Logger.info('No cached products found', tag: 'MainPage');
        // If no cache and we're offline, set loading to false to show empty state
        final connectivityService = ConnectivityService();
        if (!connectivityService.isConnected && mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Error loading cached products: $e',
          tag: 'MainPage', error: e);
      // On error, set loading to false if offline
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected && mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Save products to local storage for offline viewing
  Future<void> _saveProductsToCache(List<Product> productsToCache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson =
          json.encode(productsToCache.map((p) => p.toJson()).toList());
      await prefs.setString(_cachedProductsKey, productsJson);
      Logger.info('Cached ${productsToCache.length} products', tag: 'MainPage');
    } catch (e) {
      Logger.error('Error caching products: $e', tag: 'MainPage', error: e);
    }
  }

  Future<void> _loadProducts({int page = 1}) async {
    if (_isDisposed) return;

    Logger.info('Loading products for page $page', tag: 'MainPage');

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // Check connectivity first
      final connectivityService = ConnectivityService();
      final isOnline = connectivityService.isConnected;

      if (!isOnline) {
        Logger.info('Device is offline, loading cached products',
            tag: 'MainPage');
        // Always try to load cached products when offline
        await _loadCachedProducts();
        // Set loading to false to show cached products
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final stopwatch = Stopwatch()..start();
      final wooProducts =
          await WooCommerceService.getProducts(perPage: 20, page: page).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.warning('Product loading timeout', tag: 'MainPage');
          throw Exception('Request timeout');
        },
      );
      stopwatch.stop();

      Logger.logPerformance('Load Products', stopwatch.elapsed);

      if (_isDisposed) return;

      final convertedProducts =
          wooProducts.map((wooProduct) => wooProduct.toProduct()).toList();

      // Cache products for offline viewing
      await _saveProductsToCache(convertedProducts);

      if (mounted) {
        setState(() {
          products = convertedProducts;
          isLoading = false;
        });
      }

      Logger.info('Successfully loaded ${convertedProducts.length} products',
          tag: 'MainPage');
    } catch (e, stackTrace) {
      Logger.logError('Load Products', e, stackTrace: stackTrace);
      // On error, try to load cached products as fallback
      if (mounted) {
        // Try to load cached products if available
        if (products.isEmpty) {
          await _loadCachedProducts();
        }
        setState(() {
          // Don't clear products on error - keep cached ones
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkStatusBanner(
      child: _buildMainContent(context),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    Widget appBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          NotificationBadge(
            child: IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationsPage(),
                ),
              ),
              icon: const Icon(Icons.notifications),
              tooltip: 'Notifications',
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SearchPage()),
                ),
                icon: SvgPicture.asset('assets/icons/search_icon.svg'),
                tooltip: 'Search products',
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      bottomNavigationBar: CustomBottomBar(controller: bottomTabController),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDashboardPage()),
          );
        },
        backgroundColor: mediumYellow,
        tooltip: 'Order Management',
        child: Icon(Icons.shopping_bag, color: Colors.white),
      ),
      body: CustomPaint(
        painter: MainBackground(),
        child: TabBarView(
          controller: bottomTabController,
          physics: NeverScrollableScrollPhysics(),
          children: <Widget>[
            SafeArea(
              child: NestedScrollView(
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                  // These are the slivers that show up in the "outer" scroll view.
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: appBar,
                    ),
                    SliverToBoxAdapter(
                      child: isLoading
                          ? SizedBox(
                              height: _heroCarouselHeight(context),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      mediumYellow),
                                ),
                              ),
                            )
                          : products.isEmpty
                              ? _buildEmptyProductState(context)
                              : RefreshIndicator(
                                  onRefresh: _refreshSelectedTimeline,
                                  color: mediumYellow,
                                  child: SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12.0,
                                      ),
                                      child: WeeklyFeaturedShowcase(
                                        products: products,
                                        onViewAll: () =>
                                            bottomTabController.animateTo(1),
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                    SliverToBoxAdapter(
                      child: tabBar,
                    )
                  ];
                },
                body: TabView(
                  tabController: tabController,
                ),
              ),
            ),
            CategoryListPage(),
            CheckOutPage(),
            ProfilePageNew()
          ],
        ),
      ),
    );
  }

  Future<void> _refreshSelectedTimeline() {
    return _loadProducts(page: 1);
  }

  Widget get tabBar {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        indicatorColor: mediumYellow,
        indicatorWeight: 3,
        labelColor: darkGrey,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'Montserrat',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          fontFamily: 'Montserrat',
        ),
        tabs: const [
          Tab(text: 'For You'),
          Tab(text: 'Popular'),
          Tab(text: 'New In'),
          Tab(text: 'Collections'),
          Tab(text: 'Sale'),
        ],
      ),
    );
  }

  double _heroCarouselHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final calculated = screenHeight * 0.4;
    return math.max(260.0, math.min(calculated, 360.0));
  }

  Widget _buildEmptyProductState(BuildContext context) {
    final placeholderHeight = _heroCarouselHeight(context);
    return RefreshIndicator(
      onRefresh: _refreshSelectedTimeline,
      color: mediumYellow,
      child: SizedBox(
        height: placeholderHeight,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: placeholderHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 52,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No products available',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
