import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../entities/new_filter_attribute.dart';

class NewAttributeFilterModel extends ChangeNotifier {
  List<NewFilterAttribute> _attributes = [];
  List<String> _selectedParentIds = [];
  
  Future<void> fetchAttributes() async {
    final response = await http.get(
      Uri.parse('https://katina.ly/wp-json/katina-hpa-complete/v1/attributes')
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _attributes = (data['data'] as List).map((item) => NewFilterAttribute.fromJson(item)).toList();
      notifyListeners();
    }
  }
  
  List<NewFilterAttribute> get visibleAttributes => _attributes.where((attr) {
    if (_selectedParentIds.isEmpty) return attr.parentId == null;
    return _selectedParentIds.contains(attr.parentId);
  }).toList();
  
  List<String> get selectedParentIds => _selectedParentIds;
  
  void selectAttribute(String attributeId) {
    final attribute = _attributes.firstWhere((attr) => attr.id == attributeId);
    if (attribute.hasChildren) {
      _selectedParentIds.add(attributeId);
      notifyListeners();
    }
  }
  
  void goBack() {
    if (_selectedParentIds.isNotEmpty) {
      _selectedParentIds.removeLast();
      notifyListeners();
    }
  }
}
