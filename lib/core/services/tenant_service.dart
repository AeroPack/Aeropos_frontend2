import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TenantService {
  final FlutterSecureStorage _storage;
  int _tenantId = 1;

  TenantService(this._storage);

  int get tenantId => _tenantId;

  Future<void> initialize() async {
    final storedIdStr = await _storage.read(key: 'tenant_id');
    if (storedIdStr != null) {
      _tenantId = int.tryParse(storedIdStr) ?? 1;
    }
  }

  Future<void> setTenantId(int id) async {
    _tenantId = id;
    await _storage.write(key: 'tenant_id', value: id.toString());
  }
}
