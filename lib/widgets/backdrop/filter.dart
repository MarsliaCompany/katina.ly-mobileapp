import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/filters/new_attribute_system.dart';
import '../../widgets/new_attribute_filter_widget.dart';

class FilterWidget extends StatelessWidget {
  final bool showAttribute;
  final bool showCategory;
  final bool showBrand;
  final bool showTag;
  final bool showPriceSlider;
  final Function(Map<String, dynamic>)? onFilter;
  
  const FilterWidget({
    super.key, 
    required this.showAttribute,
    this.showCategory = false,
    this.showBrand = false,
    this.showTag = false,
    this.showPriceSlider = false,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showAttribute)
          ChangeNotifierProvider<NewAttributeFilterSystem>(
            create: (_) => NewAttributeFilterSystem()..fetchAttributes(),
            child: NewAttributeFilterWidget(
              onApply: (payload) {
                if (onFilter != null) {
                  onFilter!(payload);
                }
              },
            ),
          ),
      ],
    );
  }
}
