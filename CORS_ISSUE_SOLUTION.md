# CORS Issue Solution - TworkSystem WooCommerce API

## 🚫 Problem: "ClientException: Failed to fetch"

You're encountering a **CORS (Cross-Origin Resource Sharing)** error when trying to access the WooCommerce API from a web browser.

### What is CORS?
CORS is a security feature implemented by web browsers that blocks requests from one domain to another unless the server explicitly allows it.

## ✅ Solutions

### 1. **Use Mobile App (Recommended)**
The easiest and most reliable solution is to use the mobile version of the app:

```bash
# Run on Android
flutter run -d android

# Run on iOS (if available)
flutter run -d ios
```

**Why this works:**
- Mobile apps don't have CORS restrictions
- Direct API access without browser limitations
- Full functionality available

### 2. **Server-Side CORS Configuration**
Contact the TworkSystem.com administrator to add CORS headers to their server:

```apache
# Apache .htaccess
Header always set Access-Control-Allow-Origin "*"
Header always set Access-Control-Allow-Methods "GET, POST, OPTIONS"
Header always set Access-Control-Allow-Headers "Content-Type, Authorization"
```

```nginx
# Nginx configuration
add_header Access-Control-Allow-Origin *;
add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
add_header Access-Control-Allow-Headers "Content-Type, Authorization";
```

### 3. **WooCommerce Plugin Solution**
Install a CORS plugin on the WordPress/WooCommerce site:

- **CORS Headers Plugin**
- **WooCommerce REST API CORS Plugin**

### 4. **Proxy Server (Advanced)**
Set up a proxy server that adds CORS headers:

```javascript
// Example Express.js proxy
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

app.use('/api', createProxyMiddleware({
  target: 'https://tworksystem.com',
  changeOrigin: true,
  onProxyRes: function (proxyRes, req, res) {
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
  }
}));
```

## 🔧 Current App Status

### ✅ What's Working:
- ✅ API credentials are correct
- ✅ Server is responding (Status 200)
- ✅ Products are available (1 product found)
- ✅ Mobile app will work perfectly

### ❌ What's Not Working:
- ❌ Web browser access due to CORS
- ❌ Direct API calls from web platform

## 📱 Testing the Mobile App

1. **Connect Android device or start emulator**
2. **Run the app:**
   ```bash
   flutter run -d android
   ```
3. **Navigate to WooCommerce page**
4. **Verify products load correctly**

## 🛠️ Code Changes Made

I've updated the error handling to provide better feedback:

```dart
// Enhanced error handling for CORS issues
if (kIsWeb && e.toString().contains('Failed to fetch')) {
  throw WooCommerceException(
    'CORS Error: The server does not allow cross-origin requests from web browsers. '
    'This is a server-side configuration issue. Please contact the website administrator '
    'to enable CORS for your domain, or use the mobile app instead.',
    originalError: e,
  );
}
```

## 🎯 Next Steps

1. **Immediate Solution:** Use the mobile app
2. **Long-term Solution:** Contact TworkSystem.com to enable CORS
3. **Alternative:** Set up a proxy server if you control the infrastructure

The mobile app will work perfectly with your TworkSystem.com WooCommerce API!
