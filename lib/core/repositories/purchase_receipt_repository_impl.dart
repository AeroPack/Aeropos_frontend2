import 'package:drift/drift.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/core/repositories/purchase_receipt_repository.dart';
import 'package:ezo/core/di/service_locator.dart';
import 'package:ezo/core/services/unit_conversion_service.dart';

class PurchaseReceiptRepositoryImpl implements PurchaseReceiptRepository {
  final AppDatabase db;

  PurchaseReceiptRepositoryImpl(this.db);

  @override
  Future<int> insertPurchaseReceipt(PurchaseReceiptsCompanion entry) async {
    final id = await db.into(db.purchaseReceipts).insert(entry);
    ServiceLocator.instance.syncService.sync();
    return id;
  }

  @override
  Future<List<PurchaseReceiptEntity>> getAllPurchaseReceipts() async {
    return await (db.select(db.purchaseReceipts)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  @override
  Stream<List<PurchaseReceiptEntity>> watchAllPurchaseReceipts(int tenantId) {
    return (db.select(db.purchaseReceipts)
          ..where(
            (t) => t.isDeleted.equals(false) & t.tenantId.equals(tenantId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  @override
  Future<void> deletePurchaseReceipt(int id) async {
    final now = DateTime.now();
    await (db.update(db.purchaseReceipts)..where((t) => t.id.equals(id))).write(
      PurchaseReceiptsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        syncStatus: const Value(1),
      ),
    );
    ServiceLocator.instance.syncService.sync();
  }

  @override
  Future<void> updatePurchaseReceipt(PurchaseReceiptEntity entry) async {
    await (db.update(
      db.purchaseReceipts,
    )..where((t) => t.id.equals(entry.id))).write(entry.toCompanion(true));
    ServiceLocator.instance.syncService.sync();
  }

  @override
  Future<int> createPurchaseWithItems({
    required PurchaseReceiptsCompanion header,
    required List<PurchaseReceiptItemsCompanion> items,
  }) async {
    return await db.transaction(() async {
      final receiptId = await db.into(db.purchaseReceipts).insert(header);

      for (final item in items) {
        final itemWithReceiptId = PurchaseReceiptItemsCompanion(
          receiptId: Value(receiptId),
          productId: item.productId,
          quantity: item.quantity,
          unitId: item.unitId,
          price: item.price,
          totalPrice: item.totalPrice,
          discountPerItem: item.discountPerItem,
          taxPerItem: item.taxPerItem,
          isDeleted: const Value(false),
        );
        await db.into(db.purchaseReceiptItems).insert(itemWithReceiptId);

        final product = await (db.select(
          db.products,
        )..where((t) => t.id.equals(item.productId.value))).getSingleOrNull();

        if (product != null) {
          final conversionService = UnitConversionService(db);
          final unitId = item.unitId.value;
          final qtyInBase = await conversionService.convertToBaseUnit(
            productId: item.productId.value,
            quantity: item.quantity.value.toDouble(),
            fromUnitId: unitId ?? product.unitId ?? 1,
          );
          final newStock = product.stockQuantity + qtyInBase.toInt();
          await (db.update(
            db.products,
          )..where((t) => t.id.equals(item.productId.value))).write(
            ProductsCompanion(
              stockQuantity: Value(newStock),
              updatedAt: Value(DateTime.now()),
              syncStatus: const Value(1),
            ),
          );
        }
      }

      ServiceLocator.instance.syncService.sync();
      return receiptId;
    });
  }

  @override
  Future<void> updateProductStock(
    int productId,
    double additionalQuantity, {
    int? unitId,
  }) async {
    final product = await (db.select(
      db.products,
    )..where((t) => t.id.equals(productId))).getSingleOrNull();

    if (product != null) {
      final conversionService = UnitConversionService(db);
      final qtyInBase = await conversionService.convertToBaseUnit(
        productId: productId,
        quantity: additionalQuantity,
        fromUnitId: unitId ?? product.unitId ?? 1,
      );
      final newStock = product.stockQuantity + qtyInBase.toInt();
      await (db.update(
        db.products,
      )..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          stockQuantity: Value(newStock),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(1),
        ),
      );
    }
  }

  @override
  Future<void> updatePurchaseWithItems({
    required int receiptId,
    required int supplierId,
    required DateTime date,
    String? supplierInvoiceNumber,
    required double subtotal,
    required double tax,
    required double discount,
    required double totalAmount,
    String? notes,
    required List<PurchaseReceiptItemsCompanion> items,
  }) async {
    await db.transaction(() async {
      // Update the receipt header
      await (db.update(
        db.purchaseReceipts,
      )..where((t) => t.id.equals(receiptId))).write(
        PurchaseReceiptsCompanion(
          supplierId: Value(supplierId),
          date: Value(date),
          supplierInvoiceNumber: Value(supplierInvoiceNumber),
          subtotal: Value(subtotal),
          tax: Value(tax),
          discount: Value(discount),
          totalAmount: Value(totalAmount),
          notes: Value(notes),
          updatedAt: Value(DateTime.now()),
          syncStatus: Value(1),
        ),
      );

      // Delete existing items
      await (db.delete(
        db.purchaseReceiptItems,
      )..where((t) => t.receiptId.equals(receiptId))).go();

      // Insert new items
      for (final item in items) {
        final itemWithReceiptId = PurchaseReceiptItemsCompanion(
          receiptId: Value(receiptId),
          productId: item.productId,
          quantity: item.quantity,
          unitId: item.unitId,
          price: item.price,
          totalPrice: item.totalPrice,
          discountPerItem: item.discountPerItem,
          taxPerItem: item.taxPerItem,
          isDeleted: const Value(false),
        );
        await db.into(db.purchaseReceiptItems).insert(itemWithReceiptId);
      }

      ServiceLocator.instance.syncService.sync();
    });
  }

  @override
  Stream<List<PurchaseReceiptItemEntity>> watchItemsByReceiptId(int receiptId) {
    return (db.select(db.purchaseReceiptItems)..where(
          (t) => t.receiptId.equals(receiptId) & t.isDeleted.equals(false),
        ))
        .watch();
  }

  @override
  Future<List<PurchaseReceiptItemEntity>> getItemsByReceiptId(
    int receiptId,
  ) async {
    return await (db.select(db.purchaseReceiptItems)..where(
          (t) => t.receiptId.equals(receiptId) & t.isDeleted.equals(false),
        ))
        .get();
  }
}
