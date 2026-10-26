import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../models/entities/filter_attribute.dart';
import '../../../models/entities/hierarchical_attribute.dart';
import '../../../models/filter_attribute_model.dart';
import '../../../models/product_model.dart';

class HierarchicalFilterColumn extends StatefulWidget {
  const HierarchicalFilterColumn({
    super.key,
    this.selectedAttribute,
    this.onChanged,
    this.lockedRootId,
    this.lockedRootLabel,
  });

  final Map<FilterAttribute, List<SubAttribute>>? selectedAttribute;
  final ValueChanged<Map<FilterAttribute, List<SubAttribute>>>? onChanged;
  final int? lockedRootId;
  final String? lockedRootLabel;

  @override
  HierarchicalFilterColumnState createState() =>
      HierarchicalFilterColumnState();
}

class HierarchicalFilterColumnState
    extends State<HierarchicalFilterColumn> {
  final List<_LevelData> _levels = [];
  bool _isBootstrapping = true;
  bool _isLoadingNextLevel = false;

  final Map<int, String> _searchQueries = {};
  final Map<int, TextEditingController> _searchControllers = {};

  FilterAttributeModel get _filterModel =>
      context.read<FilterAttributeModel>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() => _isBootstrapping = true);
    final filterModel = context.read<FilterAttributeModel>();
    final roots = await filterModel.loadRootAttributes();
    if (!mounted) return;
    final rootNodes =
        roots.isNotEmpty ? roots : filterModel.getCachedChildren(null);
    if (rootNodes.isEmpty) {
      setState(() => _isBootstrapping = false);
      return;
    }

    var initialNode = rootNodes.first;
    if (widget.lockedRootId != null) {
      final lockedNode = rootNodes
          .firstWhereOrNull((element) => element.id == widget.lockedRootId);
      if (lockedNode != null) {
        initialNode = lockedNode;
      }
    }

    setState(() {
      _levels
        ..clear()
        ..add(_LevelData(
          node: initialNode,
          isLocked: widget.lockedRootId != null,
        ));
    });

    await _ensureOptionsForLevel(0);

    if (widget.lockedRootId != null) {
      final rootLevel = _levels.first;
      rootLevel.selected = SubAttribute(
        id: widget.lockedRootId,
        name: widget.lockedRootLabel ?? rootLevel.node.label ?? rootLevel.node.name,
      );
      _emitSelection();
    }

    setState(() => _isBootstrapping = false);
  }

  Future<void> _ensureOptionsForLevel(int index) async {
    if (index < 0 || index >= _levels.length) {
      return;
    }
    final filterModel = context.read<FilterAttributeModel>();
    final attrId = _levels[index].node.id;
    await filterModel.getSubAttributes(attributeId: attrId);
    if (!mounted) {
      return;
    }
    setState(() {
      _levels[index].options =
          List<SubAttribute>.from(filterModel.lstSubAttribute[attrId] ?? []);
    });
  }

  Future<void> _handleSelectionChanged(
      int levelIndex, int? subAttributeId) async {
    final level = _levels[levelIndex];
    setState(() {
      level.selected = level.options
          .firstWhereOrNull((element) => element.id == subAttributeId);
      if (levelIndex + 1 < _levels.length) {
        _levels.removeRange(levelIndex + 1, _levels.length);
      }
    });

    if (subAttributeId == null) {
      _emitSelection();
      return;
    }

    await _loadNextLevels(levelIndex);
    _emitSelection();
  }

  Future<void> _loadNextLevels(int levelIndex) async {
    setState(() => _isLoadingNextLevel = true);
    final parentId = _levels[levelIndex].node.id;
    final children = await _filterModel.loadChildren(parentId);

    if (!mounted) return;

    setState(() {
      _isLoadingNextLevel = false;
      if (levelIndex + 1 < _levels.length) {
        _levels.removeRange(levelIndex + 1, _levels.length);
      }
      for (final child in children) {
        _levels.add(_LevelData(node: child));
      }
    });

    for (var i = levelIndex + 1; i < _levels.length; i++) {
      await _ensureOptionsForLevel(i);
    }
  }

  void _emitSelection() {
    final filterModel = context.read<FilterAttributeModel>();
    final map = <FilterAttribute, List<SubAttribute>>{};
    final attributes = _filterModel.lstProductAttribute ?? [];

    for (final level in _levels) {
      final selection = level.selected;
      if (selection == null) {
        continue;
      }
      final attribute = attributes
          .firstWhereOrNull((element) => element.id == level.node.id);
      if (attribute != null) {
        map[attribute] = [selection];
      }
    }

    ProductModel? productModel;
    try {
      productModel = context.read<ProductModel>();
    } catch (_) {
      productModel = null;
    }
    productModel?.setAttributeFilters(map.isEmpty ? null : map, notify: false);
    widget.onChanged?.call(map);
  }

  void resetSelections() {
    if (_levels.isEmpty) {
      return;
    }
    setState(() {
      final root = _levels.first;
      root.selected = null;
      _levels
        ..clear()
        ..add(root);
    });
    _emitSelection();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FilterAttributeModel>();

    if (_isBootstrapping) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_levels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(),
        const SizedBox(height: 8),
        for (var i = 0; i < _levels.length; i++)
          _buildLevelDropdown(context, model, i),
        if (_isLoadingNextLevel)
          const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLevelDropdown(
      BuildContext context, FilterAttributeModel model, int index) {
    final level = _levels[index];

    final shouldShow = index == 0 ||
        (index - 1 >= 0 && _levels[index - 1].selected != null);
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final label = model.getAttributeName(level.node.id) ??
        level.node.label ??
        level.node.name;
    final selectedId = level.selected?.id;
    final isLoadingOptions =
        level.options.isEmpty && model.isLoadingSub[level.node.id] == true;

    if (level.isLocked) {
      final lockedColor = Theme.of(context)
          .colorScheme
          .onSurface
          .withOpacity(0.6);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: lockedColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceVariant,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      level.selected?.name ?? widget.lockedRootLabel ?? label,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: lockedColor),
                    ),
                  ),
                  const Icon(Icons.lock, size: 16),
                ],
              ),
            )
          ],
        ),
      );
    }

    final nodeId = level.node.id;
    final controller = _getSearchController(nodeId);
    final filteredOptions = _filterOptions(level.options, nodeId);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Padding(
        key: ValueKey(level.node.id),
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: ValueKey('hierarchy-search-$nodeId'),
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: controller.clear,
                      )
                    : null,
                hintText: 'ابحث عن $label',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: selectedId,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              isExpanded: true,
              hint: Text('${S.of(context).select ?? 'اختر'} $label'),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(S.of(context).all ?? 'الكل'),
                ),
                ...filteredOptions.map(
                  (option) => DropdownMenuItem<int?>(
                    value: option.id,
                    child: Text(option.name ?? ''),
                  ),
                ),
              ],
              onChanged: isLoadingOptions
                  ? null
                  : (value) => _handleSelectionChanged(index, value),
            ),
            if (filteredOptions.isEmpty &&
                (_searchQueries[nodeId] ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
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
    );
  }

  TextEditingController _getSearchController(int nodeId) {
    if (_searchControllers.containsKey(nodeId)) {
      return _searchControllers[nodeId]!;
    }
    final controller = TextEditingController(text: _searchQueries[nodeId] ?? '');
    controller.addListener(() {
      if (!mounted) {
        return;
      }
      final text = controller.text;
      setState(() {
        if (text.isEmpty) {
          _searchQueries.remove(nodeId);
        } else {
          _searchQueries[nodeId] = text;
        }
      });
    });
    _searchControllers[nodeId] = controller;
    return controller;
  }

  List<SubAttribute> _filterOptions(List<SubAttribute> source, int nodeId) {
    final query = _searchQueries[nodeId];
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

  Widget _buildSectionTitle() {
    return Text(
      S.of(context).attribute ?? 'السمات',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  @override
  void dispose() {
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _LevelData {
  _LevelData({required this.node, this.isLocked = false});

  final HierarchicalAttribute node;
  List<SubAttribute> options = [];
  SubAttribute? selected;
  final bool isLocked;
}
