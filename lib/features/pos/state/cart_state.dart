import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/core/di/service_locator.dart';
import 'package:ezo/features/pos/state/pos_category_state.dart';
import 'package:ezo/core/models/product_unit.dart';
import 'package:drift/drift.dart' show OrderingTerm;

// 1. Models
class CartItem {
  final ProductEntity product;
  final double quantity;
  final ProductUnit? selectedUnit;
  final double manualDiscount;
  final bool isPercentDiscount;
  final List<String>? modifiers;
  final String? course;

  const CartItem({
    required this.product,
    this.quantity = 1.0,
    this.selectedUnit,
    this.manualDiscount = 0.0,
    this.isPercentDiscount = false,
    this.modifiers,
    this.course,
  });

  double get unitPrice => quantity > 0 ? calculatedPrice / quantity : 0;

  double get calculatedPrice {
    if (selectedUnit == null) {
      return product.price * quantity;
    }

    final qtyInBase = quantity * selectedUnit!.conversionFactor;

    // Case 1: Selected unit has its own selling_price
    if (selectedUnit!.sellingPrice != null) {
      return selectedUnit!.sellingPrice! * quantity;
    }

    // Case 2: Derive from another unit with selling_price (highest conversion_factor)
    // This requires productUnits from cache - need to check via CartNotifier
    // For now, fall back to product price
    if (product.price > 0) {
      final rawPrice = qtyInBase * product.price;
      return rawPrice.roundToDouble();
    }

    return product.price * quantity;
  }

  double get taxRate {
    final rateStr = product.gstRate?.replaceAll('%', '') ?? '0';
    return double.tryParse(rateStr) ?? 0.0;
  }

  double get tax {
    final rate = taxRate;
    final effectivePrice = selectedUnit != null
        ? calculatedPrice
        : (product.price * quantity);
    double discountAmount = manualDiscount;
    if (isPercentDiscount) {
      discountAmount = effectivePrice * (manualDiscount / 100);
    }
    final totalBeforeTax = effectivePrice - discountAmount;

    if (product.gstType?.toLowerCase() == 'exclusive' ||
        product.gstType?.toLowerCase() == 'excluding') {
      return (totalBeforeTax * rate) / 100;
    } else {
      return (totalBeforeTax * rate) / (100 + rate);
    }
  }

  double get subtotal {
    final effectivePrice = selectedUnit != null
        ? calculatedPrice
        : (product.price * quantity);
    double discountAmount = manualDiscount;
    if (isPercentDiscount) {
      discountAmount = effectivePrice * (manualDiscount / 100);
    }
    final totalBeforeTax = effectivePrice - discountAmount;
    if (product.gstType?.toLowerCase() == 'exclusive' ||
        product.gstType?.toLowerCase() == 'excluding') {
      return totalBeforeTax;
    } else {
      return totalBeforeTax - tax;
    }
  }

  double get total => subtotal + tax;

  CartItem copyWith({
    ProductEntity? product,
    double? quantity,
    ProductUnit? selectedUnit,
    double? basePrice,
    double? manualDiscount,
    bool? isPercentDiscount,
    List<String>? modifiers,
    String? course,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedUnit: selectedUnit ?? this.selectedUnit,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      isPercentDiscount: isPercentDiscount ?? this.isPercentDiscount,
      modifiers: modifiers ?? this.modifiers,
      course: course ?? this.course,
    );
  }
}

class CartState {
  final List<CartItem> items;
  final CustomerEntity? selectedCustomer;
  final double overallDiscount; // The value (either Rs or %)
  final bool isOverallPercent;

  const CartState({
    this.items = const [],
    this.selectedCustomer,
    this.overallDiscount = 0.0,
    this.isOverallPercent = false,
  });

  double get itemDiscounts => items.fold(0.0, (sum, item) {
    if (item.isPercentDiscount) {
      return sum +
          (item.product.price * item.quantity * (item.manualDiscount / 100));
    }
    return sum + item.manualDiscount;
  });

  double get overallDiscountAmount {
    final itemTotal = items.fold(0.0, (sum, item) => (sum) + (item.total));
    if (isOverallPercent) {
      return itemTotal * (overallDiscount / 100);
    }
    return overallDiscount;
  }

