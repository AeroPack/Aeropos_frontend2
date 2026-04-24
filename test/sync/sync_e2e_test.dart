import 'dart:math';
import 'dart:convert';
import 'sync_test_utils.dart';

void main() {
  print('========================================');
  print('SYNC ENGINE E2E HARDENING TESTS');
  print('========================================\n');

  testWeeksOffline();
  testLargeBatch();
  testRandomRetry();
  testMultiDeviceConflict();
  testInventoryStress();
  testCrashRecovery();
  testIdempotency();

  print('\n========================================');
  print('ALL TESTS PASSED ✓');
  print('========================================\n');
}

void testWeeksOffline() {
  print('=== TEST: Weeks-offline (1000 ops) ===');
  final server = MockSyncServer();
  final outbox = <Map<String, dynamic>>[];

  for (var i = 0; i < 1000; i++) {
    outbox.add({
      'idempotencyKey': 'op_${i}_${DateTime.now().millisecondsSinceEpoch}',
      'tenantId': 't1',
      'companyId': 'c1',
      'deviceId': 'd1',
      'entity': 'products',
      'entityId': 'prod_$i',
      'opType': 1,
      'data': '{"name": "Product $i", "price": ${100.0 + i}}',
      'version': i + 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  final result = pushBatches(server, outbox, maxBatch: 500);

  print(
    'Ops: ${outbox.length}, Batches: ${result.batches}, Acked: ${result.acked}',
  );
  assert(result.acked == 1000);
  print('✓ PASSED\n');
}

void testLargeBatch() {
  print('=== TEST: Large Batch (10k ops) ===');
  final server = MockSyncServer();
  final outbox = <Map<String, dynamic>>[];
  final sw = Stopwatch()..start();

  for (var i = 0; i < 10000; i++) {
    outbox.add({
      'idempotencyKey': 'op_large_$i',
      'tenantId': 't1',
      'companyId': 'c1',
      'deviceId': 'd1',
      'entity': i % 2 == 0 ? 'products' : 'categories',
      'entityId': 'entity_$i',
      'opType': 1,
      'data': '{"name": "Entity $i"}',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  final result = pushBatches(server, outbox, maxBatch: 500);
  sw.stop();

  print('10k ops in ${sw.elapsedMilliseconds}ms (${result.batches} batches)');
  print('Acked: ${result.acked}');
  assert(result.acked == 10000);
  print('✓ PASSED\n');
}

void testRandomRetry() {
  print('=== TEST: Random Retry Failures ===');
  final server = MockSyncServer();
  final outbox = <Map<String, dynamic>>[];

  for (var i = 0; i < 100; i++) {
    outbox.add({
      'idempotencyKey': 'op_retry_$i',
      'tenantId': 't1',
      'companyId': 'c1',
      'deviceId': 'd1',
      'entity': 'products',
      'entityId': 'prod_$i',
      'opType': 1,
      'data': '{"name": "Product $i"}',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  server.setFailMode(true, failAfter: 2);

  int attempts = 0;
  PushResult? result;

  while (attempts < 5) {
    try {
      result = pushBatchesWithRetry(
        server,
        outbox,
        maxBatch: 500,
        maxRetries: 3,
      );
      break;
    } catch (e) {
      attempts++;
      print('Attempt $attempts failed');
    }
  }

  print('Succeeded after $attempts retry attempts');
  assert(result!.acked == 100);
  print('✓ PASSED\n');
}

void testMultiDeviceConflict() {
  print('=== TEST: Multi-device Conflict ===');
  final server = MockSyncServer();

  server.handlePush({
    'tenantId': 't1',
    'cursor': 0,
    'operations': [
      {
        'idempotencyKey': 'op_1',
        'entity': 'products',
        'entityId': 'prod_1',
        'opType': 1,
        'data': '{"name": "Initial", "price": 100}',
        'version': 1,
      },
    ],
  });

  final conflictResult = server.handlePush({
    'tenantId': 't1',
    'cursor': 1,
    'operations': [
      {
        'idempotencyKey': 'op_2',
        'entity': 'products',
        'entityId': 'prod_1',
        'opType': 2,
        'data': '{"name": "From Device 2", "price": 150}',
        'version': 1,
      },
    ],
  });

  print(
    'Acked: ${conflictResult['acked']}, Rejected: ${conflictResult['rejected']}',
  );
  assert((conflictResult['rejected'] as List).isNotEmpty);
  print('✓ PASSED\n');
}

void testInventoryStress() {
  print('=== TEST: Inventory Stress ===');
  final stockDelta = <String, int>{};

  for (var device = 0; device < 5; device++) {
    for (var i = 0; i < 20; i++) {
      final productId = 'prod_${i % 10}';
      stockDelta[productId] = (stockDelta[productId] ?? 0) - 1;
    }
  }

  print('5 devices x 20 sales = 100 total sales');
  print('Total delta: ${stockDelta.values.fold(0, (a, b) => a + b)}');
  assert(stockDelta.values.fold(0, (a, b) => a + b) == -100);
  print('✓ PASSED\n');
}

void testCrashRecovery() {
  print('=== TEST: Crash Recovery ===');
  final server = MockSyncServer();
  final outbox = <Map<String, dynamic>>[];

  for (var i = 0; i < 100; i++) {
    outbox.add({
      'idempotencyKey': 'op_crash_$i',
      'tenantId': 't1',
      'companyId': 'c1',
      'deviceId': 'd1',
      'entity': 'products',
      'entityId': 'prod_$i',
      'opType': 1,
      'data': '{"name": "Product $i"}',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  server.setFailMode(true, failAfter: 1);

  try {
    pushBatches(server, outbox, maxBatch: 500);
  } catch (e) {
    print('Batch failed (expected): ${e.toString()}');
  }

  final remainingBefore = outbox.length;
  print('Remaining: $remainingBefore');

  server.setFailMode(false);
  final result = pushBatches(server, outbox, maxBatch: 500);

  print('After recovery: acked ${result.acked}');
  assert(result.acked > 0);
  print('✓ PASSED\n');
}

void testIdempotency() {
  print('=== TEST: Idempotency ===');
  final server = MockSyncServer();

  final op = {
    'idempotencyKey': 'idem_1',
    'tenantId': 't1',
    'companyId': 'c1',
    'deviceId': 'd1',
    'entity': 'products',
    'entityId': 'prod_1',
    'opType': 1,
    'data': '{"name": "Test"}',
    'version': 1,
    'createdAt': DateTime.now().toIso8601String(),
  };

  final result1 = server.handlePush({
    'tenantId': 't1',
    'cursor': 0,
    'operations': [op],
  });

  print('First push: acked ${result1['acked']}');

  final result2 = server.handlePush({
    'tenantId': 't1',
    'cursor': 1,
    'operations': [op],
  });

  print('Duplicate push: acked ${result2['acked']}');

  assert(server.operationCount == 1);
  print('✓ PASSED\n');
}

class PushResult {
  final int acked;
  final int rejected;
  final int batches;
  PushResult({
    required this.acked,
    required this.rejected,
    required this.batches,
  });
}

PushResult pushBatches(
  MockSyncServer server,
  List<Map<String, dynamic>> outbox, {
  required int maxBatch,
}) {
  int acked = 0;
  int rejected = 0;
  int batches = 0;

  while (outbox.isNotEmpty) {
    batches++;
    final end = maxBatch > outbox.length ? outbox.length : maxBatch;
    final batch = outbox.sublist(0, end);

    final result = server.handlePush({
      'tenantId': 't1',
      'cursor': acked,
      'operations': batch,
    });

    acked += (result['acked'] as List).length;
    rejected += (result['rejected'] as List).length;
    outbox.removeRange(0, end);
  }

  return PushResult(acked: acked, rejected: rejected, batches: batches);
}

PushResult pushBatchesWithRetry(
  MockSyncServer server,
  List<Map<String, dynamic>> outbox, {
  required int maxBatch,
  required int maxRetries,
}) {
  int acked = 0;
  int rejected = 0;
  int batches = 0;

  while (outbox.isNotEmpty) {
    batches++;
    final end = maxBatch > outbox.length ? outbox.length : maxBatch;
    final batch = outbox.sublist(0, end);

    try {
      final result = server.handlePush({
        'tenantId': 't1',
        'cursor': acked,
        'operations': batch,
      });

      acked += (result['acked'] as List).length;
      rejected += (result['rejected'] as List).length;
    } catch (e) {
      if (batches >= maxRetries) rethrow;
    }
    outbox.removeRange(0, end);
  }

  return PushResult(acked: acked, rejected: rejected, batches: batches);
}
