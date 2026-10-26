import 'package:flutter/material.dart';

class HierarchicalFilterModel extends ChangeNotifier {
  final List<FilterItem> _allFilters = [];
  List<String> selectedParentIds = [];
  
  void loadFilters(List<FilterItem> filters) {
    _allFilters.clear();
    _allFilters.addAll(filters);
    notifyListeners();
  }
  
  List<FilterItem> get visibleFilters {
    return _allFilters.where((filter) {
      // Show top level filters first
      if (selectedParentIds.isEmpty) {
        return filter.parentId == null;
      }
      // Show children of selected parent
      return selectedParentIds.contains(filter.parentId);
    }).toList();
  }
  
  void selectFilter(String filterId) {
    final filter = _allFilters.firstWhere((f) => f.id == filterId);
    
    if (filter.hasChildren) {
      selectedParentIds.add(filterId);
    }
    notifyListeners();
  }
  
  void goBack() {
    if (selectedParentIds.isNotEmpty) {
      selectedParentIds.removeLast();
      notifyListeners();
    }
  }
  
  void loadFromApiData(Map<String, dynamic> apiData) {
    final filters = <FilterItem>[];
    
    // تحويل بيانات API إلى قائمة FilterItem
    for (final item in apiData['data']) {
      filters.add(FilterItem(
        id: item['id'].toString(),
        name: item['label'] ?? item['name'],
        parentId: item['parent_ids']?.first?.toString(),
        hasChildren: item['has_children'] ?? false,
      ));
      
      // إضافة الأبناء إذا وجدوا
      if (item['children'] != null) {
        for (final child in item['children']) {
          filters.add(FilterItem(
            id: child['id'].toString(),
            name: child['label'] ?? child['name'],
            parentId: item['id'].toString(),
            hasChildren: child['has_children'] ?? false,
          ));
        }
      }
    }
    
    loadFilters(filters);
  }
}

class FilterItem {
  final String id;
  final String name;
  final String? parentId;
  final bool hasChildren;
  
  FilterItem({
    required this.id,
    required this.name,
    this.parentId,
    this.hasChildren = false,
  });
}
