import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../database/tables/product_units_table.dart';
import '../services/sync_service.dart';
import 'package:uuid/uuid.dart';
import '../repositories/category_repository.dart';
import '../repositories/unit_repository.dart';
import '../repositories/brand_repository.dart';
import '../models/category.dart';
import '../models/unit.dart';
import '../models/brand.dart';
import '../di/service_locator.dart';

class ProductViewModel {
  final AppDatabase _database;
  final CategoryRepository _categoryRepository;
  final UnitRepository _unitRepository;
  final BrandRepository _brandRepository;
  final SyncService _syncService;
  final _uuid = const Uuid();

  ProductViewModel(
    this._database,
    this._categoryRepository,
    this._unitRepository,
    this._brandRepository,
    this._syncService,
  );

  AppDatabase get database => _database;

  Stream<List<ProductEntity>> get allProducts => _database.watchAllProducts();

  Stream<List<drift.TypedResult>> get allProductsWithCategory =>
      _database.watchProductsWithCategory();

  Stream<List<Category>> get allCategories =>
      _categoryRepository.watchAllCategories();
  Stream<List<Unit>> get allUnits => _unitRepository.watchAllUnits();
  Stream<List<Brand>> get allBrands => _brandRepository.watchAllBrands();

  Future<void> addProduct({
    required String name,
    required String sku,
    required double price,
    required double stockQuantity,
    double? cost, // Added cost
    int? categoryId,
    int? unitId,
    int? brandId, // Added
    String? gstType,
    String? gstRate,
    String? description,
    String? localPath,
    String? imageUrl, // Remote URL or Base64 data URI (for web)
    double discount = 0.0,
    bool isPercentDiscount = false,
  }) async {
    final entry = ProductsCompanion(
      uuid: drift.Value(_uuid.v4()),
      name: drift.Value(name),
      sku: sku.isEmpty ? const drift.Value(null) : drift.Value(sku),
      price: drift.Value(price),
      stockQuantity: drift.Value(stockQuantity.toInt()),
      cost: drift.Value(cost), // Added cost
      categoryId: drift.Value(categoryId),
      unitId: drift.Value(unitId),
      brandId: drift.Value(brandId), // Added
      gstType: drift.Value(gstType),
      gstRate: drift.Value(gstRate),
      description: drift.Value(description),
      localPath: drift.Value(localPath),
      imageUrl: drift.Value(imageUrl),
      discount: drift.Value(discount),
      isPercentDiscount: drift.Value(isPercentDiscount),
      isActive: const drift.Value(true),
      tenantId: const drift.Value(1), // Default tenant ID
      syncStatus: const drift.Value(1), // Pending
      isDeleted: const drift.Value(false),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    );

    try {
      await _database.insertProduct(entry);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isSkuUnique(String sku, {int? excludeId}) async {
    final query = _database.select(_database.products)
      ..where((tbl) => tbl.sku.equals(sku))
      ..where((tbl) => tbl.isDeleted.equals(false));
    if (excludeId != null) {
      query.where((tbl) => tbl.id.isNotValue(excludeId));
    }
    final result = await query.getSingleOrNull();
    return result == null;
  }

  Future<bool> isNameUnique(String name, {int? excludeId}) async {
    final query = _database.select(_database.products)
      ..where((tbl) => tbl.name.equals(name))
      ..where((tbl) => tbl.isDeleted.equals(false));
    if (excludeId != null) {
      query.where((tbl) => tbl.id.isNotValue(excludeId));
    }
    final result = await query.getSingleOrNull();
    return result == null;
  }

  Future<void> updateProduct(ProductEntity product) async {
    await _database.updateProduct(product);
  }

  Future<void> deleteProduct(int id) async {
    await _database.deleteProduct(id);
  }

  Future<void> syncPendingProducts() async {
    try {
      await _syncService.push();
    } catch (e) {
      print('ProductViewModel syncPendingProducts error: $e');
    }
  }

  Future<void> fetchAndSync() async {
    try {
      await _syncService.pull();
    } catch (e) {
      print('ProductViewModel fetchAndSync error: $e');
    }
  }

  Future<String> generateNextSku() async {
    return await ServiceLocator.instance.skuGenerator.generateNextSku();
  }

  Future<void> saveProductUnit(ProductUnitsCompanion unit) async {
    await _database.into(_database.productUnits).insert(unit);
  }

  Future<void> updateProductUnit(ProductUnitsCompanion unit) async {
    await (_database.update(
      _database.productUnits,
    )..where((t) => t.id.equals(unit.id.value))).write(unit);
  }

  Future<List<ProductUnitEntity>> getProductUnits(int productId) async {
    return await (_database.select(
      _database.productUnits,
    )..where((t) => t.productId.equals(productId))).get();
  }

  Future<void> deleteProductUnits(int productId) async {
    await (_database.delete(
      _database.productUnits,
    )..where((t) => t.productId.equals(productId))).go();
  }

  Future<void> deleteProductUnit(int id) async {
    await (_database.delete(
      _database.productUnits,
    )..where((t) => t.id.equals(id))).go();
  }
}
