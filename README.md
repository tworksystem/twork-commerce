# T-Work Commerce

<div align="center">

**Modern Flutter E-Commerce Platform**

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-ready, cross-platform e-commerce application built with Flutter, integrated with WooCommerce and WordPress. Features enterprise-grade loyalty program, offline support, real-time notifications, and comprehensive payment solutions.

[Features](#-features) • [Quick Start](#-getting-started) • [Architecture](#-architecture) • [Documentation](#-documentation) • [Contributing](#-contributing)

</div>

---

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuration](#configuration)
- [Project Structure](#-project-structure)
- [Development](#-development)
- [Testing](#-testing)
- [Deployment](#-deployment)
- [Security](#-security)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Support](#-support)

---

## ✨ Features

### 🛍️ E-Commerce Core
- **Multi-channel Storefront** – Weekly curated hero sections, animated product details, and intuitive navigation
- **Advanced Search & Filtering** – Deep search with bottom sheet UX, category filtering, and product recommendations
- **Shopping Cart** – Persistent cart with offline support, quantity management, and real-time price calculations
- **Checkout Flow** – Streamlined checkout process with multiple payment options and address management
- **Order Management** – Complete order history, tracking, and status updates with real-time notifications

### 💰 Payments & Wallet
- **Multiple Payment Methods** – Credit cards, digital wallets, and voucher support
- **P2P Money Transfer** – Send and request money flows with transaction history
- **Dynamic Payment Summaries** – Real-time calculation of totals, discounts, and taxes
- **Secure Payment Processing** – Encrypted payment data handling with secure storage

### 🎁 Loyalty & Points System
- **Points Earning** – Automatic points on purchases, referrals, reviews, and special events
- **Points Redemption** – Redeem points for discounts with configurable redemption rates
- **Offline Queue** – Points transactions queued locally and synced when connectivity resumes
- **Transaction History** – Complete audit trail of all point transactions with expiration tracking
- **WordPress Integration** – Custom plugin for server-side points management and synchronization

### 📱 User Experience
- **Offline Support** – Full offline functionality with automatic sync when online
- **Push Notifications** – Firebase Cloud Messaging integration for order updates and promotions
- **In-App Notifications** – Notification center with rich content and action buttons
- **Background Services** – WorkManager integration for background order polling and sync
- **Network Status** – Real-time connectivity monitoring with user-friendly indicators

### 🛠️ Developer Experience
- **State Management** – Provider pattern for reactive UI updates
- **Error Handling** – Comprehensive error handling with retry mechanisms and user-friendly messages
- **Logging & Monitoring** – Structured logging with multiple sinks (console, analytics, crash reporting)
- **Code Quality** – Linting, formatting, and analysis tools configured
- **Testing** – Unit, widget, and integration tests with mocktail for mocking

---

## 🏗️ Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Application                      │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Screens/Widgets)                                  │
│  ├─ State Management (Provider)                              │
│  └─ Navigation & Routing                                     │
├─────────────────────────────────────────────────────────────┤
│  Business Logic Layer (Services)                              │
│  ├─ WooCommerce Service      │  Auth Service                 │
│  ├─ Point Service            │  Payment Service              │
│  ├─ Offline Queue Service    │  Notification Service         │
│  └─ Secure Storage Service   │  Connectivity Service          │
├─────────────────────────────────────────────────────────────┤
│  Data Layer (Models/Storage)                                  │
│  ├─ Local Storage (SharedPreferences, SecureStorage)         │
│  ├─ Network Layer (HTTP Client with Retry)                   │
│  └─ Offline Queue (SQLite via sqflite)                       │
└─────────────────────────────────────────────────────────────┘
                            ↕ REST API
┌─────────────────────────────────────────────────────────────┐
│              WordPress/WooCommerce Backend                     │
│  ├─ WooCommerce REST API                                     │
│  ├─ T-Work Points System Plugin                              │
│  └─ Custom REST Endpoints                                    │
└─────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Description | Key Components |
|-------|-------------|----------------|
| **UI Layer** | Presentation and user interaction | `lib/screens/`, `lib/widgets/` |
| **State Management** | Reactive state updates | `lib/providers/` (Provider pattern) |
| **Service Layer** | Business logic and API communication | `lib/services/` |
| **Data Layer** | Models and data persistence | `lib/models/`, local storage, network |
| **Backend** | WordPress/WooCommerce integration | `wp-content/plugins/twork-points-system/` |

### Key Design Patterns

- **Provider Pattern** – State management for reactive UI
- **Repository Pattern** – Data access abstraction
- **Service Layer Pattern** – Business logic separation
- **Offline-First** – Queue-based sync for offline operations
- **Retry Pattern** – Exponential backoff for network requests

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** 3.24 or higher ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Dart SDK** 3.3 or higher (included with Flutter)
- **Android Studio** or **Xcode** (for mobile development)
- **VS Code** or **Android Studio** (recommended IDEs)
- **Git** for version control
- **Node.js** 16+ (for backend webhook server, optional)

Verify your setup:

```bash
flutter doctor
```

Ensure all checks pass before proceeding.

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/tworksystem/twork-commerce.git
cd twork-commerce
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Generate localization files** (if applicable)

```bash
flutter gen-l10n
```

4. **Run the application**

```bash
# For connected device/emulator
flutter run

# For specific platform
flutter run -d chrome      # Web
flutter run -d macos       # macOS
flutter run -d windows      # Windows
flutter run -d linux       # Linux
```

### Configuration

#### 1. WooCommerce API Credentials

⚠️ **SECURITY WARNING**: Never commit API keys or secrets to version control!

1. Open `lib/utils/app_config.dart`
2. Replace the placeholder values:

```dart
static const String consumerKey = 'YOUR_CONSUMER_KEY_HERE';
static const String consumerSecret = 'YOUR_CONSUMER_SECRET_HERE';
```

**Recommended Approach**: Use environment variables or secure storage:

```dart
// Option 1: Environment variables (recommended for CI/CD)
static final String consumerKey = 
    const String.fromEnvironment('CONSUMER_KEY', defaultValue: '');

// Option 2: Secure storage (recommended for runtime)
static Future<String> getConsumerKey() async {
  final secureStorage = FlutterSecureStorage();
  return await secureStorage.read(key: 'consumer_key') ?? '';
}
```

#### 2. Backend Configuration

Update the backend URL in `lib/utils/app_config.dart`:

```dart
static const String baseUrl = 'https://your-woocommerce-site.com/wp-json/wc/v3';
static const String wpBaseUrl = 'https://your-woocommerce-site.com/wp-json/wp/v2';
static const String backendUrl = 'https://your-backend-server.com';
```

#### 3. Firebase Configuration (Push Notifications)

**Android:**
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/google-services.json`
3. Ensure it's in `.gitignore` (already configured)

**iOS:**
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it in `ios/Runner/GoogleService-Info.plist`
3. Ensure it's in `.gitignore` (already configured)

#### 4. WordPress Plugin Installation

1. Copy `wp-content/plugins/twork-points-system/` to your WordPress installation
2. Activate the plugin through WordPress admin panel
3. The plugin will automatically create required database tables
4. Verify API endpoints are accessible at `/wp-json/twork/v1/`

For detailed plugin documentation, see [README_POINTS_SYSTEM.md](README_POINTS_SYSTEM.md) and [docs/POINTS_ARCHITECTURE.md](docs/POINTS_ARCHITECTURE.md).

---

## 📁 Project Structure

```
twork-commerce/
├── lib/
│   ├── main.dart                    # Application entry point
│   ├── screens/                     # UI screens organized by feature
│   │   ├── auth/                    # Authentication screens
│   │   ├── main/                    # Main navigation and home
│   │   ├── product/                 # Product listing and details
│   │   ├── shop/                    # Shopping cart and checkout
│   │   ├── orders/                  # Order management
│   │   ├── wallet/                  # Wallet and payments
│   │   ├── points/                  # Points and loyalty
│   │   ├── profile/                 # User profile
│   │   └── settings/                # App settings
│   ├── services/                    # Business logic and API services
│   │   ├── auth_service.dart        # Authentication
│   │   ├── woocommerce_service.dart # WooCommerce API integration
│   │   ├── point_service.dart       # Points system
│   │   ├── payment_service.dart     # Payment processing
│   │   ├── offline_queue_service.dart # Offline sync queue
│   │   ├── notification_service.dart  # Push/local notifications
│   │   └── connectivity_service.dart  # Network monitoring
│   ├── providers/                   # State management (Provider)
│   │   ├── auth_provider.dart
│   │   ├── cart_provider.dart
│   │   ├── order_provider.dart
│   │   └── point_provider.dart
│   ├── models/                      # Data models and DTOs
│   │   ├── product.dart
│   │   ├── order.dart
│   │   ├── point_transaction.dart
│   │   └── ...
│   ├── widgets/                     # Reusable UI components
│   │   ├── notification_badge.dart
│   │   ├── network_status_banner.dart
│   │   └── ...
│   └── utils/                       # Utilities and helpers
│       ├── app_config.dart          # App configuration
│       ├── logger.dart              # Logging utilities
│       ├── error_handler.dart      # Error handling
│       └── network_utils.dart      # Network utilities
├── test/                            # Test files
│   ├── unit/                        # Unit tests
│   ├── widget/                      # Widget tests
│   └── integration/                 # Integration tests
├── docs/                            # Documentation
│   └── POINTS_ARCHITECTURE.md      # Points system architecture
├── wp-content/
│   └── plugins/
│       └── twork-points-system/    # WordPress plugin
├── backend/                         # Backend services (optional)
│   └── webhook_server.js           # Webhook server for notifications
├── assets/                          # Images, fonts, and other assets
├── android/                         # Android-specific files
├── ios/                             # iOS-specific files
├── web/                             # Web-specific files
├── pubspec.yaml                     # Flutter dependencies
├── analysis_options.yaml           # Linting and analysis rules
└── README.md                        # This file
```

---

## 💻 Development

### Code Style

This project follows the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide. Code is automatically formatted and analyzed.

**Format code:**
```bash
flutter format .
```

**Analyze code:**
```bash
flutter analyze
```

**Run both:**
```bash
flutter format . && flutter analyze
```

### Development Workflow

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the existing code style
   - Write tests for new features
   - Update documentation as needed

3. **Run tests and checks**
   ```bash
   flutter test
   flutter format .
   flutter analyze
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

5. **Push and create a Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

### Hot Reload & Hot Restart

- **Hot Reload** (`r` in terminal): Fast refresh for UI changes
- **Hot Restart** (`R` in terminal): Full app restart
- **Quit** (`q` in terminal): Stop the app

---

## 🧪 Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/auth_service_test.dart

# Run tests in watch mode
flutter test --watch
```

### Test Structure

- **Unit Tests**: Test individual functions and classes
- **Widget Tests**: Test UI components in isolation
- **Integration Tests**: Test complete user flows

### Writing Tests

Example unit test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('PointService', () {
    test('should calculate points correctly', () {
      // Test implementation
    });
  });
}
```

---

## 🚢 Deployment

### Building for Production

**Android:**
```bash
flutter build apk --release          # APK
flutter build appbundle --release    # App Bundle (Play Store)
```

**iOS:**
```bash
flutter build ios --release
# Then archive and upload via Xcode
```

**Web:**
```bash
flutter build web --release
```

**Desktop:**
```bash
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

### Environment-Specific Builds

For different environments (dev, staging, production), use build flavors:

```bash
# Android flavors
flutter build apk --flavor production --release

# iOS schemes
flutter build ios --release --flavor production
```

### Pre-Deployment Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Update `CHANGELOG.md` (if maintained)
- [ ] Run all tests: `flutter test`
- [ ] Run analysis: `flutter analyze`
- [ ] Test on physical devices (iOS and Android)
- [ ] Verify API endpoints and credentials
- [ ] Test offline functionality
- [ ] Verify push notifications
- [ ] Check app icons and splash screens
- [ ] Review app permissions
- [ ] Test payment flows (if applicable)

---

## 🔒 Security

### Best Practices

1. **Never Commit Secrets**
   - API keys, passwords, and tokens should never be in version control
   - Use environment variables or secure storage
   - The repository has been cleaned of any previously committed secrets

2. **Secure Storage**
   - Use `flutter_secure_storage` for sensitive data
   - Encrypt data at rest when possible
   - Use HTTPS for all API communications

3. **API Security**
   - Validate all user inputs
   - Use HTTPS only
   - Implement proper authentication and authorization
   - Rate limiting on backend

4. **Code Obfuscation** (Optional)
   ```bash
   flutter build apk --release --obfuscate --split-debug-info=./debug-info
   ```

### Security Checklist

- [ ] All API keys stored securely (not in code)
- [ ] HTTPS enforced for all network requests
- [ ] User data encrypted at rest
- [ ] Authentication tokens stored securely
- [ ] Input validation on all user inputs
- [ ] Error messages don't expose sensitive information
- [ ] Dependencies are up to date (check `flutter pub outdated`)

---

## 🐛 Troubleshooting

### Common Issues

#### 1. Build Errors

**Problem**: `flutter pub get` fails
```bash
# Solution: Clean and reinstall
flutter clean
flutter pub get
```

**Problem**: iOS build fails
```bash
# Solution: Update pods
cd ios
pod deintegrate
pod install
cd ..
```

#### 2. API Connection Issues

- Verify WooCommerce API credentials in `app_config.dart`
- Check network connectivity
- Verify backend URL is correct
- Check CORS settings (for web)

#### 3. Offline Queue Not Syncing

- Check connectivity service is running
- Verify offline queue service is initialized
- Check logs for sync errors
- Ensure backend endpoints are accessible

#### 4. Push Notifications Not Working

- Verify Firebase configuration files are present
- Check device token registration
- Verify backend webhook server is running (if applicable)
- Check notification permissions

#### 5. Points Not Updating

- Verify WordPress plugin is activated
- Check API authentication
- Review point service logs
- Verify database tables exist

### Getting Help

1. Check existing [Issues](https://github.com/tworksystem/twork-commerce/issues)
2. Review documentation in `docs/` folder
3. Check [Flutter documentation](https://flutter.dev/docs)
4. Contact support: support@tworksystem.com

---

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Contribution Process

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
   - Follow code style guidelines
   - Write or update tests
   - Update documentation
4. **Commit your changes** (follow commit message convention)
5. **Push to your branch** (`git push origin feature/amazing-feature`)
6. **Open a Pull Request**

### Pull Request Guidelines

- Provide a clear description of changes
- Reference related issues
- Ensure all tests pass
- Update documentation as needed
- Keep PRs focused and scoped

### Code Review

All PRs require review before merging. Reviewers will check:
- Code quality and style
- Test coverage
- Documentation updates
- Security considerations

---

## 📄 License

Copyright (c) 2025 T-Work Commerce

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

**Copyright Notice**:
- Copyright (c) 2025 T-Work Commerce. All rights reserved.
- This software is provided under the MIT License, which permits use, modification, and distribution subject to the terms and conditions specified in the LICENSE file.
- The copyright notice and permission notice must be included in all copies or substantial portions of the software.

**Note**: Assets, fonts, and other third-party resources may have separate licenses. Please check individual file headers and respect their respective licensing terms.

---

## 📞 Support

- **Documentation**: Check `docs/` folder for detailed guides
- **Issues**: [GitHub Issues](https://github.com/tworksystem/twork-commerce/issues)
- **Email**: support@tworksystem.com
- **Website**: [www.tworksystem.com](https://www.tworksystem.com)

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - UI framework
- [WooCommerce](https://woocommerce.com) - E-commerce platform
- [WordPress](https://wordpress.org) - CMS and backend
- All contributors and maintainers

---

<div align="center">

**Made with ❤️ by the T-Work Team**

[⬆ Back to Top](#t-work-commerce)

</div>
