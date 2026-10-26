class NewFilterAttribute {
  final String id;
  final String name;
  final String? parentId;
  final bool hasChildren;
  
  NewFilterAttribute({
    required this.id,
    required this.name,
    this.parentId,
    required this.hasChildren,
  });
  
  factory NewFilterAttribute.fromJson(Map<String, dynamic> json) {
    return NewFilterAttribute(
      id: json['id'].toString(),
      name: json['label'] ?? json['name'] ?? '',
      parentId: json['parent_ids']?.first?.toString(),
      hasChildren: json['has_children'] ?? false,
    );
  }
}
