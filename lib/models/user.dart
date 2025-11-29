/// User model for mock API responses
/// This model represents a user with basic information
class User {
  final Name name;
  final Picture picture;
  final String phone;

  User({
    required this.name,
    required this.picture,
    required this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: Name.fromJson(json['name'] ?? {}),
      picture: Picture.fromJson(json['picture'] ?? {}),
      phone: json['phone'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name.toJson(),
      'picture': picture.toJson(),
      'phone': phone,
    };
  }
}

/// Name model with first and last name
class Name {
  final String first;
  final String last;

  Name({
    required this.first,
    required this.last,
  });

  factory Name.fromJson(Map<String, dynamic> json) {
    return Name(
      first: json['first'] ?? '',
      last: json['last'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first': first,
      'last': last,
    };
  }
}

/// Picture model with thumbnail URL
class Picture {
  final String thumbnail;

  Picture({
    required this.thumbnail,
  });

  factory Picture.fromJson(Map<String, dynamic> json) {
    return Picture(
      thumbnail: json['thumbnail'] ?? json['medium'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thumbnail': thumbnail,
    };
  }
}

