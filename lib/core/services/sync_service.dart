import 'dart:async';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';
// import '../models/enums/sync_status.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/unit_repository.dart';
import '../repositories/brand_repository.dart';
import '../../config/app_config.dart';

// Sync result tracking
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
    if (_isSyncing) return;

    // Skip sync if no auth token exists (user not logged in)
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) return;

    _isSyncing = true;

    try {
      await push();
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

  Future<void> pull() async {
    if (_isPulling) return;
    _isPulling = true;

    try {
      // Skip pull if no auth token exists (user not logged in)
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return;

      // Force full sync if database is empty
      final productCount = await (db.select(db.products)..limit(1)).get();
      if (productCount.isEmpty) {
        // Clear the lastSyncTime to force a full sync
        await (db.delete(
          db.syncMetadata,
        )..where((t) => t.key.equals('lastSyncTime'))).go();
      }

      var lastSyncTime = await _getLastSyncTime();

      final response = await dio.post(
        'api/sync',
        data: {'lastSyncTime': lastSyncTime?.toIso8601String()},
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        final updates = responseData['updates'] as Map<String, dynamic>?;
        if (updates != null) {
          updates.forEach((key, value) {
            if (value is List) {}
          });
          await _applyUpdates(updates);
        }
        await _updateLastSyncTime(DateTime.now());
      }
    } catch (e) {
      if (e is DioException) {}
    } finally {
      _isPulling = false;
    }
  }

  /// Force a full sync, ignoring lastSyncTime
  /// Useful for initial loads or when you need to fetch all historical data
  Future<void> forcePull() async {
    try {
      final response = await dio.post(
        'api/sync',
        data: {
          'lastSyncTime': null, // Force full sync by passing null
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        final updates = responseData['updates'] as Map<String, dynamic>?;
        if (updates != null) {
          // Log specific table counts
          updates.forEach((key, value) {
            if (value is List) {}
          });
          await _applyUpdates(updates);
        }
        // Update lastSyncTime to now so future incremental syncs work correctly
        await _updateLastSyncTime(DateTime.now());
      }
    } catch (e) {
      if (e is DioException) {}
      rethrow; // Re-throw to allow caller to handle
    }
  }

  Future<SyncResult> push() async {
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

      const int productBatchSize = 25;
      for (var i = 0; i < pendingProducts.length; i += productBatchSize) {
        final end = (i + productBatchSize < pendingProducts.length)
            ? i + productBatchSize
            : pendingProducts.length;
        final chunk = pendingProducts.sublist(i, end);
        final List<Map<String, dynamic>> batchData = [];

        for (final prod in chunk) {
          final unit = prod.unitId != null
              ? await (db.select(db.units)..where((t) => t.id.equals(prod.unitId!))).getSingleOrNull()
              : null;
          final category = prod.categoryId != null
              ? await (db.select(db.categories)..where((t) => t.id.equals(prod.categoryId!))).getSingleOrNull()
              : null;
          final brand = prod.brandId != null
              ? await (db.select(db.brands)..where((t) => t.id.equals(prod.brandId!))).getSingleOrNull()
              : null;

          batchData.add({
            'uuid': prod.uuid,
            'name': prod.name,
            'sku': prod.sku,
            'price': prod.price,
            'cost': prod.cost,
            'stockQuantity': prod.stockQuantity,
            'categoryId': prod.categoryId,
            'categoryUuid': category?.uuid,
            'unitId': prod.unitId,
            'unitUuid': unit?.uuid,
            'brandId': prod.brandId,
            'brandUuid': brand?.uuid,
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
            await (db.update(db.customers)..where((t) => t.id.equals(customer.id)))
                .write(const CustomersCompanion(syncStatus: Value(0)));
          },
          'Customer: ${customer.name}',
          onPermanentFailure: () async {
            await (db.update(db.customers)..where((t) => t.id.equals(customer.id)))
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
            await (db.update(db.suppliers)..where((t) => t.id.equals(supplier.id)))
                .write(const SuppliersCompanion(syncStatus: Value(0)));
          },
          'Supplier: ${supplier.name}',
          onPermanentFailure: () async {
            await (db.update(db.suppliers)..where((t) => t.id.equals(supplier.id)))
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
            await (db.update(db.employees)..where((t) => t.id.equals(employee.id)))
                .write(const EmployeesCompanion(syncStatus: Value(0)));
          },
          'Employee: ${employee.name}',
          onPermanentFailure: () async {
            await (db.update(db.employees)..where((t) => t.id.equals(employee.id)))
                .write(const EmployeesCompanion(syncStatus: Value(2)));
          },
        );
        if (success) {
          syncedCounts['employees'] = syncedCounts['employees']! + 1;
        } else {
          failedCounts['employees'] = failedCounts['employees']! + 1;
        }
      }

      // Invoices
      final pendingInvoices = await (db.select(
        db.invoices,
      )..where((t) => t.syncStatus.equals(1))).get();
      for (final inv in pendingInvoices) {
        final itemsWithProducts = await (db.select(
          db.invoiceItems,
        ).join([
          innerJoin(db.products, db.products.id.equalsExp(db.invoiceItems.productId)),
        ])..where(db.invoiceItems.invoiceId.equals(inv.id))).get();

        final customer = inv.customerId != null
            ? await (db.select(db.customers)..where((t) => t.id.equals(inv.customerId!))).getSingleOrNull()
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
