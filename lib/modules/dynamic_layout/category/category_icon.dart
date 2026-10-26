import 'package:flutter/material.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:inspireui/extensions/color_extension.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../config/category_config.dart';
import '../helper/helper.dart';
import 'category_icon_gradient_item.dart';
import 'category_icon_item.dart';

const _paddingList = 24.0;
const _maxWidth = 64.0;

class CategoryIcons extends StatelessWidget {
  final CategoryConfig config;
  final int crossAxisCount;
  final Function onShowProductList;
  final Map<String?, String?> listCategoryName;

  const CategoryIcons({
    required this.onShowProductList,
    required this.listCategoryName,
    required this.config,
    this.crossAxisCount = 5,
    super.key,
  });

  double get separateWidth => config.separateWidth;

  @override
  Widget build(BuildContext context) {
    final listItemData = config.items;
    var numberItemOnScreen = config.columns ?? crossAxisCount;

    numberItemOnScreen = getValueForScreenType(
      context: context,
      mobile: numberItemOnScreen,
      tablet: numberItemOnScreen + 3,
      desktop: numberItemOnScreen + 8,
    );

    var row = (listItemData.length.toDouble() / numberItemOnScreen).ceil();
    final size = config.commonItemConfig.size ?? 1.0;
    final widthItem = (MediaQuery.of(context).size.width -
        _paddingList -
        (separateWidth * (numberItemOnScreen))) /
        numberItemOnScreen *
        size;
    var items = <Widget>[];

    for (var item in config.items) {
      if (config.gradientDesign) {
        items.add(
          CategoryIconGradientItem(
            onTap: (name) => onShowProductList(item..name = name),
            iconSize: widthItem > _maxWidth ? _maxWidth : widthItem,
            itemConfig: item,
            commonConfig: config.commonItemConfig,
            isHorizontal: config.horizontalItem,
            isWrap: config.wrap,
          ),
        );
      } else {
        items.add(
          CategoryIconItem(
            onTap: (name) => onShowProductList(item..name = name),
            iconSize: widthItem > _maxWidth ? _maxWidth : widthItem,
            itemConfig: item,
            commonConfig: config.commonItemConfig,
            isHorizontal: config.horizontalItem,
            isWrap: config.wrap,
          ),
        );
      }
    }

    // Always use Grid layout
    return BackgroundColorWidget(
      margin: EdgeInsets.only(
        left: config.marginLeft,
        right: config.marginRight,
        top: config.marginTop,
        bottom: config.marginBottom,
      ),
      enable: config.enableBackground ?? true,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.0),
        boxShadow: [
          if (config.shadow != null)
            BoxShadow(
              color: Colors.black.withValueOpacity(0.1),
              blurRadius: Helper.formatDouble(config.shadow ?? 15.0)!,
              offset: Offset(0, Helper.formatDouble(config.shadow ?? 10.0)!),
            )
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: numberItemOnScreen,
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 8.0,
          childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return items[index];
        },
      ),
    );
  }
}