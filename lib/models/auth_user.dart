class AuthUser {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String username;
  final String? avatar;
  final String? phone;
  final String? billingAddress;
  final String? billingCity;
  final String? billingCountry;
  final String? shippingAddress;
  final DateTime? dateCreated;
  final bool isEmailVerified;
  final List<String> roles;

  AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    this.avatar,
    this.phone,
    this.billingAddress,
    this.shippingAddress,
    this.billingCity,
    this.billingCountry,
    this.dateCreated,
    this.isEmailVerified = false,
    this.roles = const ['customer'],
  });

  String get fullName => ('$firstName $lastName').trim();
  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final dynamic metaDynamic = json['meta'];
    String? metaPhone;
    if (metaDynamic is Map<String, dynamic>) {
      metaPhone = metaDynamic['billing_phone'] as String?;
    } else if (metaDynamic is List) {
      // Some WP setups return meta as a list of key/value pairs; attempt to find billing_phone
      try {
        for (final item in metaDynamic) {
          if (item is Map && item.containsKey('billing_phone')) {
            final val = item['billing_phone'];
            if (val is String) {
              metaPhone = val;
              break;
            }
          }
        }
      } catch (_) {}
    }

    final Map<String, dynamic>? billingMap = json['billing'] is Map
        ? (json['billing'] as Map).cast<String, dynamic>()
        : null;
    final Map<String, dynamic>? shippingMap = json['shipping'] is Map
        ? (json['shipping'] as Map).cast<String, dynamic>()
        : null;

    return AuthUser(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      avatar: json['avatar_url'],
      phone: billingMap?['phone'] ?? shippingMap?['phone'] ?? metaPhone,
      billingAddress: _formatAddress(billingMap),
      shippingAddress: _formatAddress(shippingMap),
      dateCreated: json['date_created'] != null &&
              json['date_created'] is String &&
              (json['date_created'] as String).isNotEmpty
          ? DateTime.parse(json['date_created'])
          : null,
      isEmailVerified: json['is_paying_customer'] ?? false,
      roles: json['role'] != null ? [json['role']] : ['customer'],
      billingCity: billingMap?['city'] as String?,
      billingCountry: billingMap?['country'] as String?,
    );
  }

  static String? _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return null;

    List<String> parts = [];
    if (address['address_1']?.isNotEmpty == true) {
      parts.add(address['address_1']);
    }
    if (address['address_2']?.isNotEmpty == true) {
      parts.add(address['address_2']);
    }
    if (address['city']?.isNotEmpty == true) parts.add(address['city']);
    if (address['state']?.isNotEmpty == true) parts.add(address['state']);
    if (address['postcode']?.isNotEmpty == true) parts.add(address['postcode']);
    if (address['country']?.isNotEmpty == true) parts.add(address['country']);

    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'avatar_url': avatar,
      'billing': {
        'phone': phone,
        'city': billingCity,
        'country': billingCountry,
      },
      'shipping': {
        'phone': phone,
      },
      'meta': {
        'billing_phone': phone,
      },
      'date_created': dateCreated?.toIso8601String(),
      'is_paying_customer': isEmailVerified,
      'role': roles.isNotEmpty ? roles.first : 'customer',
    };
  }

  AuthUser copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? username,
    String? avatar,
    String? phone,
    String? billingAddress,
    String? billingCity,
    String? billingCountry,
    String? shippingAddress,
    DateTime? dateCreated,
    bool? isEmailVerified,
    List<String>? roles,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      phone: phone, // Allow null values to be set
      billingAddress: billingAddress ?? this.billingAddress,
      billingCity: billingCity ?? this.billingCity,
      billingCountry: billingCountry ?? this.billingCountry,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      dateCreated: dateCreated ?? this.dateCreated,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      roles: roles ?? this.roles,
    );
  }
}