  double get totalDiscount => itemDiscounts + overallDiscountAmount;

  double get subtotal =>
      items.fold(0.0, (sum, item) => (sum) + (item.subtotal));
  double get taxAmount => items.fold(0.0, (sum, item) => (sum) + (item.tax));
  double get total {
    final itemTotal = items.fold(0.0, (sum, item) => (sum) + (item.total));
    return itemTotal - overallDiscountAmount;
  }

  CartState copyWith({
    List<CartItem>? items,
    CustomerEntity? selectedCustomer,
    double? overallDiscount,
    bool? isOverallPercent,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      overallDiscount: overallDiscount ?? this.overallDiscount,
      isOverallPercent: isOverallPercent ?? this.isOverallPercent,
    );
  }
}

// 2. Notifier
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  final Map<int, List<ProductUnitEntity>> _productUnitsCache = {};

  Future<void> loadProductUnits(int productId) async {
    if (_productUnitsCache.containsKey(productId)) return;

    final db = ServiceLocator.instance.database;
    final units =
        await (db.select(db.productUnits)
              ..where((t) => t.productId.equals(productId))
              ..orderBy([(t) => OrderingTerm.desc(t.conversionFactor)]))
            .get();

    _productUnitsCache[productId] = units;
  }

  void setProductUnitsCache(int productId, List<ProductUnitEntity> units) {
    _productUnitsCache[productId] = units;
  }

  List<ProductUnitEntity>? getProductUnits(int productId) {
    return _productUnitsCache[productId];
  }

  double calculatePrice({
    required ProductEntity product,
    required double quantity,
    required ProductUnit? selectedUnit,
  }) {
    if (selectedUnit == null) {
      return product.price * quantity;
    }

    final qtyInBase = quantity * selectedUnit.conversionFactor;

    // Case 1: Selected unit has its own selling_price
    if (selectedUnit.sellingPrice != null) {
      return selectedUnit.sellingPrice! * quantity;
    }

    // Case 2: Derive from another unit with selling_price (highest conversion_factor)
    final productUnits = _productUnitsCache[product.id];
    if (productUnits != null) {
      final unitsWithPrice =
          productUnits.where((u) => u.sellingPrice != null).toList()
            ..sort((a, b) => b.conversionFactor.compareTo(a.conversionFactor));

      if (unitsWithPrice.isNotEmpty &&
          unitsWithPrice.first.conversionFactor > 0) {
        final basePrice =
            unitsWithPrice.first.sellingPrice! /
            unitsWithPrice.first.conversionFactor;
        final rawPrice = qtyInBase * basePrice;
        return rawPrice.roundToDouble();
      }
    }

    // Case 3: Fallback to product price
    if (product.price > 0) {
      final rawPrice = qtyInBase * product.price;
      return rawPrice.roundToDouble();
    }

    return product.price * quantity;
  }

  bool _compareModifiers(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    final sortedA = List<String>.from(a)..sort();
    final sortedB = List<String>.from(b)..sort();
    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  void addProduct(
    ProductEntity product, {
    double quantity = 1.0,
    ProductUnit? selectedUnit,
    List<String>? modifiers,
    String? course,
  }) {
    final existingIndex = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          _compareModifiers(i.modifiers, modifiers) &&
          i.course == course &&
          i.selectedUnit?.id == selectedUnit?.id,
    );

    if (existingIndex >= 0) {
      // Increment
      final newItems = List<CartItem>.from(state.items);
      final newItem = newItems[existingIndex].copyWith(
        quantity: newItems[existingIndex].quantity + quantity,
      );
      newItems[existingIndex] = newItem;
      state = state.copyWith(items: newItems);
    } else {
      double validDiscount = product.discount;
      if (product.isPercentDiscount) {
        if (validDiscount > 100) validDiscount = 100;
      } else {
        if (validDiscount > product.price) validDiscount = product.price;
      }
      if (validDiscount < 0) validDiscount = 0;

      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            product: product,
            quantity: quantity,
            selectedUnit: selectedUnit,
            manualDiscount: validDiscount,
            isPercentDiscount: product.isPercentDiscount,
            modifiers: modifiers,
            course: course,
          ),
        ],
      );
    }
  }

  void removeProduct(
    ProductEntity product, {
    ProductUnit? selectedUnit,
    List<String>? modifiers,
    String? course,
  }) {
    state = state.copyWith(
      items: state.items
          .where(
            (i) =>
                i.product.id != product.id ||
                i.selectedUnit?.id != selectedUnit?.id ||
                !_compareModifiers(i.modifiers, modifiers) ||
                i.course != course,
          )
          .toList(),
    );
  }

  void updateQuantity(
    ProductEntity product,
    double quantity, {
    ProductUnit? selectedUnit,
    List<String>? modifiers,
    String? course,
  }) {
    if (quantity <= 0) {
      removeProduct(
        product,
        selectedUnit: selectedUnit,
        modifiers: modifiers,
        course: course,
      );
      return;
    }

    final index = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          _compareModifiers(i.modifiers, modifiers) &&
          i.course == course &&
          (selectedUnit != null ? i.selectedUnit?.id == selectedUnit.id : true),
    );
    if (index >= 0) {
      final newItems = List<CartItem>.from(state.items);
      newItems[index] = newItems[index].copyWith(
        quantity: quantity,
        selectedUnit: selectedUnit ?? newItems[index].selectedUnit,
      );
      state = state.copyWith(items: newItems);
    }
  }

  void updateItemDiscount(
    ProductEntity product,
    double discount,
    bool isPercent, {
    ProductUnit? selectedUnit,
    List<String>? modifiers,
    String? course,
  }) {
    final index = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          i.selectedUnit?.id == selectedUnit?.id &&
          _compareModifiers(i.modifiers, modifiers) &&
          i.course == course,
    );
    if (index >= 0) {
      double validDiscount = discount;
      final itemSubtotal =
          state.items[index].product.price * state.items[index].quantity;

      if (isPercent) {
        if (validDiscount > 100) validDiscount = 100;
      } else {
        if (validDiscount > itemSubtotal) validDiscount = itemSubtotal;
      }

      if (validDiscount < 0) validDiscount = 0;

      final newItems = List<CartItem>.from(state.items);
      newItems[index] = newItems[index].copyWith(
        manualDiscount: validDiscount,
        isPercentDiscount: isPercent,
      );
      state = state.copyWith(items: newItems);
    }
  }

  void setOverallDiscount(double discount, bool isPercent) {
    double validDiscount = discount;
    final currentTotal = state.items.fold(0.0, (sum, item) => sum + item.total);

    if (isPercent) {
      if (validDiscount > 100) validDiscount = 100;
    } else {
      if (validDiscount > currentTotal) validDiscount = currentTotal;
    }

    if (validDiscount < 0) validDiscount = 0;

    state = state.copyWith(
      overallDiscount: validDiscount,
      isOverallPercent: isPercent,
    );
  }

  void clearCart() {
    state = const CartState();
  }

  void setCustomer(CustomerEntity? customer) {
    state = state.copyWith(selectedCustomer: customer);
  }
}

