# WooCommerce Integration - Home Aid Myanmar

## 🚀 Professional WooCommerce REST API Integration

This Flutter app is professionally integrated with **Home Aid Myanmar** e-commerce store using WooCommerce REST API v3.

### 🏪 Store Information

- **Store Name:** Home Aid Myanmar
- **Website:** https://www.homeaid.com.mm/
- **API Version:** WooCommerce REST API v3
- **Products:** Home Appliances, Electronics, Kitchen Appliances, Mobile Phones, Computers, CCTV, and more

---

## 📋 Features Implemented

### ✅ Core Features

1. **WooCommerce REST API Integration**
   - Full REST API v3 implementation
   - Secure authentication with Consumer Key & Secret
   - Real-time product data synchronization

2. **Product Management**
   - Display all products from HomeAid.com.mm
   - Featured products showcase
   - Product details with images, prices, ratings
   - Stock status tracking
   - Sale/Discount badges
   - Category filtering

3. **Offline Support & Caching**
   - Smart caching mechanism
   - Persistent storage with SharedPreferences
   - Offline product viewing
   - Cache expiration management
   - Automatic cache refresh

4. **Error Handling & Recovery**
   - Comprehensive error handling
   - Network error detection
   - Timeout management
   - Graceful fallback to cached data
   - User-friendly error messages

5. **UI/UX Features**
   - Pull-to-refresh functionality
   - Loading states with indicators
   - Product image caching
   - Responsive grid layout
   - Product detail modal sheets
   - Sale badges and featured tags
   - Rating stars display

---

## 🏗️ Architecture & Code Structure

### Clean Architecture Pattern

```
lib/
├── config/
│   └── woocommerce_config.dart      # API configuration & credentials
├── models/
│   ├── woocommerce_product.dart     # Product model
│   └── woocommerce_product.g.dart   # Generated serialization
├── services/
│   ├── woocommerce_service.dart     # API service layer
│   └── product_repository.dart      # Repository pattern
├── widgets/
│   └── woocommerce_product_list.dart # Product list widget
└── screens/
    └── main/
        └── woocommerce_page.dart     # Main products page
```

### Key Classes

#### 1. **WooCommerceConfig** (`lib/config/woocommerce_config.dart`)
- Centralized API configuration
- Consumer Key & Secret management
- Endpoint definitions
- Cache settings

#### 2. **WooCommerceService** (`lib/services/woocommerce_service.dart`)
- HTTP API calls
- Authentication
- Error handling
- Response parsing
- Connection testing

#### 3. **ProductRepository** (`lib/services/product_repository.dart`)
- Data management layer
- Caching logic
- Offline support
- Search functionality

#### 4. **WooCommerceProduct** (`lib/models/woocommerce_product.dart`)
- Product data model
- JSON serialization
- Helper methods (pricing, ratings, etc.)

---

## 🔐 API Credentials

The following credentials are configured in `lib/config/woocommerce_config.dart`:

```dart
baseUrl: 'https://www.homeaid.com.mm'
consumerKey: 'YOUR_CONSUMER_KEY_HERE'
consumerSecret: 'YOUR_CONSUMER_SECRET_HERE'
```

**Security Note:** In production, these should be stored in environment variables or secure storage.

---

## 📦 Dependencies

All required dependencies are configured in `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.2.0                      # HTTP requests
  json_annotation: ^4.9.0           # JSON serialization
  shared_preferences: ^2.2.2        # Local storage
  cached_network_image: ^3.3.1      # Image caching
  flutter_rating_bar: ^4.0.0        # Rating stars

dev_dependencies:
  build_runner: any                 # Code generation
  json_serializable: any            # JSON serialization
```

---

## 🚀 How to Use

### 1. View All Products

```dart
import 'package:ecommerce_int2/screens/main/woocommerce_page.dart';

// Navigate to WooCommerce products page
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => WooCommercePage()),
);
```

### 2. Use the Product List Widget

```dart
import 'package:ecommerce_int2/widgets/woocommerce_product_list.dart';

// Display all products
WooCommerceProductList(featured: false)

// Display only featured products
WooCommerceProductList(featured: true)
```

### 3. Access Products Programmatically

