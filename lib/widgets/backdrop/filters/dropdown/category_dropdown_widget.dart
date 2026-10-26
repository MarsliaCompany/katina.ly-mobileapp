import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../../models/index.dart' show BlogModel, Category, CategoryModel, ProductModel;

class CategoryDropdownWidget extends StatefulWidget {
  final Function(List<String> category) onFilter;
  final bool isUseBlog;
  final List<String>? categoryId;
  final bool isBlog;
  final bool allowMultiple;

  const CategoryDropdownWidget({
    super.key,
    required this.onFilter,
    this.isUseBlog = false,
    this.categoryId,
    this.isBlog = false,
    this.allowMultiple = false,
  });

  @override
  State<CategoryDropdownWidget> createState() => _CategoryDropdownWidgetState();
}

class _CategoryDropdownWidgetState extends State<CategoryDropdownWidget> {
  ProductModel get productModel => context.read<ProductModel>();
  BlogModel get blogModel => context.read<BlogModel>();

  List<String>? get categoryId =>
      widget.isUseBlog ? blogModel.categoryIds : productModel.categoryIds;

  List<String> _categoryId = [];
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId ?? categoryId ?? [];
  }

  void _updateSelectedCategoryName(List<Category> categories) {
    if (_categoryId.isNotEmpty && categories.isNotEmpty) {
      try {
        final selectedCategory = categories.firstWhere(
          (cat) => cat.id == _categoryId.first,
        );
        _selectedCategoryName = selectedCategory.name;
      } catch (e) {
        _selectedCategoryName = null;
      }
    } else {
      _selectedCategoryName = null;
    }
  }

  List<Category> _getRootCategories(List<Category> categories) {
    return categories.where((item) => item.isRoot == true).toList();
  }

  void _onCategoryChanged(String? categoryId, String? categoryName) {
    setState(() {
      if (categoryId == null) {
        _categoryId = [];
        _selectedCategoryName = null;
      } else {
        if (widget.allowMultiple) {
          if (_categoryId.contains(categoryId)) {
            _categoryId.remove(categoryId);
          } else {
            _categoryId.add(categoryId);
          }
        } else {
          _categoryId = [categoryId];
          _selectedCategoryName = categoryName;
        }
      }
    });
    widget.onFilter(_categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final menuCategory = widget.isUseBlog
        ? Selector<BlogModel, List<Category>>(
            builder: (context, categories, child) {
              return _buildDropdown(categories);
            },
            selector: (_, model) => model.categories,
          )
        : Selector<CategoryModel, List<Category>>(
            builder: (context, categories, child) {
              return _buildDropdown(categories);
            },
            selector: (_, model) => model.categories ?? [],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).category,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          menuCategory,
        ],
      ),
    );
  }

  Widget _buildDropdown(List<Category> categories) {
    final rootCategories = _getRootCategories(categories);
    
    if (rootCategories.isEmpty) {
      return const SizedBox();
    }

    // Update selected category name when categories are available
    _updateSelectedCategoryName(categories);

    // Create a flat list of all categories for dropdown
    List<Category> flatCategories = [];
    void addCategoryAndChildren(Category category) {
      flatCategories.add(category);
      final children = categories.where((c) => c.parent == category.id).toList();
      for (var child in children) {
        addCategoryAndChildren(child);
      }
    }
    
    for (var root in rootCategories) {
      addCategoryAndChildren(root);
    }

    return DropdownButtonFormField<String>(
      value: _categoryId.isNotEmpty ? _categoryId.first : null,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      hint: const Text('اختر الفئة'),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(S.of(context).all ?? 'الكل'),
        ),
        ...flatCategories.map((category) {
          final indent = category.isRoot == true ? '' : '  ';
          return DropdownMenuItem<String>(
            value: category.id,
            child: Text('$indent${category.name}'),
          );
        }),
      ],
      onChanged: (value) {
        if (value != null) {
          final selectedCategory = flatCategories.firstWhere(
            (cat) => cat.id == value,
          );
          _onCategoryChanged(value, selectedCategory.name);
        } else {
          _onCategoryChanged(null, null);
        }
      },
    );
  }
}

