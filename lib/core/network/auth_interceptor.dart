import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../di/service_locator.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // 1. Auth header (existing)
      final token = await _storage.read(key: 'auth_token');

      print(
        'DEBUG [AuthInterceptor]: Token from storage: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}',
      );

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        print(
          'DEBUG [AuthInterceptor]: Set Authorization header for ${options.uri}',
        );
      } else {
        print(
          'DEBUG [AuthInterceptor]: NO TOKEN - Authorization header will be missing',
        );
      }

      // 2. Company ID header (from stored company.id)
      final companyId = await _storage.read(key: 'company_id');
      if (companyId != null) {
        options.headers['X-Company-Id'] = companyId;
        print('DEBUG [AuthInterceptor]: Set X-Company-Id header: $companyId');
      } else {
        print('DEBUG [AuthInterceptor]: No company_id in storage - skipping X-Company-Id');
      }

      // 3. Tenant ID header (from tenant service)
      final tenantId = ServiceLocator.instance.tenantService.tenantIdOrNull;
      if (tenantId != null) {
        options.headers['X-Tenant-Id'] = tenantId.toString();
        print('DEBUG [AuthInterceptor]: Set X-Tenant-Id header: $tenantId');
      } else {
        print('DEBUG [AuthInterceptor]: No tenantId yet - skipping X-Tenant-Id');
      }

      handler.next(options);
    } catch (e) {
      print('DEBUG [AuthInterceptor]: error: $e');
      // Never block the request - let it proceed even if we have errors
      handler.next(options);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Clear token on 401 Unauthorized
      await _storage.delete(key: 'auth_token');
    }
    super.onError(err, handler);
  }
}
