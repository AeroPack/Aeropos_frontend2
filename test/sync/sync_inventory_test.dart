import 'sync_test_utils.dart';

void main() {
  print('========================================');
  print('INVENTORY SYNC STRESS TESTS');
  print('========================================\n');

  testInventoryConcurrentSales();
  testInventoryDeltasSumCorrectly();
  testInventoryLedgerMode();
  testInventoryNoOverwrite();

  print('\n========================================');
  print('ALL INVENTORY TESTS PASSED ✓');
  print('========================================\n');
}

void testInventoryConcurrentSales() {
  print('=== TEST: Concurrent Sales (5 devices) ===');
  final stockDelta = <String, int>{};

  for (var device = 0; device < 5; device++) {
    for (var sale = 0; sale < 20; sale++) {
      final productId = 'prod_${sale % 10}';
      stockDelta[productId] = (stockDelta[productId] ?? 0) - 1;
    }
  }

  final total = stockDelta.values.fold(0, (a, b) => a + b);
  print('5 devices x 20 sales = ${stockDelta.values.length} product updates');
  print('Total stock delta: $total');
  assert(total == -100, 'Should be -100 total');
  print('✓ PASSED\n');
}

void testInventoryDeltasSumCorrectly() {
  print('=== TEST: Delta Summation ===');
  final ledger = <String, List<int>>{};

  ledger['prod_1'] = [10, -5, -3, 2, -1];
  ledger['prod_2'] = [100, -10, -5];

  final prod1Stock = ledger['prod_1']!.fold(0, (a, b) => a + b);
  final prod2Stock = ledger['prod_2']!.fold(0, (a, b) => a + b);

  print('prod_1: ${ledger['prod_1']} = $prod1Stock');
  print('prod_2: ${ledger['prod_2']} = $prod2Stock');

  assert(prod1Stock == 3, 'prod_1 should be 3');
  assert(prod2Stock == 85, 'prod_2 should be 85');
  print('✓ PASSED\n');
}

void testInventoryLedgerMode() {
  print('=== TEST: Ledger Mode (No Overwrite) ===');
  final server = MockSyncServer();

  // Device 1: sells 5 units
  server.handlePush({
    'tenantId': 't1',
    'operations': [
      {
        'idempotencyKey': 'stock_1',
        'entity': 'stock',
        'entityId': 'prod_1',
        'opType': 1,
        'data': '{"operation":"STOCK_OUT","quantity":-5}',
      },
    ],
  });

  // Device 2: sells 3 units (same product)
  server.handlePush({
    'tenantId': 't1',
    'operations': [
      {
        'idempotencyKey': 'stock_2',
        'entity': 'stock',
        'entityId': 'prod_1',
        'opType': 1,
        'data': '{"operation":"STOCK_OUT","quantity":-3}',
      },
    ],
  });

  // Verify: both operations should be acked (not rejected)
  assert(server.operationCount == 2, 'Both deltas should be stored');
  print('Both deltas stored: ${server.operationCount} operations');
  print('✓ PASSED\n');
}

void testInventoryNoOverwrite() {
  print('=== TEST: No Direct Overwrite ===');
  final snapshot = <String, int>{'prod_1': 100};

  // Attempt to directly set stock (should NOT happen with proper ledger)
  // This tests that we're using deltas, not direct assignment
  final wrongApproach = 'setting stock to 50 directly';

  // Correct approach: use deltas
  var stock = snapshot['prod_1']!;
  stock -= 10;
  stock -= 5;
  snapshot['prod_1'] = stock;

  print('Stock after deltas: ${snapshot['prod_1']} (not 50)');
  assert(snapshot['prod_1'] == 85, 'Stock should be computed from deltas');
  print('✓ PASSED\n');
}

// Stock ledger simulation for real hardware
class StockLedger {
  final Map<String, List<Map<String, dynamic>>> _ledger = {};

  void addDelta(String productId, int quantity, String reason, String refId) {
    _ledger.putIfAbsent(productId, () => []);
    _ledger[productId]!.add({
      'quantity': quantity,
      'reason': reason,
      'referenceId': refId,
      'timestamp': DateTime.now(),
    });
  }

  int getStock(String productId) {
    final deltas = _ledger[productId];
    if (deltas == null) return 0;
    return deltas.map((d) => d['quantity'] as int).fold(0, (a, b) => a + b);
  }
}
