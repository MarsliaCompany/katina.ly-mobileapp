import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filters/hierarchical_filter_model.dart';

class HierarchicalFilterWidget extends StatelessWidget {
  const HierarchicalFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<HierarchicalFilterModel>();
    
    return Column(
      children: [
        // Display current level filters
        Wrap(
          spacing: 8,
          children: model.visibleFilters.map((filter) {
            return FilterChip(
              label: Text(filter.name),
              selected: false,
              onSelected: (_) => model.selectFilter(filter.id),
            );
          }).toList(),
        ),
        
        // Back button if not at top level
        if (model.selectedParentIds.isNotEmpty)
          TextButton(
            onPressed: model.goBack,
            child: const Text('رجوع'),
          ),
      ],
    );
  }
}
