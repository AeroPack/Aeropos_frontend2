import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/sku_generator.dart';
import '../services/tenant_service.dart';
import '../../config/app_config.dart';
import '../services/sync_service.dart';
import '../services/sync_engine.dart';
import '../services/device_id_service.dart';
import '../repositories/sync_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/unit_repository.dart';
import '../repositories/brand_repository.dart';
import '../repositories/customer_transaction_repository.dart';
import '../repositories/customer_transaction_repository_impl.dart';
import '../repositories/supplier_transaction_repository.dart';
import '../repositories/supplier_transaction_repository_impl.dart';
import '../repositories/purchase_receipt_repository.dart';
import '../repositories/purchase_receipt_repository_impl.dart';
import '../services/inventory_service.dart';
import 'package:ezo/core/viewModel/product_view_model.dart';
import 'package:ezo/core/viewModel/category_view_model.dart';
import 'package:ezo/core/viewModel/unit_view_model.dart';
import 'package:ezo/core/viewModel/brand_view_model.dart';
import 'package:ezo/core/viewModel/customer_view_model.dart';
import 'package:ezo/core/viewModel/supplier_view_model.dart';
import 'package:ezo/core/viewModel/employee_view_model.dart';
import 'package:ezo/core/viewModel/customer_transaction_view_model.dart';
import 'package:ezo/core/viewModel/supplier_transaction_view_model.dart';
import 'package:ezo/core/viewModel/purchase_receipt_view_model.dart';
import '../database/app_database.dart';
import '../network/auth_interceptor.dart';
import '../network/dio_client.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import 'package:http/http.dart' as http;

class ServiceLocator {
  static final instance = ServiceLocator._();
  ServiceLocator._();

  late final AppDatabase database;
  late final FlutterSecureStorage secureStorage;
  late final Dio dio;

  late final ProductRepository productRepository;
  late final CustomerRepository customerRepository;
  late final SupplierRepository supplierRepository;
  late final EmployeeRepository employeeRepository;
  late final SaleRepository saleRepository;
  late final CategoryRepository categoryRepository;
  late final UnitRepository unitRepository;
  late final BrandRepository brandRepository;
  late final CustomerTransactionRepository customerTransactionRepository;
  late final SupplierTransactionRepository supplierTransactionRepository;
  late final PurchaseReceiptRepository purchaseReceiptRepository;
  late final AuthRepository authRepository;
  late final AuthRemoteDataSource authRemoteDataSource;
  late final ProfileRepository profileRepository;

  late final InventoryService inventoryService;
  late final SyncService syncService;
  late final SyncEngine syncEngine;
  late final SyncRepository syncRepository;
  late final TenantService tenantService;
  late final SkuGenerator skuGenerator;
  late final DeviceIdService deviceIdService;

  late final ProductViewModel productViewModel;
  late final CategoryViewModel categoryViewModel;
  late final UnitViewModel unitViewModel;
  late final BrandViewModel brandViewModel;
  late final CustomerViewModel customerViewModel;
  late final SupplierViewModel supplierViewModel;
  late final EmployeeViewModel employeeViewModel;
  late final CustomerTransactionViewModel customerTransactionViewModel;
  late final SupplierTransactionViewModel supplierTransactionViewModel;
  late final PurchaseReceiptViewModel purchaseReceiptViewModel;

Future<void> initialize() async {
    // Initialize database
    database = AppDatabase();

    // Initialize secure storage
    if (kIsWeb) {
      secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(),
        iOptions: IOSOptions(),
      );
    } else {
      secureStorage = const FlutterSecureStorage();
    }

    // Initialize network
    final authInterceptor = AuthInterceptor(secureStorage);
    dio = DioClient.createDio(authInterceptor);

    // Initialize data sources
    authRemoteDataSource = AuthRemoteDataSourceImpl(dio);

    // Initialize repositories
    productRepository = ProductRepository(database);
    customerRepository = CustomerRepository(database);
    supplierRepository = SupplierRepository(database);
    employeeRepository = EmployeeRepository(database);
    saleRepository = SaleRepository(database);
    categoryRepository = CategoryRepository(database);
    unitRepository = UnitRepository(database);
    brandRepository = BrandRepository(database);
    customerTransactionRepository = CustomerTransactionRepositoryImpl(database);
    supplierTransactionRepository = SupplierTransactionRepositoryImpl(database);
    purchaseReceiptRepository = PurchaseReceiptRepositoryImpl(database);
    authRepository = AuthRepositoryImpl(
      authRemoteDataSource,
      secureStorage,
      database,
    );
    profileRepository = ProfileRepositoryImpl(
      http.Client(),
      secureStorage,
      baseUrl: AppConfig.apiBaseUrl,
    );

    // Initialize services
    tenantService = TenantService(secureStorage);
    await tenantService.initialize();

    // Device ID for multi-device sync
    deviceIdService = DeviceIdService(database);
    final deviceId = await deviceIdService.getDeviceId();

    skuGenerator = SkuGenerator();

    // Initialize sync infrastructure
    inventoryService = InventoryService(productRepository);

    // Use nullable tenantId to prevent crash if not restored from storage
    final currentTenantId =
        tenantService.tenantIdOrNull?.toString() ?? 'pending';

    syncRepository = SyncRepository(
      db: database,
      tenantId: currentTenantId,
      companyId: 'default',
      deviceId: deviceId,
    );

    syncEngine = SyncEngine(
      db: database,
      dio: dio,
      tenantId: currentTenantId,
      companyId: 'default',
      deviceId: deviceId,
    );

    // Start background sync (only once)
    // Now ENABLE SyncEngine (was disabled, causing push issues)
    syncEngine.startAutoSync();

    // Keep old SyncService for backward compatibility (but DON'T start its auto-sync)
    syncService = SyncService(
      db: database,
      dio: dio,
      productRepo: productRepository,
      customerRepo: customerRepository,
      supplierRepo: supplierRepository,
      employeeRepo: employeeRepository,
      saleRepo: saleRepository,
      categoryRepo: categoryRepository,
      unitRepo: unitRepository,
      brandRepo: brandRepository,
    );

    // Initialize view models
    productViewModel = ProductViewModel(
      database,
      categoryRepository,
      unitRepository,
      brandRepository,
      syncService,
    );
    categoryViewModel = CategoryViewModel(database, syncService);
    unitViewModel = UnitViewModel(database, syncService);
    brandViewModel = BrandViewModel(database, syncService);
    customerViewModel = CustomerViewModel(
      database,
      customerRepository,
      syncService,
    );
    supplierViewModel = SupplierViewModel(
      database,
      supplierRepository,
      syncService,
    );
    customerTransactionViewModel = CustomerTransactionViewModel(
      customerTransactionRepository,
      database,
    );
    supplierTransactionViewModel = SupplierTransactionViewModel(
      supplierTransactionRepository,
      database,
    );
    purchaseReceiptViewModel = PurchaseReceiptViewModel(
      purchaseReceiptRepository,
      database,
    );
    employeeViewModel = EmployeeViewModel(
      database,
      employeeRepository,
      syncService,
    );

    // SyncEngine is now handling auto-sync via startAutoSync()
// SyncService auto-sync is DISABLED to avoid duplicate syncs
// if (tenantService.tenantIdOrNull != null) {
//   syncService.startAutoSync(interval: const Duration(minutes: 5));
// }
  }

  Future<void> dispose() async {
    syncService.stopAutoSync();
  }
}
