This is extremely clear. Let me now construct the comprehensive plan based on all your answers.
---
📋 Implementation Plan
Phase 1: Server Contract Design (FIRST) ⚠️
This MUST be defined first because Flutter depends on it.
Single Sync Endpoint (Two Operations):
POST /api/sync
PUSH Request:
{
  "tenant_id": 1,
  "cursor": 1200,
  "operations": [
    {
      "id": "uuid-outbox-1",
      "op": "INSERT",           // or UPDATE, DELETE
      "table": "invoices",
      "record_key": "uuid-inv-123",
      "payload": {
        "old": null,           // null for INSERT
        "new": { ... }
      },
      "version": 1,            // client-assigned, server will override
      "idempotency_key": "uuid-outbox-1",
      "client_created_at": "2026-04-11T10:00:00Z"
    }
  ]
}
PUSH Response:
{
  "cursor": 1240,
  "acked": ["uuid-outbox-1", "uuid-outbox-2"],
  "rejected": [
    {
      "id": "uuid-outbox-3",
      "reason": "VERSION_CONFLICT",
      "server_version": 1241,
      "current_state": { ... }
    }
  ]
}
PULL Request:
{
  "tenant_id": 1,
  "cursor": 1200
}
PULL Response:
{
  "cursor": 1240,
  "operations": [
    {
      "id": 5001,
      "op": "UPDATE",
      "table": "products",
      "record_key": "uuid-prod-456",
      "payload": {
        "old": { "stockQuantity": 10 },
        "new": { "stockQuantity": 5 }
      },
      "version": 1241,
      "server_created_at": "2026-04-11T10:05:00Z"
    }
  ]
}
Questions on Contract:
1. Max batch size? Recommend 500 operations per request (balance between network reliability and completeness)
2. Compression? Recommend gzip for payloads > 10KB
3. Inventory deltas: Should stock operations be sent separately or in same stream? (I recommend separate stock_outbox for inventory to allow high-frequency updates without blocking main sync)
---
Phase 2: PostgreSQL Schema
-- CORE: Operations log (source of truth)
CREATE TABLE operations_log (
  id BIGSERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  table_name VARCHAR(50) NOT NULL,
  record_key UUID NOT NULL,
  payload JSONB NOT NULL,          -- {old: {...}, new: {...}}
  version BIGINT NOT NULL,         -- monotonic per tenant
  idempotency_key UUID,             -- for deduplication
  client_created_at TIMESTAMPTZ,   -- client clock (untrusted)
  server_created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, idempotency_key)
);
CREATE INDEX idx_ops_tenant_version ON operations_log(tenant_id, version);
-- Cursors: tracks sync position per tenant
CREATE TABLE sync_cursors (
  tenant_id INTEGER PRIMARY KEY,
  last_version_synced BIGINT NOT NULL DEFAULT 0,
  last_ack_version BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- Inventory: Delta-based ledger (not LWW!)
CREATE TABLE stock_ledger (
  id BIGSERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  product_id UUID NOT NULL,
  operation VARCHAR(10) NOT NULL,  -- STOCK_IN, STOCK_OUT, ADJUST
  quantity DECIMAL(10,3) NOT NULL,   -- signed: +ve for in, -ve for out
  reference_type VARCHAR(20),        -- invoice, purchase, adjustment
  reference_key UUID,
  version BIGINT NOT NULL,           -- links to operations_log.version
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_stock_tenant_product ON stock_ledger(tenant_id, product_id, id);
-- Snapshot: Current stock state (materialized)
CREATE TABLE stock_snapshot (
  tenant_id INTEGER NOT NULL,
  product_id UUID NOT NULL,
  quantity DECIMAL(10,3) NOT NULL DEFAULT 0,
  version BIGINT NOT NULL,           -- last version that modified this
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (tenant_id, product_id)
);
---
Phase 3: Flutter (Drift) Changes
New Tables Required:
// sync_outbox - pending operations (replaces syncStatus flag)
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();  // UUID
  TextColumn get operation => text()();  // INSERT, UPDATE, DELETE
  TextColumn get tableName => text()();
  TextColumn get recordKey => text()();  // UUID of entity
  JsonColumn get payload => json()();  // {old: {...}, new: {...}}
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get clientCreatedAt => dateTime()();
  IntColumn get status => integer().withDefault(const Constant(0))();  // 0=pending, 1=acked, 2=rejected
  TextColumn get error => text().nullable()();
}
// sync_inbox - applied remote operations
class SyncInbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverOperationId => integer()();  // from operations_log.id
  TextColumn get operation => text()();
  TextColumn get tableName => text()();
  TextColumn get recordKey => text()();
  JsonColumn get payload => json()();
  IntColumn get version => integer()();
  DateTimeColumn get appliedAt => dateTime()();
}
Sync Meta Improvements:
// sync_state - replaces simple lastSyncTime
class SyncState extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tenantId => integer()();
  BigIntColumn get localVersion => integer().withDefault(const Constant(0))();
  BigIntColumn get remoteVersion => integer().withDefault(const Constant(0))();
  BigIntColumn get lastAckedVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  BoolColumn get isSyncing => boolean().withDefault(const Constant(false))();
}
Sync Service Refactor:
1. Remove: per-table syncStatus queries
2. Add: batch read from sync_outbox
3. Add: single request builder
4. Add: retry with exponential backoff
---
Phase 4: End-to-End Flows
Scenario	Flow
Cold Start	Pull all operations since cursor=0
Weeks Offline	Push outbox (may be 1000s ops), server ACKs in batches, pull new since old cursor, apply, repeat until caught up
Conflict	Server rejects with VERSION_CONFLICT, client receives current state, next pull pushes server version
Retry Storm	Exponential backoff (1s, 2s, 4s, 8s... max 60s), max 5 retries
Partial Failure	Only clear ACKed ops from outbox, keep rejected until resolved
---
Confirmation Before I Proceed
Please confirm:
1. Contract format OK? Any changes to the JSON structure above?
2. Batch size - 500 operations per request reasonable?
3. Inventory - Should I create separate stock_outbox + stock_ledger? (Recommended for high-frequency)
4. Ready to start implementation? Or do you want to review this plan more?
Once confirmed, I'll begin implementing Phase 1 (Server Contract - but since backend is separate, I'll document it as a spec) or whatever you prioritize.