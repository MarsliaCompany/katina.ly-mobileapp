import 'dart:convert';

import 'package:flutter/material.dart';

class AttributeNode {
  AttributeNode({
    required this.id,
    required this.label,
    required this.values,
    required this.children,
  });

  final String id;
  final String label;
  final List<AttributeValue> values;
  final List<AttributeNode> children;

  factory AttributeNode.fromJson(Map<String, dynamic> json) {
    final values = (json['values'] as List<dynamic>? ?? [])
        .map(
          (valueJson) => AttributeValue.fromJson(valueJson),
        )
        .toList();
    final children = (json['children'] as List<dynamic>? ?? [])
        .map(
          (childJson) => AttributeNode.fromJson(
            Map<String, dynamic>.from(childJson as Map),
          ),
        )
        .toList();
    final label = json['label']?.toString() ?? json['name']?.toString() ?? '';
    return AttributeNode(
      id: json['id'].toString(),
      label: label.isEmpty ? 'سمة' : label,
      values: values,
      children: children,
    );
  }
}

class AttributeValue {
  AttributeValue({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  factory AttributeValue.fromJson(Map<String, dynamic> json) {
    final label = json['name']?.toString() ?? json['label']?.toString() ?? '';
    return AttributeValue(
      id: json['id'].toString(),
      label: label.isEmpty ? 'قيمة' : label,
    );
  }
}

class ConditionalAttributeFilter extends StatefulWidget {
  const ConditionalAttributeFilter({
    super.key,
    required this.rootJson,
    required this.onApply,
    this.minSelections = 3,
  });

  /// JSON string that represents the root attribute node (company → models → ...).
  final String rootJson;
  final ValueChanged<Map<String, String>> onApply;
  final int minSelections;

  @override
  State<ConditionalAttributeFilter> createState() =>
      _ConditionalAttributeFilterState();
}

class _ConditionalAttributeFilterState
    extends State<ConditionalAttributeFilter> {
  late AttributeNode _root;
  final List<_FilterLevel> _levels = [];

  @override
  void initState() {
    super.initState();
    _root = AttributeNode.fromJson(
      json.decode(widget.rootJson) as Map<String, dynamic>,
    );
    _levels.add(
      _FilterLevel(
        node: _root,
      ),
    );
  }

  void _onValueSelected({
    required int levelIndex,
    required AttributeValue? value,
  }) {
    setState(() {
      final level = _levels[levelIndex];
      level.selectedValue = value;
      _levels.removeRange(levelIndex + 1, _levels.length);

      if (value == null) {
        return;
      }

      if (level.node.children.isEmpty) {
        return;
      }

      final childNode = level.node.children.firstWhere(
        (node) => node.values.isNotEmpty,
        orElse: () => level.node.children.first,
      );

      _levels.add(
        _FilterLevel(
          node: childNode,
        ),
      );
    });
  }

  void _reset() {
    setState(() {
      _levels
        ..clear()
        ..add(_FilterLevel(node: _root));
    });
  }

  bool get _canApply =>
      _levels.where((level) => level.selectedValue != null).length >=
      widget.minSelections;

  Map<String, String> _buildPayload() {
    final payload = <String, String>{};
    for (final level in _levels) {
      if (level.selectedValue == null) {
        break;
      }
      payload[level.node.id] = level.selectedValue!.id;
    }
    return payload;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ...List.generate(_levels.length, (index) {
          final level = _levels[index];
          return AnimatedSwitcher(
            key: ValueKey('level-$index-${level.node.id}'),
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            ),
            child: Padding(
              key: ValueKey('dropdown-$index-${level.node.id}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<AttributeValue>(
                value: level.selectedValue,
                decoration: InputDecoration(
                  labelText: level.node.label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: level.node.values
                    .map(
                      (value) => DropdownMenuItem<AttributeValue>(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _onValueSelected(
                  levelIndex: index,
                  value: value,
                ),
              ),
            ),
          );
        }),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة ضبط'),
            ),
            ElevatedButton(
              onPressed: _canApply ? () => widget.onApply(_buildPayload()) : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterLevel {
  _FilterLevel({
    required this.node,
    this.selectedValue,
  });

  final AttributeNode node;
  AttributeValue? selectedValue;
}
