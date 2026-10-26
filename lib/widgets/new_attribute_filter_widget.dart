import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/filters/new_attribute_system.dart';

class NewAttributeFilterWidget extends StatelessWidget {
  const NewAttributeFilterWidget({
    super.key,
    this.onApply,
  });

  final ValueChanged<Map<String, dynamic>>? onApply;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<NewAttributeFilterSystem>();

    if (model.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (model.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              model.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context
                  .read<NewAttributeFilterSystem>()
                  .fetchAttributes(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final canApply = onApply != null && model.canApply;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تصفية المنتجات',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 64,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'اختر الشركة المصنعة ثم استكمل التسلسل لترى منتجات مطابقة بكل دقة.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...List.generate(model.levels.length, (index) {
          final level = model.levels[index];
          final values = model.optionsForLevel(index);

          if (values.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: DropdownButtonFormField<String>(
                  value: level.selectedValueId,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    labelText: model.getLevelLabel(index),
                  ),
                  items: values
                      .map(
                        (attributeValue) => DropdownMenuItem<String>(
                          value: attributeValue.id,
                          child: Text(attributeValue.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => context
                      .read<NewAttributeFilterSystem>()
                      .updateSelection(
                        levelIndex: index,
                        selectedValueId: value,
                      ),
                ),
              ),
            ),
          );
        }),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                context.read<NewAttributeFilterSystem>().resetSelections(),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة ضبط الاختيارات'),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                canApply ? () => onApply!(model.buildFilterPayload()) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              disabledBackgroundColor: theme.colorScheme.surfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('تطبيق'),
          ),
        ),
      ],
    );
  }
}
