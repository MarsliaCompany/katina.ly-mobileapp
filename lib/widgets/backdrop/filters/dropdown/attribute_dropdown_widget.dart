import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../../models/entities/hierarchical_attribute.dart';
import '../../../../models/filter_attribute_model.dart';
import '../../../../models/index.dart';
import '../../../../services/services.dart';
import '../hierarchical_filter_column.dart';

class AttributeDropdownWidget extends StatefulWidget {
  const AttributeDropdownWidget({
    super.key,
    this.selectedAttribute,
    this.onChanged,
  });

  final Map<FilterAttribute, List<SubAttribute>>? selectedAttribute;
  final Function(Map<FilterAttribute, List<SubAttribute>>)? onChanged;

  @override
  State<AttributeDropdownWidget> createState() => AttributeDropdownWidgetState();
}

class AttributeDropdownWidgetState extends State<AttributeDropdownWidget> {
  // Map to store selected sub-attributes for each attribute
  Map<int, List<SubAttribute>> _selectedSubAttributesMap = {};
  final Map<int, String> _searchQueries = {};
  final Map<int, TextEditingController> _searchControllers = {};

  FilterAttributeModel get filterAttributeModel =>
      context.read<FilterAttributeModel>();

  String get lang => context.read<AppModel>().langCode;

  @override
  void initState() {
    super.initState();
    // Initialize selected attributes from widget
    if (widget.selectedAttribute?.isNotEmpty ?? false) {
      for (var entry in widget.selectedAttribute!.entries) {
        _selectedSubAttributesMap[entry.key.id!] = entry.value;
        // Load sub-attributes for each attribute
        filterAttributeModel.getSubAttributes(attributeId: entry.key.id!);
      }
    }
  }

  void resetSelections() {
    setState(() {
      _selectedSubAttributesMap.clear();
    });
    widget.onChanged?.call({});
  }

  void _onSubAttributeChanged(int attributeId, int? subAttributeId) {
    final attribute = filterAttributeModel.lstProductAttribute
        ?.firstWhereOrNull((element) => element.id == attributeId);

    if (attribute == null) {
      return;
    }

    setState(() {
      if (subAttributeId == null) {
        _selectedSubAttributesMap.remove(attributeId);
        _clearDescendantSelections(attributeId);
      } else {
        final subAttribute = filterAttributeModel
            .lstSubAttribute[attributeId]
            ?.firstWhereOrNull((element) => element.id == subAttributeId);

        if (subAttribute != null) {
          _clearDescendantSelections(attributeId);
          _selectedSubAttributesMap[attributeId] = [subAttribute];
        }
      }
    });

    // Build the attributes map to pass to parent
    final Map<FilterAttribute, List<SubAttribute>> attributesMap = {};
    for (var entry in _selectedSubAttributesMap.entries) {
      final attr = filterAttributeModel.lstProductAttribute
          ?.firstWhereOrNull((element) => element.id == entry.key);
      if (attr != null && entry.value.isNotEmpty) {
        attributesMap[attr] = entry.value;
      }
    }

    widget.onChanged?.call(attributesMap);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FilterAttributeModel>(
      builder: (_, model, __) {
        final listAttribute = model.listVisibleAttribute ?? [];

        if (listAttribute.isEmpty) {
          return const SizedBox();
        }

        final hasHierarchy = model.hasHierarchicalAttributes &&
            (model.hierarchicalAttributes?.isNotEmpty ?? false);

        if (hasHierarchy) {
          return _buildHierarchicalDropdowns(model);
        }

        return _buildFlatDropdowns(model, listAttribute);
      },
    );
  }