// 3. Providers
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// A provider to search/filter products for the POS Grid
final productSearchProvider = StateProvider<String>((ref) => '');

final posProductListProvider = StreamProvider<List<ProductEntity>>((ref) {
  final query = ref.watch(productSearchProvider).toLowerCase();
  final selectedCategoryId = ref.watch(selectedCategoryProvider);
  final database = ServiceLocator.instance.database;

  return database.select(database.products).watch().map((products) {
    return products.where((p) {
      final matchesQuery =
          query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          (p.sku?.toLowerCase().contains(query) ?? false);

      final matchesCategory =
          selectedCategoryId == null || p.categoryId == selectedCategoryId;

      return matchesQuery && matchesCategory;
    }).toList();
  });
});

final customerSearchProvider = StateProvider<String>((ref) => '');

final posCustomerListProvider = StreamProvider<List<CustomerEntity>>((ref) {
  final query = ref.watch(customerSearchProvider).toLowerCase();
  final database = ServiceLocator.instance.database;

  // Only customers
  return database.select(database.customers).watch().map((customers) {
    return customers
        .where(
          (u) =>
              (query.isEmpty ||
              u.name.toLowerCase().contains(query) ||
              (u.phone?.toLowerCase().contains(query) ?? false)),
        )
        .toList();
  });
});
