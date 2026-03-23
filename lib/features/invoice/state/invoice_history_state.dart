import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:ezo/core/di/service_locator.dart';

class SalesHistoryState {
  final List<TypedResult> items;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String query;
  final int limit;
  final int totalItems;

  const SalesHistoryState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 0,
    this.query = '',
    this.limit = 20,
    this.totalItems = 0,
  });

  SalesHistoryState copyWith({
    List<TypedResult>? items,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? query,
    int? limit,
    int? totalItems,
  }) {
    return SalesHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      query: query ?? this.query,
      limit: limit ?? this.limit,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}

class SalesHistoryNotifier extends StateNotifier<SalesHistoryState> {
  SalesHistoryNotifier() : super(const SalesHistoryState()) {
    loadInitial();
    _listenToChanges();
  }

  final _db = ServiceLocator.instance.database;
  StreamSubscription? _subscription;

  int get _tenantId => ServiceLocator.instance.tenantService.tenantId;

  void _listenToChanges() {
    _subscription?.cancel();
    // Use customSelect to watch relevant tables for reactivity
    final trigger = _db.selectOnly(_db.invoices)
      ..addColumns([_db.invoices.id])
      ..limit(1);

    _subscription = trigger.watch().listen((_) {
      // Silent refresh
      _loadData(fetchCount: true);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, page: 0, items: [], totalItems: 0);
    await _loadData(fetchCount: true);
  }

  Future<void> setPage(int page) async {
    if (state.isLoading || state.page == page) return;
    state = state.copyWith(isLoading: true, page: page);
    await _loadData(fetchCount: false);
  }

  Future<void> setQuery(String query) async {
    if (state.query == query) return;
    state = state.copyWith(query: query, page: 0, items: [], isLoading: true);
    await _loadData(fetchCount: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadData(fetchCount: true);
  }

  Future<void> _loadData({bool fetchCount = false}) async {
    try {
      final offset = state.page * state.limit;

      // ignore: avoid_print
      print(
        'SalesHistoryNotifier: _tenantId=$_tenantId, page=${state.page}, limit=${state.limit}',
      );

      // Fetch items
      final newItems = await _db.getInvoiceItemsDetailedPaginated(
        limit: state.limit,
        offset: offset,
        queryStr: state.query.isEmpty ? null : state.query,
        tenantId: _tenantId,
      );

      // ignore: avoid_print
      print('SalesHistoryNotifier: got ${newItems.length} items');

      int totalItems = state.totalItems;
      if (fetchCount) {
        totalItems = await _db.getInvoiceItemsCount(
          queryStr: state.query.isEmpty ? null : state.query,
          tenantId: _tenantId,
        );
      }

      // Calculate hasMore based on total count
      // page is 0-indexed. (page + 1) * limit < totalItems
      final hasMore = (state.page + 1) * state.limit < totalItems;

      state = state.copyWith(
        items: newItems, // Replace items for table view
        isLoading: false,
        hasMore: hasMore,
        totalItems: totalItems,
      );
    } catch (e) {
      // ignore: avoid_print
      print('SalesHistoryNotifier _loadData error: $e');
      state = state.copyWith(isLoading: false, hasMore: false);
    }
  }
}

final salesHistoryProvider =
    StateNotifierProvider<SalesHistoryNotifier, SalesHistoryState>((ref) {
      return SalesHistoryNotifier();
    });
