import 'package:flutter/material.dart';
import '../new_attribute_filter_widget.dart';

class NewFilterSystem extends StatelessWidget {
  final bool showAttribute;
  final Function(Map<String, dynamic>)? onFilter;
  
  const NewFilterSystem({
    super.key, 
    required this.showAttribute,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showAttribute)
          NewAttributeFilterWidget(
            onApply: onFilter,
          ),
      ],
    );
  }
}
