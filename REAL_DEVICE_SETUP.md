# Real Device Setup Guide - Flutter App
## iOS နဲ့ Android Devices မှာ Run နည်း

---

## 📱 iOS Device (iPhone/iPad) Setup

### Prerequisites
- macOS with Xcode installed
- Apple ID account
- iPhone/iPad with iOS 12.0 or higher
- Lightning/USB-C cable

### Step-by-Step Instructions

#### 1. Install Xcode (if not installed)
```bash
# Check if Xcode is installed
xcode-select --print-path

# If not, install from App Store or run:
xcode-select --install
```

#### 2. Connect Your iPhone/iPad
1. Connect your iPhone/iPad to Mac using USB cable
2. Unlock your device
3. If prompted, tap **"Trust This Computer"** on your iPhone
4. Enter your device passcode

#### 3. Configure Xcode
```bash
# Open Xcode
open -a Xcode

# Or manually:
# 1. Open Xcode
# 2. Go to Preferences → Accounts
# 3. Add your Apple ID if not already added
```

#### 4. Set Up Signing
1. Open project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select **Runner** in project navigator
3. Go to **Signing & Capabilities** tab
4. Select your Team (Apple ID)
5. Xcode will automatically create provisioning profile

#### 5. Verify Device Connection
```bash
# Check if device is detected
flutter devices

# You should see something like:
# iPhone 14 Pro (mobile) • 00008110-XXXXX • ios • iOS 17.0
```

#### 6. Run on Device
```bash
# Run directly
flutter run

# Or specify device
flutter run -d <device-id>

# Example:
flutter run -d 00008110-XXXXX
```

### Common iOS Issues

#### Issue 1: "Untrusted Developer"
**Error**: "Untrusted Developer" message on iPhone

**Solution**:
1. Go to iPhone Settings
2. General → VPN & Device Management
3. Tap on your developer certificate
4. Tap "Trust [Developer Name]"

#### Issue 2: Code Signing Error
**Error**: "No signing certificate found"

**Solution**:
1. Open Xcode
2. Preferences → Accounts
3. Select your Apple ID
4. Click "Download Manual Profiles"
5. Try running again

#### Issue 3: Device Not Detected
**Error**: Device not showing in `flutter devices`

**Solution**:
```bash
# Restart usbmuxd
sudo pkill usbmuxd

# Unplug and replug device
# Then run:
flutter devices

# If still not working:
flutter doctor -v
```

---

## 🤖 Android Device Setup

### Prerequisites
- Android device with Android 4.1 (API 16) or higher
- USB cable
- Android SDK installed (comes with Flutter)

### Step-by-Step Instructions

#### 1. Enable Developer Mode
1. Go to **Settings** on your Android device
2. Scroll to **About Phone** (or **About Device**)
3. Find **Build Number**
4. Tap **Build Number** 7 times
5. You'll see "You are now a developer!" message

#### 2. Enable USB Debugging
1. Go back to **Settings**
2. Find **Developer Options** (usually in System or Advanced)
3. Enable **Developer Options** toggle
4. Scroll down and enable **USB Debugging**
5. (Optional) Enable **Install via USB** for easier testing

#### 3. Connect Your Device
1. Connect your Android device to Mac using USB cable
2. On your device, you'll see a prompt:
   - **"Allow USB debugging?"**
3. Check **"Always allow from this computer"**
4. Tap **OK** or **Allow**

#### 4. Verify Connection
```bash
# Check if device is detected
flutter devices

# You should see something like:
# SM G991B (mobile) • R5CT123XXXX • android-arm64 • Android 13 (API 33)
```

#### 5. Run on Device
```bash
# Run directly (if only one device)
flutter run

# Or specify device
flutter run -d <device-id>

# Example:
flutter run -d R5CT123XXXX

# For specific build mode:
flutter run -d <device-id> --release
```

### Android-Specific Commands

```bash
# Check ADB connection
flutter doctor -v

# List all ADB devices
adb devices

# If device unauthorized:
adb kill-server
adb start-server

# Install debug APK manually
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk

# View device logs
flutter logs
```

### Common Android Issues

#### Issue 1: Device Not Detected
**Error**: Device not in `flutter devices` list

**Solution**:
```bash
# Restart ADB server
adb kill-server
adb start-server

# Check if device is visible
adb devices

# If shows "unauthorized":
# 1. Revoke USB debugging on phone (Developer Options)
# 2. Turn off USB debugging
# 3. Turn on USB debugging again
# 4. Replug cable
# 5. Accept prompt on phone
```

#### Issue 2: "No permissions"
**Error**: Permission denied errors

