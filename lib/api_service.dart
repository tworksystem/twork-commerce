import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ecommerce_int2/models/user.dart';

/// Mock API service for fetching user data
/// This service provides mock user data for development/testing purposes
class ApiService {
  /// Fetches a list of users from a mock API
  /// 
  /// [nrUsers] - Number of users to fetch (default: 5)
  /// Returns a list of User objects
  static Future<List<User>> getUsers({int nrUsers = 5}) async {
    try {
      // Using RandomUser API as a mock data source
      final response = await http.get(
        Uri.parse('https://randomuser.me/api/?results=$nrUsers'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        
        return results.map((json) {
          // Transform RandomUser API format to our User model
          return User(
            name: Name(
              first: json['name']['first'] ?? '',
              last: json['name']['last'] ?? '',
            ),
            picture: Picture(
              thumbnail: json['picture']['thumbnail'] ?? '',
            ),
            phone: json['phone'] ?? '',
          );
        }).toList();
      } else {
        // Return empty list on error
        return [];
      }
    } catch (e) {
      // Return empty list on exception
      print('Error fetching users: $e');
      return [];
    }
  }
}

