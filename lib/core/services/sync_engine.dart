import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../config/app_config.dart';
import '../di/service_locator.dart';

const int MAX_BATCH_SIZE = 500;
const int COMPRESSION_THRESHOLD = 10240;
const Duration SYNC_INTERVAL = Duration(seconds: 10);
const int MAX_RETRY_ATTEMPTS = 3;
const Duration BASE_RETRY_DELAY = Duration(seconds: 2);

void _log(String event, Map<String, dynamic> fields) {
  final fieldsStr = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
  print('SYNC_$event $fieldsStr');
}

class SyncOpType {
  static const int insert = 1;
  static const int update = 2;
  static const int delete = 3;
}

class SyncEngineResult {
  final bool success;
  final int pushed;
  final int acked;
  final int rejected;
  final int pulled;
  final List<String> errors;

  SyncEngineResult({
    required this.success,
    this.pushed = 0,
    this.acked = 0,
    this.rejected = 0,
    this.pulled = 0,
    this.errors = const [],
  });
}

class SyncEngine {
  final AppDatabase db;
  final Dio dio;
  final String tenantId;
  final String companyId;
  final String deviceId;

  Timer? _syncTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;

  SyncEngine({
    required this.db,
    required this.dio,
    required this.tenantId,
    required this.companyId,
    required this.deviceId,
  }) {
    dio.options.baseUrl = AppConfig.apiBaseUrl;
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  void startAutoSync({Duration interval = SYNC_INTERVAL}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => sync());
    Future.delayed(const Duration(seconds: 5), sync);
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () => _doSync());
  }

  Future<SyncEngineResult> _doSync() async {
    if (_isSyncing) {
      _log('SKIP', {'reason': 'already_syncing', 'device': deviceId});
      return SyncEngineResult(success: false, errors: ['Already syncing']);
    }

    try {
      final token = await ServiceLocator.instance.secureStorage.read(key: 'auth_token');
      print('[ENGINE][AUTH] token read result: ${token == null ? "NULL" : "present (${token.length} chars)"}');
      print('[ENGINE][AUTH] storage instance hashCode: ${ServiceLocator.instance.secureStorage.hashCode}');
      if (token == null || token.isEmpty) {
        _log('SKIP', {'reason': 'not_authenticated', 'device': deviceId});
        return SyncEngineResult(success: false, errors: ['Not authenticated']);
      }
    } catch (e) {
      print('[ENGINE][AUTH] ERROR reading token: $e');
      _log('SKIP', {'reason': 'not_authenticated', 'device': deviceId, 'error': e.toString()});
      return SyncEngineResult(success: false, errors: ['Not authenticated']);
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _log('SKIP', {'reason': 'offline', 'device': deviceId});
      return SyncEngineResult(success: false, errors: ['Offline']);
    }

    _isSyncing = true;
    _log('START', {'device': deviceId, 'tenant': tenantId});

    try {
      final sw = Stopwatch()..start();
      final result = await _sync();
      sw.stop();

      if (result.pushed > 0 || result.pulled > 0) {
        _log('SYNC', {
          'device': deviceId,
          'pushed': result.pushed,
          'pulled': result.pulled,
          'duration': '${sw.elapsedMilliseconds}ms',
        });
      }

      if (result.success) {
        _log('DONE', {'device': deviceId, 'status': 'ok'});
      } else {
        _log('ERROR', {'device': deviceId, 'errors': result.errors.length});
      }

      return result;
    } catch (e) {
      _log('ERROR', {'device': deviceId, 'error': e.toString()});
      return SyncEngineResult(success: false, errors: [e.toString()]);
    } finally {
      _isSyncing = false;
    }
  }

  Future<SyncEngineResult> push() => _doSync();

  Map<String, dynamic> _mapToApiFormat(Map<String, dynamic> op) {
    // Convert opType: 1=insert, 2=update, 3=delete
    String type;
    switch (op['opType'] as int) {
      case 1:
        type = 'INSERT';
        break;
      case 2:
        type = 'UPDATE';
        break;
      case 3:
        type = 'DELETE';
        break;
      default:
        type = 'INSERT';
    }

    // Table name must match backend exactly (lowercase with underscore)
    String table = op['entity'].toString().toLowerCase();
    if (table == 'invoiceitems') table = 'invoice_items';
    if (table == 'invoicesettings') table = 'invoice_settings';

    // Parse timestamp and convert to UTC ISO 8601
    String timestamp = op['createdAt']?.toString() ?? DateTime.now().toUtc().toIso8601String();
    if (timestamp.isNotEmpty && !timestamp.endsWith('Z')) {
      timestamp = DateTime.parse(timestamp).toUtc().toIso8601String();
    } else if (!timestamp.endsWith('Z') && !timestamp.contains('Z')) {
      timestamp = DateTime.now().toUtc().toIso8601String();
    }

    return {
      'type': type,
      'table': table,
      'recordId': op['entityId'],
      'data': op['data'],
      'timestamp': timestamp,
    };
  }

  Future<T> _withRetry<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxAttempts = MAX_RETRY_ATTEMPTS,
    Duration baseDelay = BASE_RETRY_DELAY,
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        _log('RETRY', {
          'op': operationName,
          'attempt': attempts,
          'max': maxAttempts,
          'error': e.toString(),
        });

        if (attempts >= maxAttempts) {
          _log('RETRY_FAILED', {
            'op': operationName,
            'attempts': attempts,
            'error': e.toString(),
          });
          rethrow;
        }

        final delay = baseDelay * (1 << (attempts - 1));
        await Future.delayed(delay);
      }
    }

    throw Exception('Retry logic exhausted for: $operationName');
  }

  Future<SyncEngineResult> _sync() async {
    _log('SYNC_START', {'device': deviceId, 'tenant': tenantId});

    // 1. Push all batches first
    int totalAcked = 0;
    int totalRejected = 0;
    final errors = <String>[];

    // DEBUG: Check outbox before push
    final outboxCheck = await _getPendingOutbox(100);
    print('[ENGINE][OUTBOX] ${outboxCheck.length} items in outbox before sync');
    for (final item in outboxCheck.take(5)) {
      print('[ENGINE][OUTBOX] ${item['entity']}:${item['entityId']} opType=${item['opType']}');
    }

    while (true) {
      final pending = await _getPendingOutbox(MAX_BATCH_SIZE);
      print('[ENGINE][PUSH] Reading from sync_outbox...');
      print('[ENGINE][PUSH] Found ${pending.length} pending operations');
      if (pending.isEmpty) break;

      final mappedOps = pending.map(_mapToApiFormat).toList();
      // Note: Empty check already covered by pending.isEmpty check above (line 234)

      final lastPulledAt = await _getLastSyncTime();

      final body = {
        'deviceId': deviceId,
        'operations': mappedOps,
      };  // NOTE: No lastPulledAt in push request - only deviceId and operations

      try {
        final pushResult = await _withRetry(
          operation: () => _pushBatch(body),
          operationName: 'push',
        );
        totalAcked += pushResult['acked'] as int;
        totalRejected += pushResult['rejected'] as int;
        print('[ENGINE][PUSH] Sent batch, server acknowledged ${pushResult['acked']} ops, rejected ${pushResult['rejected']}');
      } catch (e) {
        errors.add('Push failed: ${e.toString()}');
      }

      if (pending.length < MAX_BATCH_SIZE) break;
    }

    // 2. Single pull with consistent snapshot (with retry)
    final lastPulledAt = await _getLastSyncTime();
    Map<String, dynamic> pullResponse;

    try {
      pullResponse = await _withRetry(
        operation: () => _pullOnce(lastPulledAt),
        operationName: 'pull',
      );
    } catch (e) {
      _log('SYNC_FAIL', {'device': deviceId, 'error': e.toString()});
      return SyncEngineResult(
        success: false,
        errors: [...errors, 'Pull failed: ${e.toString()}'],
      );
    }

    if (!pullResponse['success']) {
      return SyncEngineResult(
        success: false,
        errors: pullResponse['errors'] as List<String>,
      );
    }

    // 3. Apply pulled operations + update cursor
    final operations = pullResponse['operations'] as List<Map<String, dynamic>>;
    int pulled = 0;

    try {
      for (final op in operations) {
        try {
          print('[ENGINE][PULL_APPLY] ${op['table']}:${op['recordId']} type=${op['type']}');
          await _applyOperation(op);
          pulled++;
          print('[ENGINE][PULL_APPLY] ✅ ${op['table']}:${op['recordId']} success');
        } catch (e) {
          print('[ENGINE][PULL_APPLY] ❌ ${op['table']}:${op['recordId']} error=$e');
          // Don't increment pulled on failure, but continue to next operation
        }
      }

      final nextCursor = pullResponse['nextCursor'] as String?;
      if (nextCursor != null) {
        await _updateLastSyncTime(DateTime.parse(nextCursor));
      }
    } catch (e) {
      errors.add('Apply failed: ${e.toString()}');
    }

    _log('SYNC_DONE', {
      'device': deviceId,
      'acked': totalAcked,
      'rejected': totalRejected,
      'pulled': pulled,
    });

    return SyncEngineResult(
      success: errors.isEmpty,
      pushed: totalAcked + totalRejected,
      acked: totalAcked,
      rejected: totalRejected,
      pulled: pulled,
      errors: errors,
    );
  }

  Future<Map<String, dynamic>> _pushBatch(Map<String, dynamic> body) async {
    try {
      final response = await dio.post(
        'api/sync',
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer ${await ServiceLocator.instance.secureStorage.read(key: 'auth_token')}',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        int acked = 0;
        int rejected = 0;

        // === FIX TYPE CASTING (List<dynamic> → List<Map>) ===
        final acknowledged = (data['acknowledged'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
        for (final ack in acknowledged) {
          final opId = ack['opId'] as String?;
          final status = ack['status'] as String?;
          final normalized = status?.toLowerCase();
          final error = ack['error'] as Map<String, dynamic>?;

          if ((normalized == 'success' || normalized == 'duplicate') && opId != null) {
            await (db.delete(db.syncOutbox)
                  ..where((t) => t.idempotencyKey.equals(opId)))
                .go();
            acked++;
          } else if (normalized == 'failed' && opId != null) {
            rejected++;
            await _markOutboxFailed(opId, error?['code'], error?['message']);
          }
        }

        return {
          'success': true,
          'acked': acked,
          'rejected': rejected,
        };
      }

      return {'success': false, 'acked': 0, 'rejected': 0};
    } catch (e) {
      return {'success': false, 'acked': 0, 'rejected': 0, 'error': e.toString()};
    }
  }

  Future<void> _markOutboxFailed(String opId, String? code, String? message) async {
    final errorMsg = '${code ?? 'UNKNOWN'}: ${message ?? 'Unknown error'}';
    await (db.update(db.syncOutbox)
          ..where((t) => t.idempotencyKey.equals(opId)))
        .write(SyncOutboxCompanion(
          status: const Value('failed'),
          lastError: Value(errorMsg),
        ));
  }

  Future<Map<String, dynamic>> _pullOnce(DateTime? lastPulledAt) async {
    try {
      final body = {
        'deviceId': deviceId,
        'lastPulledAt': lastPulledAt?.toUtc().toIso8601String() ?? '2020-01-01T00:00:00.000Z',
        'operations': [],
      };

      print('[ENGINE][PULL] Requesting since: ${body['lastPulledAt']}');

      final response = await dio.post(
        'api/sync',
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer ${await ServiceLocator.instance.secureStorage.read(key: 'auth_token')}',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        
        // === FIX TYPE CASTING (List<dynamic> → List<Map>) ===
        final operations = (data['operations'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
        final nextCursor = data['nextCursor'] as String?;

        print('[ENGINE][PULL] Received ${operations.length} operations from server');

        return {
          'success': true,
          'operations': operations,
          'nextCursor': nextCursor,
        };
      }

      return {'success': false, 'operations': [], 'errors': ['HTTP ${response.statusCode}']};
    } catch (e) {
      return {'success': false, 'operations': [], 'errors': [e.toString()]};
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingOutbox(int limit) async {
    final rows =
        await (db.select(db.syncOutbox)
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(limit))
            .get();

    return rows
        .map(
          (row) => {
            'idempotencyKey': row.idempotencyKey,
            'tenantId': row.tenantId,
            'companyId': row.companyId,
            'deviceId': row.deviceId,
            'entity': row.entity,
            'entityId': row.entityId,
            'opType': row.opType,
            'data': jsonDecode(row.data),
            'createdAt': row.createdAt.toIso8601String(),
          },
        )
        .toList();
  }

  Future<DateTime?> _getLastSyncTime() async {
    final state = await (db.select(db.syncState)..where(
          (t) =>
              t.tenantId.equals(tenantId) &
              t.companyId.equals(companyId) &
              t.deviceId.equals(deviceId),
        ))
        .getSingleOrNull();
    return state?.lastSyncAt;
  }

  Future<void> _updateLastSyncTime(DateTime time) async {
    await db
        .into(db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion(
            tenantId: Value(tenantId),
            companyId: Value(companyId),
            deviceId: Value(deviceId),
            lastServerVersion: Value(time.millisecondsSinceEpoch),
            lastSyncAt: Value(time),
          ),
        );
  }

  Future<void> _applyOperation(Map<String, dynamic> op) async {
    final entity = op['table'] as String?;
    final recordId = op['recordId'] as String?;
    final operation = op['type'] as String?;
    final data = op['data'] as Map<String, dynamic>?;

    if (entity == null || recordId == null) return;

    if (operation == 'DELETE') {
      await _deleteEntity(entity, recordId);
      return;
    }

    if (data == null) return;

    await _upsertEntity(entity, recordId, data);
  }

  Future<void> _deleteEntity(String entity, String uuid) async {
    switch (entity) {
      case 'products':
        await (db.delete(db.products)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'categories':
        await (db.delete(db.categories)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'units':
        await (db.delete(db.units)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'brands':
        await (db.delete(db.brands)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'customers':
        await (db.delete(db.customers)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'suppliers':
        await (db.delete(db.suppliers)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'employees':
        await (db.delete(db.employees)..where((t) => t.uuid.equals(uuid))).go();
        break;
      case 'invoices':
        await (db.delete(db.invoices)..where((t) => t.uuid.equals(uuid))).go();
        break;
    }
  }

  Future<void> _upsertEntity(
    String entity,
    String recordKey,
    Map<String, dynamic> data,
  ) async {
    switch (entity) {
      case 'products':
        await _upsertProduct(recordKey, data);
        break;
      case 'categories':
        await _upsertCategory(recordKey, data);
        break;
      case 'units':
        await _upsertUnit(recordKey, data);
        break;
      case 'brands':
        await _upsertBrand(recordKey, data);
        break;
      case 'customers':
        await _upsertCustomer(recordKey, data);
        break;
      case 'suppliers':
        await _upsertSupplier(recordKey, data);
        break;
      case 'employees':
        await _upsertEmployee(recordKey, data);
        break;
      case 'invoices':
        await _upsertInvoice(recordKey, data);
        break;
    }
  }

  Future<void> _upsertProduct(String uuid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');
    
    // Check if record exists
    final existing = await (db.select(db.products)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (existing != null) {
      // UPDATE by uuid
      await (db.update(db.products)..where((t) => t.uuid.equals(uuid))).write(
        ProductsCompanion(
          name: Value(cleanData['name'] as String? ?? ''),
          sku: Value(cleanData['sku'] as String?),
          price: Value((cleanData['price'] as num?)?.toDouble() ?? 0.0),
          cost: Value((cleanData['cost'] as num?)?.toDouble()),
          categoryId: Value(cleanData['categoryId'] as int?),
          unitId: Value(cleanData['unitId'] as int?),
          brandId: Value(cleanData['brandId'] as int?),
          stockQuantity: Value(cleanData['stockQuantity'] as int? ?? 0),
          isActive: Value(cleanData['isActive'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    } else {
      // INSERT new
      await db.into(db.products).insert(
        ProductsCompanion(
          uuid: Value(uuid),
          name: Value(cleanData['name'] as String? ?? ''),
          sku: Value(cleanData['sku'] as String?),
          price: Value((cleanData['price'] as num?)?.toDouble() ?? 0.0),
          cost: Value((cleanData['cost'] as num?)?.toDouble()),
          categoryId: Value(cleanData['categoryId'] as int?),
          unitId: Value(cleanData['unitId'] as int?),
          brandId: Value(cleanData['brandId'] as int?),
          stockQuantity: Value(cleanData['stockQuantity'] as int? ?? 0),
          isActive: Value(cleanData['isActive'] as bool? ?? true),
          tenantId: Value(int.tryParse(tenantId) ?? 1),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    }
  }

Future<void> _upsertCategory(String uuid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');
    
    final existing = await (db.select(db.categories)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (existing != null) {
      await (db.update(db.categories)..where((t) => t.uuid.equals(uuid))).write(
        CategoriesCompanion(
          name: Value(cleanData['name'] as String? ?? ''),
          subcategory: Value(cleanData['subcategory'] as String?),
          description: Value(cleanData['description'] as String?),
          isActive: Value(cleanData['isActive'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    } else {
      await db.into(db.categories).insert(
        CategoriesCompanion(
          uuid: Value(uuid),
          name: Value(cleanData['name'] as String? ?? ''),
          subcategory: Value(cleanData['subcategory'] as String?),
          description: Value(cleanData['description'] as String?),
          isActive: Value(cleanData['isActive'] as bool? ?? true),
          tenantId: Value(int.tryParse(tenantId) ?? 1),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertInvoice(String uuid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');
    
    final existing = await (db.select(db.invoices)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (existing != null) {
      await (db.update(db.invoices)..where((t) => t.uuid.equals(uuid))).write(
        InvoicesCompanion(
          invoiceNumber: Value(cleanData['invoiceNumber'] as String? ?? ''),
          customerId: Value(cleanData['customerId'] as int?),
          subtotal: Value((cleanData['subtotal'] as num?)?.toDouble() ?? 0.0),
          tax: Value((cleanData['tax'] as num?)?.toDouble() ?? 0.0),
          discount: Value((cleanData['discount'] as num?)?.toDouble() ?? 0.0),
          total: Value((cleanData['total'] as num?)?.toDouble() ?? 0.0),
          paymentMethod: Value(cleanData['paymentMethod'] as String?),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    } else {
      await db.into(db.invoices).insert(
        InvoicesCompanion(
          uuid: Value(uuid),
          invoiceNumber: Value(cleanData['invoiceNumber'] as String? ?? ''),
          customerId: Value(cleanData['customerId'] as int?),
          date: Value(cleanData['date'] != null ? DateTime.parse(cleanData['date'] as String) : DateTime.now()),
          subtotal: Value((cleanData['subtotal'] as num?)?.toDouble() ?? 0.0),
          tax: Value((cleanData['tax'] as num?)?.toDouble() ?? 0.0),
          discount: Value((cleanData['discount'] as num?)?.toDouble() ?? 0.0),
          total: Value((cleanData['total'] as num?)?.toDouble() ?? 0.0),
          paymentMethod: Value(cleanData['paymentMethod'] as String?),
          tenantId: Value(int.tryParse(tenantId) ?? 1),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertUnit(String uuid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');
    
    final existing = await (db.select(db.units)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (existing != null) {
      await (db.update(db.units)..where((t) => t.uuid.equals(uuid))).write(
        UnitsCompanion(
          name: Value(cleanData['name'] as String? ?? ''),
          symbol: Value(cleanData['symbol'] as String? ?? ''),
          isActive: Value(cleanData['isActive'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    } else {
      await db.into(db.units).insert(
        UnitsCompanion(
          uuid: Value(uuid),
          name: Value(cleanData['name'] as String? ?? ''),
          symbol: Value(cleanData['symbol'] as String? ?? ''),
          isActive: Value(cleanData['isActive'] as bool? ?? true),
          tenantId: Value(int.tryParse(tenantId) ?? 1),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertBrand(String uuid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');
    
    final existing = await (db.select(db.brands)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (existing != null) {
      await (db.update(db.brands)..where((t) => t.uuid.equals(uuid))).write(
        BrandsCompanion(
          name: Value(cleanData['name'] as String? ?? ''),
          description: Value(cleanData['description'] as String?),
          isActive: Value(cleanData['isActive'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    } else {
      await db.into(db.brands).insert(
        BrandsCompanion(
          uuid: Value(uuid),
          name: Value(cleanData['name'] as String? ?? ''),
          description: Value(cleanData['description'] as String?),
          isActive: Value(cleanData['isActive'] as bool? ?? true),
          tenantId: Value(int.tryParse(tenantId) ?? 1),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    }
  }

Future<void> _upsertCustomer(String uuid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');
    
    final existing = await (db.select(db.customers)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (existing != null) {
      await (db.update(db.customers)..where((t) => t.uuid.equals(uuid))).write(
        CustomersCompanion(
          name: Value(cleanData['name'] as String? ?? ''),
          phone: Value(cleanData['phone'] as String?),
          email: Value(cleanData['email'] as String?),
          address: Value(cleanData['address'] as String?),
          creditLimit: Value((cleanData['creditLimit'] as num?)?.toDouble() ?? 0.0),
          currentBalance: Value((cleanData['currentBalance'] as num?)?.toDouble() ?? 0.0),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    } else {
      await db.into(db.customers).insert(
        CustomersCompanion(
          uuid: Value(uuid),
          name: Value(cleanData['name'] as String? ?? ''),
          phone: Value(cleanData['phone'] as String?),
          email: Value(cleanData['email'] as String?),
          address: Value(cleanData['address'] as String?),
          creditLimit: Value((cleanData['creditLimit'] as num?)?.toDouble() ?? 0.0),
          currentBalance: Value((cleanData['currentBalance'] as num?)?.toDouble() ?? 0.0),
          tenantId: Value(int.tryParse(tenantId) ?? 1),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    }
  }

Future<void> _upsertSupplier(String uuid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');
    
    final existing = await (db.select(db.suppliers)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (existing != null) {
      await (db.update(db.suppliers)..where((t) => t.uuid.equals(uuid))).write(
        SuppliersCompanion(
          name: Value(cleanData['name'] as String? ?? ''),
          phone: Value(cleanData['phone'] as String?),
          email: Value(cleanData['email'] as String?),
          address: Value(cleanData['address'] as String?),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    } else {
      await db.into(db.suppliers).insert(
        SuppliersCompanion(
          uuid: Value(uuid),
          name: Value(cleanData['name'] as String? ?? ''),
          phone: Value(cleanData['phone'] as String?),
          email: Value(cleanData['email'] as String?),
          address: Value(cleanData['address'] as String?),
          tenantId: Value(int.tryParse(tenantId) ?? 1),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> _upsertEmployee(String uuid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');
    
    final existing = await (db.select(db.employees)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (existing != null) {
      await (db.update(db.employees)..where((t) => t.uuid.equals(uuid))).write(
        EmployeesCompanion(
          name: Value(cleanData['name'] as String? ?? ''),
          phone: Value(cleanData['phone'] as String?),
          email: Value(cleanData['email'] as String?),
          address: Value(cleanData['address'] as String?),
          role: Value(cleanData['role'] as String? ?? 'employee'),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    } else {
      await db.into(db.employees).insert(
        EmployeesCompanion(
          uuid: Value(uuid),
          name: Value(cleanData['name'] as String? ?? ''),
          phone: Value(cleanData['phone'] as String?),
          email: Value(cleanData['email'] as String?),
          address: Value(cleanData['address'] as String?),
          role: Value(cleanData['role'] as String? ?? 'employee'),
          password: Value(cleanData['password'] as String?),
          tenantId: Value(int.tryParse(tenantId) ?? 1),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
          isDeleted: Value(cleanData['isDeleted'] as bool? ?? false),
        ),
      );
    }
  }

  Future<void> logOperation({
    required String entity,
    required String entityId,
    required SyncOpType opType,
    required Map<String, dynamic> data,
  }) async {
    final now = DateTime.now();
    await db
        .into(db.syncOutbox)
        .insertOnConflictUpdate(
          SyncOutboxCompanion(
            idempotencyKey: Value('${entityId}_${now.millisecondsSinceEpoch}'),
            tenantId: Value(tenantId),
            companyId: Value(companyId),
            deviceId: Value(deviceId),
            entity: Value(entity),
            entityId: Value(entityId),
            opType: Value(opType as int),
            data: Value(jsonEncode(data)),
            createdAt: Value(now),
          ),
        );
  }

  Future<bool> hasPendingOperations() async {
    final count = await (db.select(db.syncOutbox)..limit(1)).get();
    return count.isNotEmpty;
  }

  Future<int> pendingCount() async {
    final countExp = db.syncOutbox.id.count();
    final query = db.selectOnly(db.syncOutbox)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<void> clearOutbox() async {
    await db.delete(db.syncOutbox).go();
  }

  Future<void> cleanAndFullSync() async {
    await clearOutbox();
    await _updateLastSyncTime(DateTime.fromMillisecondsSinceEpoch(0));
    await sync();
  }
}