```dart
import 'package:ecommerce_int2/services/product_repository.dart';

final repository = ProductRepository();

// Get all products
final products = await repository.getProducts();

// Get featured products
final featured = await repository.getFeaturedProducts();

// Search products
final results = await repository.searchProducts('headphones');

// Get product by ID
final product = await repository.getProductById(123);
```

---

## 🔧 Configuration

### Change API Credentials

Edit `lib/config/woocommerce_config.dart`:

```dart
class WooCommerceConfig {
  static const String baseUrl = 'https://your-store.com';
  static const String consumerKey = 'your_consumer_key';
  static const String consumerSecret = 'your_consumer_secret';
}
```

### Adjust Cache Settings

```dart
// Cache expiration time
static const Duration cacheExpiration = Duration(hours: 1);

// Maximum cached products
static const int maxCacheSize = 100;
```

---

## 🧪 Testing

### Test API Connection

```dart
final repository = ProductRepository();
final isConnected = await repository.testConnection();

if (isConnected) {
  print('✅ API connected successfully!');
} else {
  print('❌ API connection failed');
}
```

### View Cache Info

```dart
final cacheInfo = repository.getCacheInfo();
print('Cached products: ${cacheInfo['cachedProducts']}');
print('Last fetch: ${cacheInfo['lastFetchTime']}');
print('Cache valid: ${cacheInfo['isCacheValid']}');
```

---

## 📱 Running the App

### Install Dependencies

```bash
flutter pub get
```

### Generate Model Files

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Run the App

```bash
# For Android
flutter run

# For iOS
flutter run -d ios

# For specific device
flutter devices
flutter run -d <device-id>
```

### Build Release

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

---

## 🎯 Best Practices Implemented

1. **Repository Pattern** - Clean separation of data layer
2. **Error Handling** - Comprehensive try-catch blocks
3. **Caching Strategy** - Smart offline support
4. **Loading States** - User-friendly loading indicators
5. **Code Documentation** - Detailed comments and documentation
6. **Type Safety** - Strong typing throughout
7. **Null Safety** - Flutter 3.0+ null safety
8. **Model Serialization** - Automatic JSON serialization
9. **Separation of Concerns** - Clean architecture
10. **Performance** - Image caching, lazy loading

---

## 🔍 API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/wp-json/wc/v3/products` | GET | Fetch all products |
| `/wp-json/wc/v3/products?featured=true` | GET | Fetch featured products |
| `/wp-json/wc/v3/products/{id}` | GET | Fetch single product |
| `/wp-json/wc/v3/products?search=query` | GET | Search products |

---

## 📚 API Documentation

For complete WooCommerce REST API documentation:
- [WooCommerce REST API Docs](https://woocommerce.github.io/woocommerce-rest-api-docs/)
- [WooCommerce API Guide](https://woocommerce.com/document/woocommerce-rest-api/)

---

## 🐛 Troubleshooting

### Issue: Products not loading

1. Check internet connection
2. Verify API credentials in `woocommerce_config.dart`
3. Check console logs for error messages
4. Test API connection: `await repository.testConnection()`

### Issue: Images not displaying

1. Ensure products have images in WooCommerce
2. Check image URLs are HTTPS
3. Clear app cache and restart

### Issue: Build errors

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

---

## 👨‍💻 Developer Notes

### Code Generation

When you modify `woocommerce_product.dart`, regenerate the `.g.dart` files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Adding New Fields

1. Add field to `WooCommerceProduct` model
2. Add `@JsonKey` annotation if needed
3. Run code generation
4. Update UI to display new field

---

## 📝 License

This integration is part of the T-Work Commerce app.

---

## 🙏 Acknowledgments

- **Home Aid Myanmar** (homeaid.com.mm) - For providing the WooCommerce store
- **WooCommerce** - For the excellent REST API
- **Flutter Team** - For the amazing framework

---

## 📞 Support

For technical support or questions:
- Check the troubleshooting section above
- Review WooCommerce API documentation
- Inspect console logs for detailed error messages

---

**Built with ❤️ using Flutter & WooCommerce REST API**

**Last Updated:** October 14, 2025
**Integration Version:** 1.0.0
**WooCommerce API Version:** v3

