import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String baseUrl;

  ProfileRepositoryImpl(this._client, this._storage, {required this.baseUrl});

  Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }


    final response = await _client.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
    );


    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Handle both flat and nested response structures for backward compatibility
      Map<String, dynamic> profileData;

      if (data.containsKey('employee') && data.containsKey('company')) {
        // Nested structure (old format) - flatten it
        final employee = data['employee'] as Map<String, dynamic>;
        final company = data['company'] as Map<String, dynamic>;

        profileData = {
          'name': employee['name'],
          'email': employee['email'],
          'phone': employee['phone'],
          'address': employee['address'],
          'position': employee['position'],
          'userName': employee['email']?.split('@')[0],
          'businessName': company['businessName'],
          'companyName': company['businessName'],
          'profileImage': company['logoUrl'],
          'imageUrl': company['logoUrl'],
        };
      } else {
        // Flat structure (new format) - use as is
        profileData = data;
      }

      // Prepend baseUrl to profileImage if it is a relative path
      if (profileData['profileImage'] != null &&
          profileData['profileImage'].toString().startsWith('/')) {
        profileData['profileImage'] = '$baseUrl${profileData['profileImage']}';
      }

      return profileData;
    } else {
      throw Exception('Failed to load profile: ${response.body}');
    }
  }

  @override
  Future<void> updateProfile(
    Map<String, dynamic> data, {
    File? imageFile,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // 1. Text Update (if data provided)
    if (data.isNotEmpty) {

      final response = await _client.put(
        Uri.parse('$baseUrl/api/profile'),
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: json.encode(data),
      );


      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to update profile data: ${response.body}');
      }
    }

    // 2. Image Upload (if image provided)
    if (imageFile != null) {

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/profile/upload-image'),
      );

      request.headers.addAll({'x-auth-token': token});

      // Determine content type based on extension
      final extension = imageFile.path.split('.').last.toLowerCase();
      var mediaType = MediaType('image', 'jpeg'); // Default

      if (extension == 'png') {
        mediaType = MediaType('image', 'png');
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mediaType = MediaType('image', 'jpeg');
      } else if (extension == 'webp') {
        mediaType = MediaType('image', 'webp');
      }

      // Add image file with correct field name 'image' and explicit content type
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);


      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to upload profile image: ${response.body}');
      }
    }
  }
}
