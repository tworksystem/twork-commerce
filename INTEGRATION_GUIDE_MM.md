# WooCommerce Integration လမ်းညွှန် (မြန်မာ)

## အကျဉ်းချုပ်
HomeAid.com.mm website မှ products များကို Flutter app တွင် WooCommerce REST API သုံးပြီး ပြသနိုင်အောင် ပြုလုပ်ထားပါသည်။

## လုပ်ဆောင်ထားသည့် အရာများ

### 1. Configuration Files (သတ်မှတ်ချက်ဖိုင်များ)
- **`lib/config/woocommerce_config.dart`**: WooCommerce API credentials နှင့် endpoints များ
  - Website: https://www.homeaid.com.mm
  - Consumer Key နှင့် Secret ကို လုံခြုံစွာ သိမ်းဆည်းထား
  - API version: WooCommerce v3

### 2. Data Models (ဒေတာမော်ဒယ်များ)
- **`lib/models/woocommerce_product.dart`**: WooCommerce product အပြည့်အစုံ
  - Product အချက်အလက်အားလုံးပါဝင် (အမည်၊ စျေးနှုန်း၊ ပုံများ၊ အမျိုးအစားများ)
  - Images, Categories, Tags, Attributes များအတွက် သီးခြား models များ

- **`lib/models/product.dart`**: ရှိပြီးသား Product model ကို update လုပ်ထား
  - WooCommerce products များကို convert လုပ်နိုင်
  - ရှိပြီးသား code များနှင့် အလုပ်လုပ်နိုင်

### 3. API Service (API ဝန်ဆောင်မှု)
- **`lib/services/woocommerce_service.dart`**: WooCommerce API ခေါ်ယူရန်
  - Featured products များယူရန်
  - On sale products များယူရန်
  - နောက်ဆုံးထွက် products များယူရန်
  - Product ရှာဖွေရန်
  - Category အလိုက် filter လုပ်ရန်
  - Pagination support
  - Error handling ကောင်းမွန်စွာ ပြုလုပ်ထား

### 4. UI Updates (အသုံးပြုသူမျက်နှာပြင် အဆင့်မြှင့်တင်မှု)
- **Main Page**: WooCommerce မှ products များပြသ
  - Featured (ထူးခြားသော)
  - On Sale (လျှော့စျေးရှိသော)
  - Latest (နောက်ဆုံးထွက်)
- Loading indicators (ခေတ္တစောင့်ပါ သင်္ကေတများ)
- Error handling (အမှားကိုင်တွယ်မှု) နှင့် retry buttons
- Network images support (အင်တာနက်မှ ပုံများပြသ)

### 5. Reusable Widgets (ပြန်သုံးနိုင်သော Widgets)
- **`lib/widgets/product_image_widget.dart`**: ပုံပြသရန် widget
  - Asset နှင့် network images နှစ်မျိုးလုံး support
  - Loading states
  - Error handling

## အသုံးပြုနည်း

### App ကို Run လုပ်ရန်
```bash
cd /Users/clickrmedia/mawkunn/t-commerce/demo/twork-commerce
flutter run
```

### WooCommerce Connection စစ်ဆေးရန်
```bash
# Test file ကို run လုပ်ပါ
flutter run lib/test_woocommerce.dart
```

## Features (လုပ်ဆောင်ချက်များ)

### ✅ ပြီးမြောက်ပြီး
1. HomeAid website မှ products များ ပြသခြင်း
2. Featured products ပြသခြင်း
3. On sale products ပြသခြင်း
4. နောက်ဆုံးထွက် products ပြသခြင်း
5. Network images load လုပ်ခြင်း
6. Error handling နှင့် retry functionality
7. Loading states ပြသခြင်း

### 🔄 နောက်ထပ် လုပ်ဆောင်နိုင်သည်များ
1. Product search (ရှာဖွေမှု)
2. Category filtering (အမျိုးအစားအလိုက် စစ်ထုတ်မှု)
3. Shopping cart နှင့် checkout
4. User authentication (အသုံးပြုသူဝင်ရောက်မှု)
5. Order management (အော်ဒါစီမံမှု)
6. Product reviews (သုံးသပ်ချက်များ)

## အသေးစိတ်အချက်အလက်များ

### Configuration File Location
```
lib/config/woocommerce_config.dart
```

### API Credentials
- Base URL: https://www.homeaid.com.mm
- Consumer Key: YOUR_CONSUMER_KEY_HERE
- Consumer Secret: YOUR_CONSUMER_SECRET_HERE

### Main Files Modified
1. `lib/screens/main/main_page.dart` - Products ပြသသည့် main page
2. `lib/screens/main/components/product_list.dart` - Product list widget
3. `lib/screens/main/components/recommended_list.dart` - Recommended products
4. `lib/models/product.dart` - Product model

## Testing (စမ်းသပ်မှု)

### 1. App ကို စမ်းသပ်ရန်
```bash
flutter run
```

### 2. Connection စမ်းသပ်ရန်
`lib/test_woocommerce.dart` file ကို အသုံးပြုပါ

### 3. စစ်ဆေးရမည့်အချက်များ
- [ ] App ဖွင့်တဲ့အခါ products များ ပေါ်လာပါသလား
- [ ] Featured, On Sale, Latest tabs များ အလုပ်လုပ်ပါသလား
- [ ] ပုံများ မှန်မှန်ပြသပါသလား
- [ ] Product အမည်နှင့် စျေးနှုန်းများ မှန်ပါသလား
- [ ] Product ကို နှိပ်လိုက်တဲ့အခါ details page သွားပါသလား

## Error Handling (အမှားကိုင်တွယ်မှု)

### အင်တာနက် မရှိလျှင်
- Error message ပြသမည်
- Retry button ပေါ်မည်

### API Error ဖြစ်လျှင်
- အသေးစိတ် error message ပြသမည်
- Console တွင် log များ ပြမည်

### ပုံများ load မဖြစ်လျှင်
- Placeholder image ပြသမည်
- အခြား products များ အလုပ်လုပ်နေမည်

## အရေးကြီးသော မှတ်ချက်များ

1. **Internet connection လိုအပ်သည်**: Products များ ကြည့်ရန် internet လိုပါသည်
2. **WooCommerce site လုပ်ဆောင်နေရမည်**: HomeAid website လုပ်ဆောင်နေရပါမည်
3. **HTTPS သုံးထားသည်**: လုံခြုံမှု အတွက် HTTPS သုံးထားပါသည်

## ပြဿနာ ဖြေရှင်းနည်း

### Products များ မပေါ်လျှင်
1. Internet connection စစ်ပါ
2. https://www.homeaid.com.mm ကို browser မှာ ဖွင့်ကြည့်ပါ
3. Console logs များကို စစ်ပါ

### ပုံများ မပေါ်လျှင်
1. WooCommerce မှာ ပုံများ upload လုပ်ထားပါသလား စစ်ပါ
2. Image URLs များ မှန်ပါသလား စစ်ပါ

## ဆက်သွယ်ရန်

ပြဿနာရှိလျှင် သို့မဟုတ် အကူအညီလိုလျှင်:
- Console logs များကို ကြည့်ပါ
- Error messages များကို မှတ်တမ်းတင်ပါ
- Screenshot ရိုက်ပါ

---

**Integration ပြီးစီးပြီ**: ✅
**Date**: October 11, 2025
**Status**: Production-Ready (အသုံးပြုနိုင်ပြီ)

