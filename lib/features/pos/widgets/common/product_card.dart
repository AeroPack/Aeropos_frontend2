import 'package:flutter/material.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/core/widgets/product_image.dart';

enum PosCardSize { small, medium, large }

/// Reusable product card for POS layouts.
/// [size] controls the visual density.
class PosProductCard extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onTap;
  final PosCardSize size;
  final bool showImage;
  final bool showPrice;
  final bool showSku;

  const PosProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.size = PosCardSize.medium,
    this.showImage = true,
    this.showPrice = true,
    this.showSku = false,
  });

  double get _imageSize {
    switch (size) {
      case PosCardSize.small:
        return 60;
      case PosCardSize.medium:
        return 100;
      case PosCardSize.large:
        return 150;
    }
  }

  double get _titleSize {
    switch (size) {
      case PosCardSize.small:
        return 11;
      case PosCardSize.medium:
        return 13;
      case PosCardSize.large:
        return 16;
    }
  }

  double get _priceSize {
    switch (size) {
      case PosCardSize.small:
        return 12;
      case PosCardSize.medium:
        return 14;
      case PosCardSize.large:
        return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showImage)
              Expanded(
                child: Center(
                  child: ProductImage(product: product, size: _imageSize),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: size == PosCardSize.small ? 4 : 8,
                vertical: size == PosCardSize.small ? 2 : 4,
              ),
              child: Text(
                product.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _titleSize,
                ),
                maxLines: size == PosCardSize.small ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showSku && product.sku != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'SKU: ${product.sku}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (showPrice)
              Padding(
                padding: EdgeInsets.only(
                  left: size == PosCardSize.small ? 4 : 8,
                  bottom: size == PosCardSize.small ? 2 : 4,
                ),
                child: Text(
                  'Rs ${product.price.toInt()}',
                  style: TextStyle(
                    color: const Color(0xFF00A78E),
                    fontWeight: FontWeight.bold,
                    fontSize: _priceSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
