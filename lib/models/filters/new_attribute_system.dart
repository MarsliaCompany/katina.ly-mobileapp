import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NewFilterAttribute {
  NewFilterAttribute({
    required this.id,
    required this.slug,
    required this.name,
    required this.label,
    this.parentId,
    required this.hasChildren,
    required this.hasValues,
    required this.isRoot,
  });

  final String id;
  final String slug;
  final String name;
  final String label;
  final String? parentId;
  final bool hasChildren;
  final bool hasValues;
  final bool isRoot;

  factory NewFilterAttribute.fromJson(
    Map<String, dynamic> json, {
    String? parentOverride,
  }) {
    final children = json['children'];
    String? inferredParent;
    if (parentOverride != null) {
      inferredParent = parentOverride;
    } else if (json['parent_ids'] is List &&
        (json['parent_ids'] as List).isNotEmpty) {
      inferredParent = (json['parent_ids'] as List).first.toString();
    }
    final inferredHasChildren =
        json['has_children'] ?? (children is List && children.isNotEmpty);
    final inferredHasValues = json['has_values'] ?? false;

    return NewFilterAttribute(
      id: json['id'].toString(),
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
      parentId: inferredParent,
      hasChildren: inferredHasChildren,
      hasValues: inferredHasValues,
      isRoot: json['is_root'] ?? false,
    );
  }
}

class NewFilterValue {
  NewFilterValue({
    required this.id,
    required this.name,
    required this.attributeId,
  });

  final String id;
  final String name;
  final String attributeId;

  factory NewFilterValue.fromJson(
    Map<String, dynamic> json, {
    required String attributeId,
  }) {
    return NewFilterValue(
      id: json['id'].toString(),
      name: json['name'] ?? json['label'] ?? '',
      attributeId: attributeId,
    );
  }
}

class _AttributeLevel {
  _AttributeLevel({
    required this.attributeId,
    this.selectedValueId,
    this.parentValueId,
  });

  final String attributeId;
  String? selectedValueId;
  String? parentValueId;
}

