import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/filters/new_attribute_system.dart';
import '../../widgets/new_attribute_filter_widget.dart';

class WebFilter extends StatelessWidget {
  final bool showAttribute;
  
  const WebFilter({super.key, required this.showAttribute});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showAttribute)
          ChangeNotifierProvider<NewAttributeFilterSystem>(
            create: (_) => NewAttributeFilterSystem()..fetchAttributes(),
            child: const NewAttributeFilterWidget(),
          ),
      ],
    );
  }
}
