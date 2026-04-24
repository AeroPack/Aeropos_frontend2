import 'dart:async';
import 'dart:convert';
// import 'dart:math';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/unit_repository.dart';
import '../repositories/brand_repository.dart';
import '../../config/app_config.dart';

final _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class SyncValidationError implements Exception {
  final String message;
  SyncValidationError(this.message);

  @override
  String toString() => 'SyncValidationError: $message';
}

class PendingChangesDetail {
  final int categories;
  final int units;
  final int brands;
  final int products;
  final int customers;
  final int suppliers;
  final int employees;
  final int invoices;

  PendingChangesDetail({
    required this.categories,
    required this.units,
    required this.brands,
    required this.products,
    required this.customers,
    required this.suppliers,
    required this.employees,
    required this.invoices,
  });

  int get total =>
      categories +
      units +
      brands +
      products +
      customers +
      suppliers +
      employees +
      invoices;

  bool get hasPending => total > 0;
}

bool isValidUUID(String? value) {
  if (value == null || value.isEmpty) return false;
  return _uuidRegex.hasMatch(value);
}

Future<void> validateProductForSync(AppDatabase db, ProductEntity prod) async {
  if (prod.unitId != null) {
    final unit = await (db.select(
      db.units,
    )..where((t) => t.id.equals(prod.unitId!))).getSingleOrNull();
    if (unit == null) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid unit reference (unit not found)',
      );
    }
    if (!isValidUUID(unit.uuid)) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid unit UUID for unit ID ${prod.unitId}',
      );
    }
  }
  if (prod.categoryId != null) {
    final cat = await (db.select(
      db.categories,
    )..where((t) => t.id.equals(prod.categoryId!))).getSingleOrNull();
    if (cat == null) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid category reference (category not found)',
      );
    }
    if (!isValidUUID(cat.uuid)) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid category UUID for category ID ${prod.categoryId}',
      );
    }
  }
  if (prod.brandId != null) {
    final brand = await (db.select(
      db.brands,
    )..where((t) => t.id.equals(prod.brandId!))).getSingleOrNull();
    if (brand == null) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid brand reference (brand not found)',
      );
    }
    if (!isValidUUID(brand.uuid)) {
      throw SyncValidationError(
        'Product ${prod.id} has invalid brand UUID for brand ID ${prod.brandId}',
      );
    }
  }
}

class SyncResult {
  final bool success;
  final Map<String, int> syncedCounts;
  final Map<String, int> failedCounts;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.syncedCounts,
    required this.failedCounts,
    required this.errors,
  });

  bool get hasFailures => failedCounts.values.any((count) => count > 0);
  int get totalSynced =>
      syncedCounts.values.fold(0, (sum, count) => sum + count);
  int get totalFailed =>
      failedCounts.values.fold(0, (sum, count) => sum + count);
}

@Deprecated(
  'Use SyncEngine from sync_engine.dart instead. Will be removed after v2.0. Migration required.',
)
class SyncService {
  final AppDatabase db;
  final Dio dio;
  final ProductRepository productRepo;
  final CustomerRepository customerRepo;
  final SupplierRepository supplierRepo;
  final EmployeeRepository employeeRepo;
  final SaleRepository saleRepo;
  final CategoryRepository categoryRepo;
  final UnitRepository unitRepo;
  final BrandRepository brandRepo;

  int get _tenantId => ServiceLocator.instance.tenantService.tenantId;

  Timer? _syncTimer;
  Timer? _syncDebounceTimer;
  bool _isSyncing = false;
  bool _isPulling = false;

  SyncService({
    required this.db,
    required this.dio,
    required this.productRepo,
    required this.customerRepo,
    required this.supplierRepo,
    required this.employeeRepo,
    required this.saleRepo,
    required this.categoryRepo,
    required this.unitRepo,
    required this.brandRepo,
  }) {
    dio.options.baseUrl = AppConfig.apiBaseUrl;
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
    print(
      '[DEPRECATED] SyncService is deprecated. Use SyncEngine instead. Migration required.',
    );
    _initializeDeviceId();
    // Reset flags in case a previous run crashed and left them true
    _isSyncing = false;
    _isPulling = false;
  }

