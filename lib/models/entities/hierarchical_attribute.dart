class HierarchicalAttribute {
  final int id;
  final String name;
  final String? label;
  final List<HierarchicalAttribute> children;
  final List<int> parentIds;

  const HierarchicalAttribute({
    required this.id,
    required this.name,
    this.label,
    this.children = const [],
    this.parentIds = const [],
  });

  bool get hasChildren => children.isNotEmpty;
  bool get hasMultipleParents => parentIds.length > 1;

  factory HierarchicalAttribute.fromJson(Map json) {
    final childList = <HierarchicalAttribute>[];
    final rawChildren = json['children'];
    if (rawChildren is Iterable) {
      for (final child in rawChildren) {
        if (child is Map) {
          childList.add(HierarchicalAttribute.fromJson(child));
        }
      }
    }

    final parentIdsList = <int>[];
    final rawParents = json['parent_ids'];
    if (rawParents is Iterable) {
      for (final parentId in rawParents) {
        if (parentId is int) {
          parentIdsList.add(parentId);
        } else if (parentId is String) {
          final parsed = int.tryParse(parentId);
          if (parsed != null) parentIdsList.add(parsed);
        }
      }
    } else if (rawParents is int) {
      parentIdsList.add(rawParents);
    } else if (rawParents is String) {
      final parsed = int.tryParse(rawParents);
      if (parsed != null) parentIdsList.add(parsed);
    }

    return HierarchicalAttribute(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? json['attribute_name'] ?? ''}',
      label: json['label'] ?? json['attribute_label'],
      children: childList,
      parentIds: parentIdsList,
    );
  }

  HierarchicalAttribute copyWith({
    int? id,
    String? name,
    String? label,
    List<HierarchicalAttribute>? children,
    List<int>? parentIds,
  }) {
    return HierarchicalAttribute(
      id: id ?? this.id,
      name: name ?? this.name,
      label: label ?? this.label,
      children: children ?? this.children,
      parentIds: parentIds ?? this.parentIds,
    );
  }

  @override
  String toString() {
    final parentStr = hasMultipleParents ? ' (Parents: $parentIds)' : '';
    return '$name ($id)$parentStr';
  }
}
