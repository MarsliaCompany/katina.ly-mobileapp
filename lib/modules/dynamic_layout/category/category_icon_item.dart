import 'package:flutter/material.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:inspireui/extensions/color_extension.dart';
import 'package:inspireui/utils/colors.dart';
import 'package:provider/provider.dart';

import '../../../models/category/category_model.dart';
import '../index.dart';
import 'common_item_extension.dart';

typedef CategoryName = String;

class CategoryIconItem extends StatelessWidget {
  final double? iconSize;
  final Function(CategoryName?)? onTap;
  final CategoryItemConfig? itemConfig;
  final CommonItemConfig commonConfig;
  final bool? isSelected;
  final bool isHorizontal;
  final bool isWrap;

  const CategoryIconItem({
    this.iconSize,
    this.onTap,
    this.itemConfig,
    this.isSelected,
    required this.commonConfig,
    this.isHorizontal = false,
    this.isWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final categoryList = Provider.of<CategoryModel>(context).categoryList;

    final id = itemConfig?.category;
    final categoryName = commonConfig.getCategoryItemName(itemConfig) ??
        (categoryList[id] != null ? categoryList[id]!.name : '');
    final image = itemConfig?.image ?? categoryList[id]?.image;
    final firstColor = (itemConfig?.colors?.isNotEmpty ?? false)
        ? itemConfig?.colors?.first
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () => onTap?.call(categoryName),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8C373),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final cardSize = cardConstraints.maxWidth;
                        return Center(
                          child: image != null
                              ? _image(image, firstColor, cardSize)
                              : Icon(
                            Icons.category,
                            size: cardSize * 0.6,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                categoryName ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _image(String image, HexColor? firstColor, double maxWidth) {
    return FluxImage(
      imageUrl: image,
      color: (itemConfig?.originalColor ?? true) || commonConfig.originalColor
          ? null
          : firstColor,
      width: maxWidth * 0.8,
      height: maxWidth * 0.8,
      fit: BoxFit.contain,
    );
  }
}