  Widget _buildFlatDropdowns(
    FilterAttributeModel model,
    Iterable<FilterAttribute> attributes,
  ) {
    // Load sub-attributes for all attributes on first build
    for (var attribute in attributes) {
      if (attribute.id != null &&
          model.lstSubAttribute[attribute.id] == null &&
          model.isLoadingSub[attribute.id] != true) {
        model.getSubAttributes(attributeId: attribute.id!);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(),
          ...attributes.map((attribute) {
            final attributeName = model.getAttributeName(attribute.id, lang: lang);
            if (attributeName == null) {
              return const SizedBox.shrink();
            }
            return _buildAttributeDropdown(
              attribute: attribute,
              attributeName: attributeName,
              model: model,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHierarchicalDropdowns(FilterAttributeModel model) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: HierarchicalFilterColumn(
        selectedAttribute: widget.selectedAttribute,
        onChanged: widget.onChanged,
      ),
    );
  }

  Widget _buildAttributeDropdown({
    required FilterAttribute attribute,
    required String attributeName,
    required FilterAttributeModel model,
  }) {
    final selectedSubAttributes = _selectedSubAttributesMap[attribute.id] ?? [];
    final selectedSubAttributeId =
        selectedSubAttributes.isNotEmpty ? selectedSubAttributes.first.id : null;
    final attributeId = attribute.id;
    final controller =
        attributeId != null ? _getSearchController(attributeId) : null;
    final filteredSubAttributes = attributeId != null
        ? _filterSubAttributes(model.lstSubAttribute[attributeId] ?? const [],
            attributeId)
        : model.lstSubAttribute[attribute.id] ?? const [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              attributeName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                if (controller != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: TextField(
                      key: ValueKey('attribute-search-$attributeId'),
                      controller: controller,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                        ),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: controller.clear,
                              )
                            : null,
                        hintText: 'ابحث عن $attributeName',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                DropdownButtonFormField<int>(
                  value: selectedSubAttributeId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  hint: Text('اختر $attributeName'),
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text(S.of(context).all ?? 'الكل'),
                    ),
                    ...filteredSubAttributes.map(
                      (subAttribute) {
                        return DropdownMenuItem<int>(
                          value: subAttribute.id,
                          child: Text(subAttribute.name ?? ''),
                        );
                      },
                    ),
                  ],
                  onChanged: model.isLoadingSub[attribute.id] == true
                      ? null
                      : (value) => _onSubAttributeChanged(attribute.id!, value),
                  isExpanded: true,
                  icon: model.isLoadingSub[attribute.id] == true
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.keyboard_arrow_down),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                ),
                if (filteredSubAttributes.isEmpty &&
                    (_searchQueries[attributeId] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 12,
                    ),
                    child: Text(
                      'لا توجد نتائج مطابقة',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).hintColor),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        S.of(context).attribute ?? 'السمات',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _clearDescendantSelections(int attributeId) {
    final roots = filterAttributeModel.hierarchicalAttributes;
    if (roots == null || roots.isEmpty) {
      return;
    }
    final node = _findNodeById(attributeId, roots);
    if (node == null) {
      return;
    }

    void removeSelections(List<HierarchicalAttribute> children) {
      for (final child in children) {
        _selectedSubAttributesMap.remove(child.id);
        final grandchildren = _resolveChildren(child, filterAttributeModel);
        if (grandchildren.isNotEmpty) {
          removeSelections(grandchildren);
        }
      }
    }

    removeSelections(_resolveChildren(node, filterAttributeModel));
  }

  HierarchicalAttribute? _findNodeById(
      int targetId, List<HierarchicalAttribute> nodes) {
    for (final node in nodes) {
      if (node.id == targetId) {
        return node;
      }
      final result = _findNodeById(targetId, node.children);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  List<HierarchicalAttribute> _resolveChildren(
    HierarchicalAttribute node,
    FilterAttributeModel model,
  ) {
    if (node.children.isNotEmpty) {
      return node.children;
    }
    final allNodes = model.hierarchicalAttributes ?? [];
    return allNodes
        .where((candidate) => candidate.parentIds.contains(node.id))
        .toList();
  }

  TextEditingController _getSearchController(int attributeId) {
    if (_searchControllers.containsKey(attributeId)) {
      return _searchControllers[attributeId]!;
    }
    final controller =
        TextEditingController(text: _searchQueries[attributeId] ?? '');
    controller.addListener(() {
      if (!mounted) {
        return;
      }
      final text = controller.text;
      setState(() {
        if (text.isEmpty) {
          _searchQueries.remove(attributeId);
        } else {
          _searchQueries[attributeId] = text;
        }
      });
    });
    _searchControllers[attributeId] = controller;
    return controller;
  }

  List<SubAttribute> _filterSubAttributes(
    List<SubAttribute> source,
    int attributeId,
  ) {
    final query = _searchQueries[attributeId];
    if (query == null || query.trim().isEmpty) {
      return source;
    }
    final normalizedQuery = _normalize(query);
    return source
        .where((subAttribute) {
          final name = subAttribute.name ?? '';
          return _normalize(name).contains(normalizedQuery);
        })
        .toList();
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  void dispose() {
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