  Future<void> _initializeDeviceId() async {
    final storage = ServiceLocator.instance.secureStorage;
    String? deviceId = await storage.read(key: 'device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await storage.write(key: 'device_id', value: deviceId);
      print('[SYNC] Generated new device ID: $deviceId');
    }
  }

  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      sync();
    });
    // Delay the first sync to let AuthController finish login
    Future.delayed(const Duration(seconds: 5), () {
      sync();
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncDebounceTimer?.cancel();
  }

  /// Debounced sync — coalesces rapid-fire calls into one execution
  Future<void> sync() async {
    // Only debounce if not already syncing
    if (_isSyncing) return;

    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(seconds: 2), () {
      _doSync();
    });
  }

  Future<void> _doSync() async {
    if (_isSyncing) {
      print('DEBUG SYNC: Already syncing - skipping');
      return;
    }
    _isSyncing = true;

    try {
      final storage = ServiceLocator.instance.secureStorage;
      final token = await storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        print('DEBUG SYNC: No auth token - skipping');
        return;
      }

      final tenantId = ServiceLocator.instance.tenantService.tenantIdOrNull;
      if (tenantId == null || tenantId <= 0) {
        print('DEBUG SYNC: Invalid tenantId=$tenantId - skipping');
        return;
      }

      // await push(); // Uncomment when push is ready
      await pull();
    } on Object catch (_) {
    } finally {
      _isSyncing = false;
    }
  }

  /// Check if there are any pending changes that need to be synced
  Future<bool> hasPendingChanges() async {
    try {
      // Check all tables for records with syncStatus = 1
      final pendingCategories =
          await (db.select(db.categories)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingCategories.isNotEmpty) return true;

      final pendingUnits =
          await (db.select(db.units)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingUnits.isNotEmpty) return true;

      final pendingBrands =
          await (db.select(db.brands)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingBrands.isNotEmpty) return true;

      final pendingProducts =
          await (db.select(db.products)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingProducts.isNotEmpty) return true;

      final pendingCustomers =
          await (db.select(db.customers)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingCustomers.isNotEmpty) return true;

      final pendingSuppliers =
          await (db.select(db.suppliers)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingSuppliers.isNotEmpty) return true;

      final pendingEmployees =
          await (db.select(db.employees)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingEmployees.isNotEmpty) return true;

      final pendingInvoices =
          await (db.select(db.invoices)
                ..where((t) => t.syncStatus.equals(1))
                ..limit(1))
              .get();
      if (pendingInvoices.isNotEmpty) return true;

      return false;
    } catch (e) {
      return false; // Assume no pending changes on error
    }
  }

  /// Get detailed count of pending changes by entity type
  Future<PendingChangesDetail> getPendingChangesDetails() async {
    try {
      final pendingCategories = await (db.select(
        db.categories,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingUnits = await (db.select(
        db.units,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingBrands = await (db.select(
        db.brands,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingProducts = await (db.select(
        db.products,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingCustomers = await (db.select(
        db.customers,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingSuppliers = await (db.select(
        db.suppliers,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingEmployees = await (db.select(
        db.employees,
      )..where((t) => t.syncStatus.equals(1))).get();
      final pendingInvoices = await (db.select(
        db.invoices,
      )..where((t) => t.syncStatus.equals(1))).get();

      return PendingChangesDetail(
        categories: pendingCategories.length,
        units: pendingUnits.length,
        brands: pendingBrands.length,
        products: pendingProducts.length,
        customers: pendingCustomers.length,
        suppliers: pendingSuppliers.length,
        employees: pendingEmployees.length,
        invoices: pendingInvoices.length,
      );
    } catch (e) {
      return PendingChangesDetail(
        categories: 0,
        units: 0,
        brands: 0,
        products: 0,
        customers: 0,
        suppliers: 0,
        employees: 0,
        invoices: 0,
      );
    }
  }

  /// Clean all local data and perform a full sync from the API
  Future<bool> cleanAndSync() async {
    if (_isSyncing) {
      return false;
    }

    _isSyncing = true;

    try {
      // Step 1: Clear all local data
      await db.clearAllData();

      // Step 2: Pull all data from API (lastSyncTime will be null, forcing full sync)
      await pull();

      return true;
    } catch (e) {
      if (e is DioException) {}
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // ----------------------------------------------------------------------
  // PULL (updated with correct payload and header handling)
  // ----------------------------------------------------------------------
  Future<void> pull() async {
    if (_isPulling) {
      print('[SYNC] pull() already in progress, skipping');
      return;
    }

    _isPulling = true;
    print('[SYNC] pull() STARTING with tenantId=$_tenantId');

    try {
      await _doPull();
    } catch (e) {
      print('[SYNC] pull() ERROR: $e');
      rethrow;
    } finally {
      _isPulling = false;
      print('[SYNC] pull() finished, flag reset');
    }
  }

  // Separate inner method for pull logic
  Future<void> _doPull() async {
    print('[DIAG] 1: enter _doPull');

    final currentTenantId =
        ServiceLocator.instance.tenantService.tenantIdOrNull;
    if (currentTenantId == null || currentTenantId <= 0) {
      print('[SYNC] Invalid tenantId=$currentTenantId - skipping pull');
      return;
    }

    final storage = ServiceLocator.instance.secureStorage;
    final token = await storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      print('[SYNC] No auth token - skipping pull');
      return;
    }

    // Ensure company_id is stored (needed for X-Company-Id header)
    String? companyId = await storage.read(key: 'company_id');
    if (companyId == null || companyId.isEmpty) {
      print('[SYNC] Warning: company_id not found in storage.');
    }

    print('[DIAG] 2: before deviceId');
    // Get or generate device ID
    String? deviceId = await storage.read(key: 'device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await storage.write(key: 'device_id', value: deviceId);
      print('[SYNC] Generated new device ID: $deviceId');
    }
    print('[DIAG] 3: after deviceId: $deviceId');

    print('[DIAG] 4: before lastSyncTime');
    final lastSyncTime = await _getLastSyncTime();
    final lastCursor = await _getLastSyncCursor();
    print('[DIAG] 5: after lastSyncTime: $lastSyncTime');

    print('[DIAG] 6: before payload');
    // NEW payload format matching backend contract
    final syncPayload = {
      'deviceId': deviceId,
      'lastPulledAt':
          lastSyncTime?.toUtc().toIso8601String() ?? '2026-01-01T00:00:00.000Z',
      'operations': <Map<String, dynamic>>[],
    };
    print('[SYNC][PULL] Payload: ${jsonEncode(syncPayload)}');
    print(
      '[SYNC][PULL] Requesting since: ${lastSyncTime?.toIso8601String() ?? "null"}',
    );
    print('[SYNC][PULL] Tenant: $_tenantId');

    print('[DIAG] 7: about to call dio.post');
    final response = await dio
        .post(
          'api/sync',
          data: syncPayload,
          options: Options(
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        )
        .timeout(
          const Duration(seconds: 35),
          onTimeout: () => throw TimeoutException('Sync request timed out'),
        );

    print('[SYNC][PULL] Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseData = response.data as Map<String, dynamic>;

      // NEW operation-based response format
      final operations = responseData['operations'] as List<dynamic>?;

      if (operations != null && operations.isNotEmpty) {
        print('[SYNC][PULL] Received ${operations.length} operations');

        // Process operations one by one with explicit logging
        for (var op in operations) {
          print('[SYNC] Processing: ${op['type']} on ${op['table']}');
          await _processOperation(op);
        }
      } else {
        print('[SYNC][PULL] No operations to process');
      }

      // Store nextCursor for future incremental syncs
      final nextCursor = responseData['nextCursor'] as String?;
      if (nextCursor != null) {
        await _updateLastSyncCursor(nextCursor);
      }

      await _updateLastSyncTime(DateTime.now());
      print('[SYNC][PULL] ✓ Completed');
    }
  }

  // Process individual operation (new operation-based format)
  Future<void> _processOperation(Map<String, dynamic> op) async {
    final table = op['table'] as String?;
    final type = op['type'] as String?;
    final data = op['data'] as Map<String, dynamic>?;
    final recordId = op['recordId'] as String?;

    if (table == null || type == null) {
      print('[SYNC][PULL] Skipping op - missing table or type');
      return;
    }

    print('[SYNC][PULL] $type on $table (recordId: $recordId)');

    switch (table) {
      case 'units':
        await _upsertUnit(data);
        break;
      case 'categories':
        await _upsertCategory(data);
        break;
      case 'brands':
        await _upsertBrand(data);
        break;
      case 'products':
        await _upsertProduct(data);
        break;
      case 'customers':
        await _upsertCustomer(data);
        break;
      case 'suppliers':
        await _upsertSupplier(data);
        break;
      case 'employees':
        await _upsertEmployee(data);
        break;
      case 'invoices':
        await _upsertInvoice(data);
        break;
      default:
        print('[SYNC][PULL] Unknown table: $table');
    }
  }

  // Individual upsert handlers
  Future<void> _upsertUnit(Map<String, dynamic>? data) async {
    if (data == null) return;
    await db
        .into(db.units)
        .insertOnConflictUpdate(
          UnitsCompanion(
            uuid: Value(data['uuid'] as String? ?? ''),
            name: Value(data['name'] as String? ?? ''),
            symbol: Value(data['symbol'] as String? ?? ''),
            isActive: Value(data['is_active'] as bool? ?? true),
            tenantId: Value(data['company_id'] as int? ?? _tenantId),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
            isDeleted: Value(data['is_deleted'] as bool? ?? false),
          ),
        );
  }

  Future<void> _upsertCategory(Map<String, dynamic>? data) async {
    if (data == null) return;
    await db
        .into(db.categories)
        .insertOnConflictUpdate(
          CategoriesCompanion(
            uuid: Value(data['uuid'] as String? ?? ''),
            name: Value(data['name'] as String? ?? ''),
            subcategory: Value(data['subcategory'] as String?),
            description: Value(data['description'] as String?),
            isActive: Value(data['is_active'] as bool? ?? true),
            tenantId: Value(data['company_id'] as int? ?? _tenantId),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
            isDeleted: Value(data['is_deleted'] as bool? ?? false),
          ),
        );
  }

  Future<void> _upsertBrand(Map<String, dynamic>? data) async {
    if (data == null) return;
    await db
        .into(db.brands)
        .insertOnConflictUpdate(
          BrandsCompanion(
            uuid: Value(data['uuid'] as String? ?? ''),
            name: Value(data['name'] as String? ?? ''),
            description: Value(data['description'] as String?),
            isActive: Value(data['is_active'] as bool? ?? true),
            tenantId: Value(data['company_id'] as int? ?? _tenantId),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
            isDeleted: Value(data['is_deleted'] as bool? ?? false),
          ),
        );
  }

  Future<void> _upsertProduct(Map<String, dynamic>? data) async {
    if (data == null) return;
    await db
        .into(db.products)
        .insertOnConflictUpdate(
          ProductsCompanion(
            uuid: Value(data['uuid'] as String? ?? ''),
            name: Value(data['name'] as String? ?? ''),
            sku: Value(data['sku'] as String?),
            price: Value((data['price'] as num?)?.toDouble() ?? 0.0),
            cost: Value((data['cost'] as num?)?.toDouble()),
            stockQuantity: Value(data['stock_quantity'] as int? ?? 0),
            isActive: Value(data['is_active'] as bool? ?? true),
            tenantId: Value(data['company_id'] as int? ?? _tenantId),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
            isDeleted: Value(data['is_deleted'] as bool? ?? false),
          ),
        );
  }

  Future<void> _upsertCustomer(Map<String, dynamic>? data) async {
    if (data == null) return;
    await db
        .into(db.customers)
        .insertOnConflictUpdate(
          CustomersCompanion(
            uuid: Value(data['uuid'] as String? ?? ''),
            name: Value(data['name'] as String? ?? ''),
            phone: Value(data['phone'] as String?),
            email: Value(data['email'] as String?),
            address: Value(data['address'] as String?),
            creditLimit: Value(
              (data['credit_limit'] as num?)?.toDouble() ?? 0.0,
            ),
            currentBalance: Value(
              (data['current_balance'] as num?)?.toDouble() ?? 0.0,
            ),
            tenantId: Value(data['company_id'] as int? ?? _tenantId),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
            isDeleted: Value(data['is_deleted'] as bool? ?? false),
          ),
        );
  }

  Future<void> _upsertSupplier(Map<String, dynamic>? data) async {
    if (data == null) return;
    await db
        .into(db.suppliers)
        .insertOnConflictUpdate(
          SuppliersCompanion(
            uuid: Value(data['uuid'] as String? ?? ''),
            name: Value(data['name'] as String? ?? ''),
            phone: Value(data['phone'] as String?),
            email: Value(data['email'] as String?),
            address: Value(data['address'] as String?),
            tenantId: Value(data['company_id'] as int? ?? _tenantId),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
            isDeleted: Value(data['is_deleted'] as bool? ?? false),
          ),
        );
  }

  Future<void> _upsertEmployee(Map<String, dynamic>? data) async {
    if (data == null) return;
    await db
        .into(db.employees)
        .insertOnConflictUpdate(
          EmployeesCompanion(
            uuid: Value(data['uuid'] as String? ?? ''),
            name: Value(data['name'] as String? ?? ''),
            phone: Value(data['phone'] as String?),
            email: Value(data['email'] as String?),
            address: Value(data['address'] as String?),
            role: Value(data['role'] as String? ?? 'employee'),
            password: Value(data['password'] as String?),
            tenantId: Value(data['company_id'] as int? ?? _tenantId),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
            isDeleted: Value(data['is_deleted'] as bool? ?? false),
          ),
        );
  }

  Future<void> _upsertInvoice(Map<String, dynamic>? data) async {
    if (data == null) return;
    await db
        .into(db.invoices)
        .insertOnConflictUpdate(
          InvoicesCompanion(
            uuid: Value(data['uuid'] as String? ?? ''),
            invoiceNumber: Value(data['invoice_number'] as String? ?? ''),
            customerId: Value(data['customer_id'] as int?),
            date: Value(
              data['created_at'] != null
                  ? DateTime.parse(data['created_at'])
                  : DateTime.now(),
            ),
            subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0.0),
            tax: Value((data['tax'] as num?)?.toDouble() ?? 0.0),
            discount: Value((data['discount'] as num?)?.toDouble() ?? 0.0),
            total: Value((data['total'] as num?)?.toDouble() ?? 0.0),
            paymentMethod: Value(data['payment_method'] as String?),
            tenantId: Value(data['company_id'] as int? ?? _tenantId),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
            isDeleted: Value(data['is_deleted'] as bool? ?? false),
          ),
        );
  }

  Future<void> _updateLastSyncCursor(String cursor) async {
    try {
      await db
          .into(db.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              key: const Value('lastSyncCursor'),
              value: Value(cursor),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } catch (_) {}
  }

  Future<String?> _getLastSyncCursor() async {
    try {
      final record = await (db.select(
        db.syncMetadata,
      )..where((t) => t.key.equals('lastSyncCursor'))).getSingleOrNull();
      return record?.value;
    } catch (e) {
      return null;
    }
  }

  /// Force a full sync, ignoring lastSyncTime
  /// Useful for initial loads or when you need to fetch all historical data
  Future<void> forcePull() async {
    try {
      final storage = ServiceLocator.instance.secureStorage;
      String? deviceId = await storage.read(key: 'device_id');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await storage.write(key: 'device_id', value: deviceId);
        print('[SYNC] Generated new device ID: $deviceId');
      }

      print('[SYNC][FORCE PULL] Starting full sync with deviceId: $deviceId');

      final response = await dio
          .post(
            'api/sync',
            data: {
              'deviceId': deviceId,
              'lastPulledAt': null, // null triggers full sync from server
              'operations': <Map<String, dynamic>>[],
            },
            options: Options(
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          )
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () => throw TimeoutException('Force pull timed out'),
          );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        final updates = responseData['updates'] as Map<String, dynamic>?;
        if (updates != null) {
          print('[SYNC][FORCE PULL] Applying updates...');
          await _applyUpdates(updates);
          print('[SYNC][FORCE PULL] ✓ Full sync completed');
        }
        await _updateLastSyncTime(DateTime.now());
      } else {
        print(
          '[SYNC][FORCE PULL] Unexpected status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[SYNC][FORCE PULL] ERROR - $e');
      rethrow;
    }
  }

  // ----------------------------------------------------------------------
  // PUSH (existing implementation)
  // ----------------------------------------------------------------------
  Future<SyncResult> push() async {
    print('DEBUG SYNC: push() STARTING with tenantId=$_tenantId');
    final syncedCounts = <String, int>{
      'categories': 0,
      'units': 0,
      'brands': 0,
      'products': 0,
      'customers': 0,
      'suppliers': 0,
      'employees': 0,
      'invoices': 0,
    };
    final failedCounts = <String, int>{
      'categories': 0,
      'units': 0,
      'brands': 0,
      'products': 0,
      'customers': 0,
      'suppliers': 0,
      'employees': 0,
      'invoices': 0,
    };
    final errors = <String>[];

    try {
      // Categories
      final pendingCategories = await (db.select(
        db.categories,
      )..where((t) => t.syncStatus.equals(1))).get();
      print('[SYNC][PUSH][categories] → ${pendingCategories.length} ops');

      for (final cat in pendingCategories) {
        final success = await _pushEntity(
          'api/categories',
          {
            'uuid': cat.uuid,
            'name': cat.name,
            'subcategory': cat.subcategory,
            'description': cat.description,
            'isActive': cat.isActive,
            'companyId': _tenantId,
          },
          () async {
            await (db.update(db.categories)..where((t) => t.id.equals(cat.id)))
                .write(const CategoriesCompanion(syncStatus: Value(0)));
          },
          'Category: ${cat.name}',
          onPermanentFailure: () async {
            await (db.update(db.categories)..where((t) => t.id.equals(cat.id)))
                .write(const CategoriesCompanion(syncStatus: Value(2)));
          },
        );
        if (success) {
          syncedCounts['categories'] = syncedCounts['categories']! + 1;
        } else {
          failedCounts['categories'] = failedCounts['categories']! + 1;
        }
      }

      // Units
      final pendingUnits = await (db.select(
        db.units,
      )..where((t) => t.syncStatus.equals(1))).get();
      print('[SYNC][PUSH][units] → ${pendingUnits.length} ops');

      for (final unit in pendingUnits) {
        final success = await _pushEntity(
          'api/units',
          {
            'uuid': unit.uuid,
            'name': unit.name,
            'symbol': unit.symbol,
            'isActive': unit.isActive,
            'companyId': _tenantId,
          },
          () async {
            await (db.update(db.units)..where((t) => t.id.equals(unit.id)))
                .write(const UnitsCompanion(syncStatus: Value(0)));
          },
          'Unit: ${unit.name}',
          onPermanentFailure: () async {
            await (db.update(db.units)..where((t) => t.id.equals(unit.id)))
                .write(const UnitsCompanion(syncStatus: Value(2)));
          },
        );
        if (success) {
          syncedCounts['units'] = syncedCounts['units']! + 1;
        } else {
          failedCounts['units'] = failedCounts['units']! + 1;
        }
      }

      // Brands
      final pendingBrands = await (db.select(
        db.brands,
      )..where((t) => t.syncStatus.equals(1))).get();
      print('[SYNC][PUSH][brands] → ${pendingBrands.length} ops');

      for (final brand in pendingBrands) {
        final success = await _pushEntity(
          'api/brands',
          {
            'uuid': brand.uuid,
            'name': brand.name,
            'description': brand.description,
            'isActive': brand.isActive,
            'companyId': _tenantId,
          },
          () async {
            await (db.update(db.brands)..where((t) => t.id.equals(brand.id)))
                .write(const BrandsCompanion(syncStatus: Value(0)));
          },
          'Brand: ${brand.name}',
          onPermanentFailure: () async {
            await (db.update(db.brands)..where((t) => t.id.equals(brand.id)))
                .write(const BrandsCompanion(syncStatus: Value(2)));
          },
        );
        if (success) {
          syncedCounts['brands'] = syncedCounts['brands']! + 1;
        } else {
          failedCounts['brands'] = failedCounts['brands']! + 1;
        }
      }

      // Products (Batch sync)
      final pendingProducts = await (db.select(
        db.products,
      )..where((t) => t.syncStatus.equals(1))).get();
      print('[SYNC][PUSH][products] → ${pendingProducts.length} ops');

      const int productBatchSize = 25;
      for (var i = 0; i < pendingProducts.length; i += productBatchSize) {
        final end = (i + productBatchSize < pendingProducts.length)
            ? i + productBatchSize
            : pendingProducts.length;
        final chunk = pendingProducts.sublist(i, end);
        final List<Map<String, dynamic>> batchData = [];

        for (final prod in chunk) {
          // Validate references before creating payload
          try {
            await validateProductForSync(db, prod);
          } catch (e) {
            print('[SYNC][PUSH][products] VALIDATION FAILED → ${prod.id}');
            // Mark as failed instead of sending
            await (db.update(db.products)..where((t) => t.id.equals(prod.id)))
                .write(const ProductsCompanion(syncStatus: Value(2)));
            failedCounts['products'] = failedCounts['products']! + 1;
            errors.add('Product ${prod.id}: $e');
            continue;
          }

          final unit = prod.unitId != null
              ? await (db.select(
                  db.units,
                )..where((t) => t.id.equals(prod.unitId!))).getSingleOrNull()
              : null;
          final category = prod.categoryId != null
              ? await (db.select(db.categories)
                      ..where((t) => t.id.equals(prod.categoryId!)))
                    .getSingleOrNull()
              : null;
          final brand = prod.brandId != null
              ? await (db.select(
                  db.brands,
                )..where((t) => t.id.equals(prod.brandId!))).getSingleOrNull()
              : null;

          // CRITICAL: Only send UUIDs, no integer IDs
          batchData.add({
            'uuid': prod.uuid,
            'name': prod.name,
            'sku': prod.sku,
            'price': prod.price,
            'cost': prod.cost,
            'stockQuantity': prod.stockQuantity,
            'categoryUuid': category?.uuid ?? '', // UUID only
            'unitUuid': unit?.uuid ?? '', // UUID only
            'brandUuid': brand?.uuid ?? '', // UUID only
            'gstType': prod.gstType,
            'gstRate': prod.gstRate,
            'imageUrl': prod.imageUrl,
            'isPercentDiscount': prod.isPercentDiscount,
            'isActive': prod.isActive,
            'companyId': _tenantId,
          });
        }

        final success = await _pushEntity(
          'api/products',
          batchData,
          () async {
            for (final prod in chunk) {
              await (db.update(db.products)..where((t) => t.id.equals(prod.id)))
                  .write(const ProductsCompanion(syncStatus: Value(0)));
            }
          },
          'Products Batch',
          onPermanentFailure: () async {
            for (final prod in chunk) {
              await (db.update(db.products)..where((t) => t.id.equals(prod.id)))
                  .write(const ProductsCompanion(syncStatus: Value(2)));
            }
          },
        );

        if (success) {
          syncedCounts['products'] = syncedCounts['products']! + chunk.length;
        } else {
          failedCounts['products'] = failedCounts['products']! + chunk.length;
        }
      }

      // Customers
      final pendingCustomers = await (db.select(
        db.customers,
      )..where((t) => t.syncStatus.equals(1))).get();
      print('[SYNC][PUSH][customers] → ${pendingCustomers.length} ops');

      for (final customer in pendingCustomers) {
        final success = await _pushEntity(
          'api/customers',
          {
            'uuid': customer.uuid,
            'name': customer.name,
            'phone': customer.phone,
            'email': customer.email,
            'address': customer.address,
            'creditLimit': customer.creditLimit,
            'currentBalance': customer.currentBalance,
            'companyId': _tenantId,
          },
          () async {
            await (db.update(db.customers)
                  ..where((t) => t.id.equals(customer.id)))
                .write(const CustomersCompanion(syncStatus: Value(0)));
          },
          'Customer: ${customer.name}',
          onPermanentFailure: () async {
            await (db.update(db.customers)
                  ..where((t) => t.id.equals(customer.id)))
                .write(const CustomersCompanion(syncStatus: Value(2)));
          },
        );
        if (success) {
          syncedCounts['customers'] = syncedCounts['customers']! + 1;
        } else {
          failedCounts['customers'] = failedCounts['customers']! + 1;
        }
      }

      // Suppliers
      final pendingSuppliers = await (db.select(
        db.suppliers,
      )..where((t) => t.syncStatus.equals(1))).get();
      print('[SYNC][PUSH][suppliers] → ${pendingSuppliers.length} ops');

      for (final supplier in pendingSuppliers) {
        final success = await _pushEntity(
          'api/suppliers',
          {
            'uuid': supplier.uuid,
            'name': supplier.name,
            'phone': supplier.phone,
            'email': supplier.email,
            'address': supplier.address,
            'companyId': _tenantId,
          },
          () async {
            await (db.update(db.suppliers)
                  ..where((t) => t.id.equals(supplier.id)))
                .write(const SuppliersCompanion(syncStatus: Value(0)));
          },
          'Supplier: ${supplier.name}',
          onPermanentFailure: () async {
            await (db.update(db.suppliers)
                  ..where((t) => t.id.equals(supplier.id)))
                .write(const SuppliersCompanion(syncStatus: Value(2)));
          },
        );
        if (success) {
          syncedCounts['suppliers'] = syncedCounts['suppliers']! + 1;
        } else {
          failedCounts['suppliers'] = failedCounts['suppliers']! + 1;
        }
      }

      // Employees
      final pendingEmployees = await (db.select(
        db.employees,
      )..where((t) => t.syncStatus.equals(1))).get();
      print('[SYNC][PUSH][employees] → ${pendingEmployees.length} ops');

      for (final employee in pendingEmployees) {
        final success = await _pushEntity(
          'api/employees',
          {
            'uuid': employee.uuid,
            'name': employee.name,
            'phone': employee.phone,
            'email': employee.email,
            'address': employee.address,
            'role': employee.role,
            'password': employee.password,
            'authMethod': employee.googleAuth ? 'google' : 'manual',
            'companyId': _tenantId,
          },
          () async {
            await (db.update(db.employees)
                  ..where((t) => t.id.equals(employee.id)))
                .write(const EmployeesCompanion(syncStatus: Value(0)));
          },
          'Employee: ${employee.name}',
          onPermanentFailure: () async {
            await (db.update(db.employees)
                  ..where((t) => t.id.equals(employee.id)))
                .write(const EmployeesCompanion(syncStatus: Value(2)));
          },
        );
        if (success) {
          syncedCounts['employees'] = syncedCounts['employees']! + 1;
        } else {
          failedCounts['employees'] = failedCounts['employees']! + 1;
        }
      }

      // Invoices (with invoice items - NOT synced independently)
      final pendingInvoices = await (db.select(
        db.invoices,
      )..where((t) => t.syncStatus.equals(1))).get();
      print('[SYNC][PUSH][invoices] → ${pendingInvoices.length} ops');

      for (final inv in pendingInvoices) {
        final itemsWithProducts = await (db.select(db.invoiceItems).join([
          innerJoin(
            db.products,
            db.products.id.equalsExp(db.invoiceItems.productId),
          ),
        ])..where(db.invoiceItems.invoiceId.equals(inv.id))).get();

        final customer = inv.customerId != null
            ? await (db.select(
                db.customers,
              )..where((t) => t.id.equals(inv.customerId!))).getSingleOrNull()
            : null;

        final success = await _pushEntity(
          'api/invoices',
          {
            'uuid': inv.uuid,
            'invoiceNumber': inv.invoiceNumber,
            'customerId': inv.customerId,
            'customerUuid': customer?.uuid,
            'date': inv.date.toIso8601String(),
            'subtotal': inv.subtotal,
            'tax': inv.tax,
            'discount': inv.discount,
            'total': inv.total,
            'paymentMethod': inv.paymentMethod,
            'companyId': _tenantId,
            'items': itemsWithProducts.map((row) {
              final e = row.readTable(db.invoiceItems);
              final p = row.readTable(db.products);
              return {
                'uuid': e.uuid,
                'productId': p.id,
                'productUuid': p.uuid,
                'quantity': e.quantity,
                'unitPrice': e.unitPrice,
                'totalPrice': e.totalPrice,
                'bonus': e.bonus,
                'discount': e.discount,
              };
            }).toList(),
          },
          () async {
            await (db.update(db.invoices)..where((t) => t.id.equals(inv.id)))
                .write(const InvoicesCompanion(syncStatus: Value(0)));
          },
          'Invoice: ${inv.invoiceNumber}',
          onPermanentFailure: () async {
            await (db.update(db.invoices)..where((t) => t.id.equals(inv.id)))
                .write(const InvoicesCompanion(syncStatus: Value(2)));
          },
        );
        if (success) {
          syncedCounts['invoices'] = syncedCounts['invoices']! + 1;
        } else {
          failedCounts['invoices'] = failedCounts['invoices']! + 1;
        }
      }
    } catch (e) {
      errors.add('Unexpected error during sync: $e');
    }

    final hasFailures = failedCounts.values.any((count) => count > 0);
    return SyncResult(
      success: !hasFailures && errors.isEmpty,
      syncedCounts: syncedCounts,
      failedCounts: failedCounts,
      errors: errors,
    );
  }

  Future<bool> _pushEntity(
    String endpoint,
    dynamic data,
    Future<void> Function() onSuccess,
    String entityDescription, {
    Future<void> Function()? onPermanentFailure,
  }) async {
    try {
      // X-Company-Id handled by AuthInterceptor - no manual header needed
      final response = await dio.post(endpoint, data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await onSuccess();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      if (e is DioException) {
        // Mark as permanently failed on 400 — these will never succeed without manual intervention
        if (e.response?.statusCode == 400) {
          await onPermanentFailure?.call();
        }
      }
      return false;
    }
  }

  /// Manually sync products from the server
  Future<bool> syncProducts() async {
    try {
      await pull();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _applyUpdates(Map<String, dynamic> updates) async {
    Future<void> upsert<T extends Table, D extends DataClass>(
      TableInfo<T, D> table,
      dynamic data,
      D Function(Map<String, dynamic>) fromJson,
    ) async {
      if (data != null && data is List) {
        for (var item in data) {
          try {
            final map = Map<String, dynamic>.from(item);

            // Add default values for fields that might be missing from API
            map['syncStatus'] = 0; // Mark as synced

            // Map companyId from backend to tenantId for local database
            if (map.containsKey('companyId') && map['companyId'] != null) {
              map['tenantId'] = map['companyId'];
            }

            // Add default updatedAt if missing (use createdAt or current time)
            if (!map.containsKey('updatedAt') || map['updatedAt'] == null) {
              map['updatedAt'] =
                  map['createdAt'] ?? DateTime.now().toIso8601String();
            }

            // Add default isDeleted if missing
            if (!map.containsKey('isDeleted') || map['isDeleted'] == null) {
              map['isDeleted'] = false;
            }

            final entity = fromJson(map);
            await db
                .into(table)
                .insertOnConflictUpdate(entity as Insertable<D>);
          } catch (e) {
            // If it's a UNIQUE constraint error (like SKU or UUID conflict), log it but continue
            if (e.toString().contains('UNIQUE constraint failed')) {
            } else {}
          }
        }
      }
    }

    await upsert(db.categories, updates['categories'], CategoryEntity.fromJson);
    await upsert(db.units, updates['units'], UnitEntity.fromJson);
    await upsert(db.brands, updates['brands'], BrandEntity.fromJson);
    await upsert(db.products, updates['products'], ProductEntity.fromJson);
    await upsert(db.customers, updates['customers'], CustomerEntity.fromJson);
    await upsert(db.suppliers, updates['suppliers'], SupplierEntity.fromJson);
    await upsert(db.employees, updates['employees'], EmployeeEntity.fromJson);
    await upsert(db.invoices, updates['invoices'], InvoiceEntity.fromJson);
    await upsert(
      db.invoiceItems,
      updates['invoiceItems'],
      InvoiceItemEntity.fromJson,
    );
  }

  Future<DateTime?> _getLastSyncTime() async {
    try {
      final record = await (db.select(
        db.syncMetadata,
      )..where((t) => t.key.equals('lastSyncTime'))).getSingleOrNull();
      if (record == null || record.value == null) return null;
      return DateTime.tryParse(record.value!);
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateLastSyncTime(DateTime time) async {
    try {
      await db
          .into(db.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              key: const Value('lastSyncTime'),
              value: Value(time.toIso8601String()),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } on Object catch (_) {}
  }
}
