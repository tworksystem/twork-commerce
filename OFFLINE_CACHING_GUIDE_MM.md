# Offline Caching လမ်းညွှန် (မြန်မာ)

## အကျဉ်းချုပ်
သင့် Flutter eCommerce app မှာ professional offline caching system တစ်ခု ထည့်သွင်းပြီးပါပြီ။ အင်တာနက် မရှိလျှင်တောင် products များကို ကြည့်ရှုနိုင်မှာဖြစ်ပါသည်။

## Features (လုပ်ဆောင်ချက်များ)

### ✅ ပြီးမြောက်ပြီး

1. **Product Caching** (ကုန်ပစ္စည်း သိမ်းဆည်းမှု)
   - WooCommerce products များကို local database (Hive) မှာ သိမ်းဆည်း
   - 24 နာရီ cache expiry (သတ်မှတ်ချိန် ကုန်ဆုံးမှု)
   - အလိုအလျောက် update လုပ်ခြင်း

2. **Image Caching** (ပုံများ သိမ်းဆည်းမှု)
   - CachedNetworkImage သုံးပြီး အလိုအလျောက် cache
   - Memory နှင့် disk cache
   - Progressive loading

3. **Network Connectivity Monitoring** (အင်တာနက် စောင့်ကြည့်မှု)
   - Real-time connectivity status
   - Automatic reconnection handling
   - Offline indicator

4. **Cache Management UI** (Cache စီမံမှု မျက်နှာပြင်)
   - Cache statistics ကြည့်ရန်
   - Clear cache manually
   - Cache size monitoring

## အသုံးပြုနည်း

### 1. App ကို Run လုပ်ရန်
```bash
cd /Users/clickrmedia/mawkunn/t-commerce/demo/twork-commerce
flutter run
```

### 2. Offline Mode စမ်းသပ်ရန်

#### နည်းလမ်း ၁: Airplane Mode
1. App ကို ဖွင့်ပြီး products များ load လုပ်ပါ
2. Phone ရဲ့ Airplane Mode ကို ဖွင့်ပါ
3. App ကို refresh လုပ်ပါ
4. Cached products များ ပေါ်လာပါမည်

#### နည်းလမ်း ၂: WiFi Off
1. App ကို ဖွင့်ပြီး products များ load လုပ်ပါ
2. WiFi/Mobile Data ကို ပိတ်ပါ
3. App ကို refresh လုပ်ပါ
4. "Offline" badge ပေါ်မည်

### 3. Cache Management

#### Cache Statistics ကြည့်ရန်:
1. Settings သို့ သွားပါ
2. "Cache Management" ကို နှိပ်ပါ
3. Statistics များ ကြည့်ပါ

#### Cache Clear လုပ်ရန်:
1. Cache Management page သွားပါ
2. အောက်ပါ options များထဲမှ ရွေးပါ:
   - Clear Product Cache
   - Clear Image Cache
   - Clear All Cache

## Technical Details (နည်းပညာ အသေးစိတ်)

### Packages Used
```yaml
hive: ^2.2.3              # Local database
hive_flutter: ^1.1.0       # Flutter integration
cached_network_image: ^3.3.1  # Image caching
connectivity_plus: ^5.0.2  # Network monitoring
path_provider: ^2.1.2      # File paths
shared_preferences: ^2.2.2 # Settings
```

### Cache Strategy

#### 1. API-First with Fallback
```
Online:  API → Cache → Display
Offline: Cache → Display
Error:   Cache (older) → Display
```

#### 2. Cache Expiry
- **Default**: 24 hours
- **On Error**: 7 days (older cache accepted)
- **Manual Refresh**: Force API call

#### 3. Cache Keys
```dart
"products_p1_pp20_featured"    // Featured products
"products_p1_pp20_sale"        // On sale products
"products_p1_pp20_obdate_odesc" // Latest products
```

### File Structure

```
lib/
├── models/
│   ├── cached_product.dart       # Hive model
│   └── cached_product.g.dart     # Generated adapter
├── services/
│   ├── cache_service.dart        # Cache operations
│   ├── connectivity_service.dart # Network monitoring
│   └── woocommerce_service_cached.dart # API with cache
├── screens/
│   └── settings/
│       └── cache_management_page.dart # Cache UI
└── widgets/
    └── product_image_widget.dart # Cached images
```

## Cache Behavior (အလုပ်လုပ်ပုံ)

### Scenario 1: First Launch (ပထမဆုံး ဖွင့်တဲ့အခါ)
```
1. App starts
2. Check connectivity: Online ✓
3. Fetch from API
4. Save to cache
5. Display products
```

### Scenario 2: Offline Mode (Offline အခြေအနေ)
```
1. App starts / Refresh
2. Check connectivity: Offline ✗
3. Load from cache
4. Display with "Offline" indicator
5. Show cached products
```