**Solution**:
```bash
# On Linux/Mac:
sudo adb devices

# Or fix permissions:
sudo usermod -aG plugdev $LOGNAME
```

#### Issue 3: Multiple Devices
**Error**: "More than one device connected"

**Solution**:
```bash
# List all devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Or run on all devices
flutter run -d all
```

#### Issue 4: USB Charging Only
**Error**: Phone only charging, not detected

**Solution**:
1. Try different USB cable (some cables are charge-only)
2. Try different USB port
3. On phone: Pull down notification → Tap USB → Select "File Transfer" or "MTP"

---

## 🔧 General Troubleshooting

### Check Flutter Setup
```bash
# Run doctor to check setup
flutter doctor -v

# Should show:
# ✓ Flutter
# ✓ Android toolchain
# ✓ Xcode (for iOS)
# ✓ Connected device
```

### Fix Common Issues
```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Rebuild
flutter run
```

### Performance Tips
```bash
# Run in release mode (better performance)
flutter run --release

# Run in profile mode (performance profiling)
flutter run --profile

# Hot reload during development
# Press 'r' in terminal while app is running
```

---

## 📊 Device Testing Checklist

### Before Running
- [ ] Device is connected via USB
- [ ] USB debugging enabled (Android)
- [ ] Device is trusted (iOS)
- [ ] Device appears in `flutter devices`
- [ ] Battery is charged (>20%)

### While Running
- [ ] App installs successfully
- [ ] No overflow errors in console
- [ ] UI looks correct
- [ ] Touch interactions work
- [ ] Navigation works
- [ ] Images load properly

### Test Scenarios for Overflow Fixes
- [ ] Browse product categories
- [ ] View product cards
- [ ] Check product names (long and short)
- [ ] Verify discount prices display correctly
- [ ] Test on different screen sizes
- [ ] Rotate device (portrait/landscape)
- [ ] Check dark mode (if supported)
- [ ] Test with different font sizes (accessibility)

---

## 🚀 Quick Commands Reference

### iOS
```bash
# Run on iOS device
flutter run

# Build iOS release
flutter build ios --release

# Open in Xcode
open ios/Runner.xcworkspace
```

### Android
```bash
# Run on Android device
flutter run

# Build Android APK
flutter build apk --release

# Build Android App Bundle (for Play Store)
flutter build appbundle --release

# Install specific APK
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Both Platforms
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run on all devices
flutter run -d all

# View logs
flutter logs

# Clean project
flutter clean

# Hot reload
# Press 'r' in terminal

# Hot restart
# Press 'R' in terminal

# Quit
# Press 'q' in terminal
```

---

## 📱 Wireless Debugging (Advanced)

### iOS Wireless Debugging
1. Connect iPhone via USB first
2. Open Xcode → Window → Devices and Simulators
3. Select your device
4. Check "Connect via network"
5. Disconnect USB cable
6. Device will now connect wirelessly

### Android Wireless Debugging
```bash
# Connect via USB first
adb devices

# Enable TCP/IP mode
adb tcpip 5555

# Find device IP (Settings → About → Status → IP address)
# Or:
adb shell ip -f inet addr show wlan0

# Connect wirelessly
adb connect <device-ip>:5555

# Example:
adb connect 192.168.1.100:5555

# Disconnect USB cable
# Verify wireless connection
adb devices

# To disconnect:
adb disconnect <device-ip>:5555
```

---

## 🎯 Testing Our Overflow Fixes

### What to Test
After connecting your device, test these specific scenarios to verify overflow fixes:

#### 1. Category Cards
- Navigate to home screen
- Scroll through category cards horizontally
- **Expected**: No yellow/black stripes, all text visible

#### 2. Product Cards
- View product swiper
- Check products with long names
- Check products with discounts
- **Expected**: Text truncates with ellipsis, no overflow

#### 3. Product List
- View product grid
- Test with various product names
- **Expected**: All cards same size, no overflow

#### 4. Shop Cart
- Add items to cart
- View checkout page
- **Expected**: Product names and prices fit properly

### Screenshots to Take
1. Home screen with categories
2. Product swiper with long product names
3. Product grid view
4. Checkout page with items

---

## 📞 Need Help?

If you encounter issues:

1. **Check Flutter Doctor**
   ```bash
   flutter doctor -v
   ```

2. **View Logs**
   ```bash
   flutter logs
   ```

3. **Clean and Rebuild**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Check Device**
   ```bash
   flutter devices -v
   ```

---

**Document Version**: 1.0  
**Created**: October 10, 2025  
**Purpose**: Guide for running Flutter app on real devices  
**Status**: ✅ Complete

