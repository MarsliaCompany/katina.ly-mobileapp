import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filters/new_attribute_filter_model.dart';
import '../models/filters/new_filter_attribute.dart';

class AttributeFilterWidget extends StatelessWidget {
  const AttributeFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<NewAttributeFilterModel>();
    
    return Column(
      children: [
        // عرض المرشحات الحالية
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: model.visibleAttributes.map((attribute) {
            return FilterChip(
              label: Text(attribute.name),
              selected: false,
              onSelected: (_) => model.selectAttribute(attribute.id),
            );
          }).toList(),
        ),
        
        // زر الرجوع إذا كنا في مستوى فرعي
        if (model.selectedParentIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              onPressed: model.goBack,
              child: const Text('رجوع للمستوى السابق'),
            ),
          ),
      ],
    );
  }
}
