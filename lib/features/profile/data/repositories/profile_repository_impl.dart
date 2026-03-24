import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
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

    final cachedLogoUrl = await _storage.read(key: 'cached_logo_url');
    final cachedAvatarUrl = await _storage.read(key: 'cached_avatar_url');

    final response = await _client.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      Map<String, dynamic> profileData;

      if (data.containsKey('employee') && data.containsKey('company')) {
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
        };

        // 1. User/Employee Data
        profileData['userImage'] = cachedAvatarUrl ?? (employee['avatarUrl'] != null
            ? (employee['avatarUrl'].toString().startsWith('/') ? '$baseUrl${employee['avatarUrl']}' : employee['avatarUrl'])
            : null);

        // 2. Company Data (fallback for backward compatibility in some views)
        profileData['logoUrl'] = cachedLogoUrl ?? (company['logoUrl'] != null
            ? (company['logoUrl'].toString().startsWith('/') ? '$baseUrl${company['logoUrl']}' : company['logoUrl'])
            : null);

        // Keep profileImage and imageUrl as logoUrl for company profile views
        profileData['profileImage'] = profileData['logoUrl'];
        profileData['imageUrl'] = profileData['logoUrl'];

      } else {
        profileData = data;
        // Apply caching and base URL logic for generic profile data if employee/company structure is not present
        // This block ensures backward compatibility for older profile structures
        if (cachedLogoUrl != null && cachedLogoUrl.isNotEmpty) {
          profileData['logoUrl'] = cachedLogoUrl;
          profileData['imageUrl'] = cachedLogoUrl;
          profileData['profileImage'] = cachedLogoUrl;
        } else {
          if (profileData['profileImage'] != null &&
              profileData['profileImage'].toString().startsWith('/')) {
            profileData['profileImage'] =
                '$baseUrl${profileData['profileImage']}';
          }
          if (profileData['imageUrl'] != null &&
              profileData['imageUrl'].toString().startsWith('/')) {
            profileData['imageUrl'] = '$baseUrl${profileData['imageUrl']}';
          }
          if (profileData['logoUrl'] != null &&
              profileData['logoUrl'].toString().startsWith('/')) {
            profileData['logoUrl'] = '$baseUrl${profileData['logoUrl']}';
          }
        }
        // For generic profile, if avatar is present, handle it
        if (cachedAvatarUrl != null && cachedAvatarUrl.isNotEmpty) {
          profileData['userImage'] = cachedAvatarUrl;
        } else if (profileData['avatarUrl'] != null &&
            profileData['avatarUrl'].toString().startsWith('/')) {
          profileData['userImage'] = '$baseUrl${profileData['avatarUrl']}';
        } else if (profileData['avatarUrl'] != null) {
          profileData['userImage'] = profileData['avatarUrl'];
        }
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
    Uint8List? imageBytes,
    String? uploadType,
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
    if (imageFile != null || imageBytes != null) {
      final isLogo = uploadType == 'logo';
      final isAvatar = uploadType == 'avatar';
      
      // Determine endpoint based on uploadType
      String endpoint = '/api/profile/upload-image'; // Default legacy
      if (isLogo) endpoint = '/api/profile/upload-logo';
      if (isAvatar) endpoint = '/api/profile/upload-avatar';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );

      request.headers.addAll({'x-auth-token': token});

      // Determine content type based on file extension
      String? fileName = 'image';
      String extension = 'jpg'; // Default
      MediaType mediaType = MediaType('image', 'jpeg');

      if (imageFile != null) {
        final path = imageFile.path;
        fileName = path.split('/').last;
        extension = path.split('.').last.toLowerCase();
      } else if (imageBytes != null) {
        // For web, we'll use a generic name
        fileName = 'image_upload.jpg';
        extension = 'jpg';
      }

      if (extension == 'png') {
        mediaType = MediaType('image', 'png');
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mediaType = MediaType('image', 'jpeg');
      } else if (extension == 'webp') {
        mediaType = MediaType('image', 'webp');
      }

      // Add image file with correct field name 'image' and explicit content type
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            filename: fileName,
            contentType: mediaType,
          ),
        );
      } else if (imageBytes != null) {
        // For web with bytes data
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: fileName,
            contentType: mediaType,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to upload profile image: ${response.body}');
      }

      final responseData = json.decode(response.body);
      String? imageUrl = responseData['imageUrl'] ?? responseData['logoUrl'];

      if (imageUrl != null) {
        final absoluteUrl = imageUrl.toString().startsWith('/')
            ? '$baseUrl$imageUrl'
            : imageUrl;
        
        // Cache based on what we uploaded
        if (uploadType == 'logo') {
          await _storage.write(key: 'cached_logo_url', value: absoluteUrl);
        } else if (uploadType == 'avatar') {
          await _storage.write(key: 'cached_avatar_url', value: absoluteUrl);
        } else {
             // Fallback for legacy
          await _storage.write(key: 'cached_logo_url', value: absoluteUrl);
        }
      }
    }
  }
}
