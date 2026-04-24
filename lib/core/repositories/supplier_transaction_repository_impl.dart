import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/dao/supplier_transaction_dao.dart';
import '../models/supplier_transaction.dart';
import '../models/enums/sync_status.dart';
import '../di/service_locator.dart';
import 'supplier_transaction_repository.dart';

class SupplierTransactionRepositoryImpl
    implements SupplierTransactionRepository {
  final AppDatabase db;
  final SupplierTransactionDao _dao;

  SupplierTransactionRepositoryImpl(this.db) : _dao = db.supplierTransactionDao;

  @override
  Future<List<SupplierTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? supplierId,
    TransactionType? type,
  }) async {
    var entities = await _dao.getAll();

    if (supplierId != null) {
      entities = entities
          .where((e) => e.supplierId.toString() == supplierId)
          .toList();
    }

    if (type != null) {
      entities = entities.where((e) => e.type == type.name).toList();
    }

    if (startDate != null) {
      entities = entities
          .where(
            (e) =>
                e.createdAt.isAfter(startDate) ||
                e.createdAt.isAtSameMomentAs(startDate),
          )
          .toList();
    }

    if (endDate != null) {
      entities = entities
          .where(
            (e) => e.createdAt.isBefore(endDate.add(const Duration(days: 1))),
          )
          .toList();
    }

    return Future.wait(entities.map((e) => _mapToDomain(e)));
  }

  @override
  Future<void> addTransaction(SupplierTransaction transaction) async {
    final companion = SupplierTransactionsCompanion(
      uuid: Value(transaction.id),
      supplierId: Value(int.tryParse(transaction.supplierId) ?? 0),
      amount: Value(transaction.amount),
      type: Value(transaction.type.name),
      remarks: Value(transaction.remarks),
      tenantId: const Value(1),
      syncStatus: Value(SyncStatus.pending.value),
    );
    await _dao.insert(companion);
    ServiceLocator.instance.syncService.sync();
  }

  @override
  Future<void> updateTransaction(SupplierTransaction transaction) async {
    final entity = await _dao.getById(int.tryParse(transaction.id) ?? 0);
    if (entity != null) {
      final updated = entity.copyWith(
        amount: transaction.amount,
        type: transaction.type.name,
        remarks: Value(transaction.remarks),
        syncStatus: SyncStatus.pending.value,
        updatedAt: DateTime.now(),
      );
      await _dao.update_(updated);
      ServiceLocator.instance.syncService.sync();
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _dao.softDelete(int.tryParse(id) ?? 0);
    ServiceLocator.instance.syncService.sync();
  }

  @override
  Future<double> getSupplierBalance(String supplierId) async {
    return _dao.getBalance(int.tryParse(supplierId) ?? 0);
  }

  @override
  Future<void> syncPendingTransactions() async {
    await _dao.getPendingSync();
  }

  Future<SupplierTransaction> _mapToDomain(
    SupplierTransactionEntity entity,
  ) async {
    final supplier = await _getSupplierById(entity.supplierId);
    return SupplierTransaction(
      id: entity.id.toString(),
      supplierId: entity.supplierId.toString(),
      supplierName: supplier?.name ?? 'Unknown',
      amount: entity.amount,
      type: entity.type == 'credit'
          ? TransactionType.credit
          : TransactionType.debit,
      remarks: entity.remarks,
      createdAt: entity.createdAt,
      syncStatus: SyncStatus.fromValue(entity.syncStatus),
    );
  }

  Future<SupplierEntity?> _getSupplierById(int supplierId) async {
    final suppliers = await (db.select(
      db.suppliers,
    )..where((t) => t.id.equals(supplierId) & t.isDeleted.equals(false))).get();
    return suppliers.isNotEmpty ? suppliers.first : null;
  }
}