### Scenario 3: Cache Expired (Cache သက်တမ်းကုန်)
```
Online:
1. Detect expired cache
2. Fetch fresh data from API
3. Update cache
4. Display new products

Offline:
1. Detect expired cache
2. Show expired cache anyway
3. Display "Offline" warning
```

### Scenario 4: Connection Restored (အင်တာနက် ပြန်ရ)
```
1. Detect connection
2. Auto-refresh in background
3. Update cache silently
4. Remove "Offline" indicator
```

## Cache Management

### Automatic Management
- ✅ Auto-initialize on app start
- ✅ Auto-update when online
- ✅ Auto-cleanup expired entries
- ✅ Memory optimization

### Manual Management
- 🔧 Clear product cache
- 🔧 Clear image cache
- 🔧 Clear all cache
- 📊 View statistics

## Performance Optimization

### Memory Cache
```dart
memCacheHeight: height * 2
memCacheWidth: width * 2
```

### Disk Cache
```dart
maxHeightDiskCache: 1000
maxWidthDiskCache: 1000
```

### Database
- Hive: Fast NoSQL database
- Indexed by cache keys
- Compressed storage

## User Experience Features

### 1. Offline Indicator
```
🔴 "Offline" badge ပြသ
📦 Cached data အသုံးပြုနေကြောင်း ပြသ
```

### 2. Refresh Button
```
🔄 Manual refresh လုပ်နိုင်
🌐 Force API call
```

### 3. Notifications
```
✅ "Showing cached products (Offline mode)"
❌ "No internet and no cached data"
🔄 "Refreshing..."
```

### 4. Cache Statistics
```
📊 Total products cached
🔑 Number of cache keys
💾 Storage size
⏰ Last updated time
```

## Troubleshooting (ပြဿနာ ဖြေရှင်းနည်း)

### Products မပေါ်လျှင်

#### Check 1: Internet Connection
```
1. Settings → Cache Management
2. Check "Connection Status"
3. If offline, cached data သာ ပေါ်မည်
```

#### Check 2: Cache Availability
```
1. Cache Management → Statistics
2. "Total Products" ကြည့်ပါ
3. 0 ဆိုရင် internet လိုပါမည်
```

#### Check 3: Cache Expiry
```
1. Cache Management → Clear Cache
2. Reconnect to internet
3. Reload products
```

### Images မပေါ်လျှင်

#### Solution 1: Clear Image Cache
```
Settings → Cache Management → Clear Image Cache
```

#### Solution 2: Check Internet
```
First load needs internet
Subsequent loads use cache
```

### App ကြာလျှင်

#### Option 1: Clear Old Cache
```
Cache Management → Clear Product Cache
```

#### Option 2: Optimize
```
Cache automatically limited to 1000x1000 pixels
Memory managed automatically
```

## Best Practices

### For Users (အသုံးပြုသူများအတွက်)

1. **ပထမဆုံး အင်တာနက်နဲ့ ဖွင့်ပါ**
   - Products များ download ဖို့

2. **Cache ကို ရံဖန်ရံခါ clear လုပ်ပါ**
   - Storage space သက်သာစေဖို့

3. **WiFi မှာ ပုံများ download လုပ်ပါ**
   - Data သုံးစွဲမှု လျှော့နည်းစေဖို့

### For Developers (Developer များအတွက်)

1. **Cache Expiry ကို သတ်မှတ်နိုင်**
```dart
await CacheService.setCacheExpiryHours(48); // 48 hours
```

2. **Force Refresh လုပ်နိုင်**
```dart
await WooCommerceServiceCached.getProducts(
  forceRefresh: true,
);
```

3. **Custom Cache Keys**
```dart
final cacheKey = 'custom_key_${categoryId}';
```

## Cache Size Management

### Estimated Sizes
```
1 Product:    ~3.5 KB
10 Products:  ~35 KB
100 Products: ~350 KB
1 Image:      ~50-200 KB
```

### Recommendations
```
Products: Keep last 100 (350 KB)
Images: Keep last 50 (2.5-10 MB)
Total: ~3-11 MB reasonable
```

## Future Enhancements

### Coming Soon
- [ ] Smart cache warming
- [ ] Selective category caching
- [ ] Background sync
- [ ] Cache priority levels
- [ ] Compression optimization

## အရေးကြီးသော မှတ်ချက်များ

1. **First Launch**: အင်တာနက် လိုပါသည်
2. **Cache Expiry**: 24 နာရီ default
3. **Storage**: ~10-50 MB reasonable
4. **Auto-Update**: အင်တာနက်ရတဲ့အခါ အလိုအလျောက်
5. **Manual Clear**: Settings မှာ ရှိပါသည်

## Support

ပြဿနာ ရှိလျှင်:
1. Cache Management → Clear All Cache
2. Restart app
3. Check console logs

---

**Status**: ✅ Production-Ready
**Version**: 1.0.0
**Date**: October 11, 2025

