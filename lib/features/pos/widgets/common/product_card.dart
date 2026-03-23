import 'package:flutter/material.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/core/widgets/product_image.dart';
import 'package:ezo/core/theme/app_theme.dart';

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
        return 15;
    }
  }

  double get _priceSize {
    switch (size) {
      case PosCardSize.small:
        return 12;
      case PosCardSize.medium:
        return 14;
      case PosCardSize.large:
        return 16;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: AppColors.grey200, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showImage)
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: ProductImage(product: product, size: _imageSize),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: _titleSize,
                      color: AppColors.text,
                    ),
                    maxLines: size == PosCardSize.small ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showSku && product.sku != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppColors.grey400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (showPrice)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Rs ${product.price.toInt()}',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: _priceSize,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