class NewAttributeFilterSystem extends ChangeNotifier {
  final List<NewFilterAttribute> _attributes = [];
  final Map<String, NewFilterAttribute> _attributeById = {};
  final Map<String, List<NewFilterValue>> _valuesByAttribute = {};
  final Map<String, Set<String>> _childrenByParentId = {};
  final List<_AttributeLevel> _levels = [];

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> fetchAttributes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('https://katina.ly/wp-json/katina-hpa-complete/v1/attributes'),
      );

      if (response.statusCode != 200) {
        _errorMessage = 'فشل تحميل السمات (${response.statusCode})';
        return;
      }

      final data = json.decode(response.body);
      _attributes.clear();
      _valuesByAttribute.clear();
      _attributeById.clear();
      _childrenByParentId.clear();
      if (data['data'] is List) {
        for (final dynamic item in data['data']) {
          _ingestAttributeTree(item);
        }
      }
      _initializeLevels();
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تحميل السمات';
      debugPrint('Error fetching attributes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<_AttributeLevel> get levels => List.unmodifiable(_levels);
  bool get hasActiveSelections =>
      _levels.any((level) => level.selectedValueId != null);
  bool get canApply => hasActiveSelections;

  void _initializeLevels() {
    _levels
      ..clear();
    final initialAttribute = _findInitialAttribute();
    if (initialAttribute != null) {
      _levels.add(_AttributeLevel(attributeId: initialAttribute.id));
    }
  }

  NewFilterAttribute? _findInitialAttribute() {
    for (final attr in _attributes) {
      if (attr.isRoot || attr.parentId == null) {
        return attr;
      }
    }
    return _attributes.isNotEmpty ? _attributes.first : null;
  }

  void _ingestAttributeTree(dynamic raw, {String? parentId}) {
    if (raw is! Map<String, dynamic>) {
      return;
    }

    final attribute =
        NewFilterAttribute.fromJson(raw, parentOverride: parentId);
    final existing = _attributeById[attribute.id];
    if (existing == null) {
      _attributes.add(attribute);
    }
    _attributeById[attribute.id] = attribute;

    final values = raw['values'];
    if (values is List && values.isNotEmpty) {
      _valuesByAttribute[attribute.id] = values
          .map(
            (value) =>
                NewFilterValue.fromJson(value, attributeId: attribute.id),
          )
          .toList();
    }

    final children = raw['children'];
    if (children is List && children.isNotEmpty) {
      final childSet =
          _childrenByParentId.putIfAbsent(attribute.id, () => <String>{});
      for (final dynamic child in children) {
        if (child is Map<String, dynamic>) {
          final childId = child['id']?.toString();
          if (childId != null) {
            childSet.add(childId);
          }
          _ingestAttributeTree(child, parentId: attribute.id);
        }
      }

      if ((_valuesByAttribute[attribute.id]?.isEmpty ?? true)) {
        final pseudoValues = children
            .whereType<Map<String, dynamic>>()
            .map(
              (child) => NewFilterValue(
                id: child['id']?.toString() ?? '',
                name: child['label']?.toString() ??
                    child['name']?.toString() ??
                    '',
                attributeId: attribute.id,
              ),
            )
            .where((value) => value.name.isNotEmpty)
            .toList();
        if (pseudoValues.isNotEmpty) {
          _valuesByAttribute[attribute.id] = pseudoValues;
        }
      }
    }
  }

  List<NewFilterValue> optionsForLevel(int levelIndex) {
    if (levelIndex < 0 || levelIndex >= _levels.length) {
      return const [];
    }
    final attributeId = _levels[levelIndex].attributeId;
    final attribute = _attributeById[attributeId];
    if (attribute == null) {
      return const [];
    }

    final predefinedValues = _valuesByAttribute[attributeId];
    if (predefinedValues != null && predefinedValues.isNotEmpty) {
      return predefinedValues;
    }

    final childIds = _childrenByParentId[attribute.id];
    if (childIds == null || childIds.isEmpty) {
      return const [];
    }
    return childIds
        .map((childId) => _attributeById[childId])
        .whereType<NewFilterAttribute>()
        .map(
          (childAttr) => NewFilterValue(
            id: childAttr.id,
            name: childAttr.label.isNotEmpty ? childAttr.label : childAttr.name,
            attributeId: attributeId,
          ),
        )
        .toList();
  }

  String getLevelLabel(int levelIndex) {
    final attributeId = _levels[levelIndex].attributeId;
    final attribute = _attributeById[attributeId];
    return attribute?.label.isNotEmpty == true
        ? attribute!.label
        : attribute?.name ?? 'اختيار فرعي';
  }

  void updateSelection({required int levelIndex, String? selectedValueId}) {
    if (levelIndex < 0 || levelIndex >= _levels.length) {
      return;
    }

    final level = _levels[levelIndex];
    level.selectedValueId = selectedValueId;

    if (_levels.length > levelIndex + 1) {
      _levels.removeRange(levelIndex + 1, _levels.length);
    }

    if (selectedValueId != null) {
      final currentAttribute = _attributeById[level.attributeId];
      if (currentAttribute != null) {
        final childIds = _childrenByParentId[currentAttribute.id];
        if (childIds != null && childIds.isNotEmpty) {
          if (currentAttribute.hasValues) {
            for (final childId in childIds) {
              _levels.add(
                _AttributeLevel(
                  attributeId: childId,
                  parentValueId: selectedValueId,
                ),
              );
            }
          } else if (childIds.contains(selectedValueId)) {
            _levels.add(
              _AttributeLevel(
                attributeId: selectedValueId,
              ),
            );
          }
        }
      }
    }

    notifyListeners();
  }

  void resetSelections() {
    _initializeLevels();
    notifyListeners();
  }

  @visibleForTesting
  void debugSeedSelections({
    required List<NewFilterAttribute> attributes,
    required Map<String, List<NewFilterValue>> valuesByAttribute,
    required List<Map<String, String?>> levels,
  }) {
    _attributes
      ..clear()
      ..addAll(attributes);

    _attributeById
      ..clear();
    for (final attribute in attributes) {
      _attributeById[attribute.id] = attribute;
    }

    _valuesByAttribute
      ..clear();
    valuesByAttribute.forEach((key, value) {
      _valuesByAttribute[key] = List<NewFilterValue>.from(value);
    });

    _levels
      ..clear();
    for (final level in levels) {
      final attributeId = level['attributeId'];
      if (attributeId == null) {
        continue;
      }
      _levels.add(
        _AttributeLevel(
          attributeId: attributeId,
          selectedValueId: level['selectedValueId'],
          parentValueId: level['parentValueId'],
        ),
      );
    }

    notifyListeners();
  }

  Map<String, dynamic> _buildEntry(_AttributeLevel level) {
    final attribute = _attributeById[level.attributeId];
    NewFilterValue? value;
    final candidates = _valuesByAttribute[level.attributeId];
    if (candidates != null) {
      for (final candidate in candidates) {
        if (candidate.id == level.selectedValueId) {
          value = candidate;
          break;
        }
      }
    }

    if (attribute == null || value == null) {
      return {};
    }

    final normalizedTaxonomy = attribute.slug.isNotEmpty
        ? (attribute.slug.startsWith('pa_')
            ? attribute.slug
            : 'pa_${attribute.slug.replaceFirst('pa_', '')}')
        : '';

    return {
      'attributeId': attribute.id,
      'attributeSlug': attribute.slug,
      'attributeTaxonomy': normalizedTaxonomy,
      'attributeName': attribute.name,
      'valueId': value.id,
      'valueName': value.name,
      'parentValueId': level.parentValueId,
    };
  }

  Map<String, dynamic> buildFilterPayload() {
    final entries = _levels
        .where((level) => level.selectedValueId != null)
        .map(_buildEntry)
        .where((entry) => entry.isNotEmpty)
        .toList();

    return {
      'attributeSelections': entries,
    };
  }
}
