import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../common/constants.dart';
import '../../models/entities/back_drop_arguments.dart';
import '../../models/entities/filter_sorty_by.dart';
import '../../models/index.dart';
import '../../modules/dynamic_layout/helper/helper.dart';
import '../../routes/flux_navigate.dart';
import '../../services/index.dart';
import '../../widgets/backdrop/new_filter_system.dart';
import '../../models/filters/new_attribute_system.dart';

class FiltersScreen extends StatefulWidget {
  final BackDropArguments arguments;

  const FiltersScreen({
    super.key,
    required this.arguments,
  });

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  // Filter state
  List<String>? _categoryIds;
  List<String>? _tagIds;
  List<String>? _brandIds;
  String? _listingLocationId;
  Map<FilterAttribute, List<SubAttribute>>? _selectedAttributes;
  List<Map<String, dynamic>>? _attributeSelectionsPayload;
  double? _minPrice;
  double? _maxPrice;
  FilterSortBy? _sortBy;

  bool _isLoadingPrices = true;

  @override
  void initState() {
    super.initState();
    _categoryIds = widget.arguments.cateId?.split(',');
    _categoryIds?.removeWhere((element) => element.isEmpty);
    _initFilterPrices();
  }

  Future<void> _initFilterPrices() async {
    final productPriceModel = context.read<ProductPriceModel>();
    
    // Fetch products to get price range
    await productPriceModel.getMinMaxPrices();
    
    if (mounted) {
      setState(() {
        _isLoadingPrices = false;
      });
    }
  }

  void _onFilter({
    double? minPrice,
    double? maxPrice,
    List<String>? categoryId,
    String? categoryName,
    List<String>? tagId,
    String? listingLocationId,
    FilterSortBy? sortBy,
    bool? isSearch,
    List<String>? brandIds,
    Map<FilterAttribute, List<SubAttribute>>? attributes,
  }) {
    setState(() {
      _minPrice = minPrice;
      _maxPrice = maxPrice;
      _categoryIds = categoryId;
      _tagIds = tagId;
      _brandIds = brandIds;
      _listingLocationId = listingLocationId;
      _sortBy = sortBy;
      _selectedAttributes = attributes;
    });
  }

  void _handleAttributeApply(Map<String, dynamic> payload) {
    final selections = (payload['attributeSelections'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList();

    if (selections == null || selections.isEmpty) {
      return;
    }

    setState(() {
      _attributeSelectionsPayload = selections;
    });

    _applyFilters();
  }

  void _applyFilters() {
    print('🔍 [FiltersScreen] بدء تطبيق المرشحات');
    
    // Store filter values in config for backdrop screen
    final Map<String, dynamic> updatedConfig = widget.arguments.config != null
        ? Map<String, dynamic>.from(widget.arguments.config!)
        : <String, dynamic>{};
    
    // Add filter values to config if they exist
    if (_minPrice != null) {
      updatedConfig['minPrice'] = _minPrice;
    }
    if (_maxPrice != null) {
      updatedConfig['maxPrice'] = _maxPrice;
    }
    if (_sortBy != null) {
      // Store sortBy as map for easier parsing
      updatedConfig['sortBy'] = _sortBy!.toMap();
    }
    if (_selectedAttributes != null && _selectedAttributes!.isNotEmpty) {
      // Store selected attributes in config
      updatedConfig['selectedAttributes'] = _selectedAttributes;
    }
    if (_attributeSelectionsPayload != null &&
        _attributeSelectionsPayload!.isNotEmpty) {
      updatedConfig['attributeSelections'] = _attributeSelectionsPayload!
          .map((selection) => Map<String, dynamic>.from(selection))
          .toList();
    }
    if (_listingLocationId != null) {
      updatedConfig['listingLocationId'] = _listingLocationId;
    }

    print('🔍 [FiltersScreen] Category IDs: $_categoryIds');
    print('🔍 [FiltersScreen] Config: $updatedConfig');

    // Create arguments with applied filters
    final finalArguments = BackDropArguments(
      cateId: _categoryIds?.join(','),
      cateName: widget.arguments.cateName,
      tag: _tagIds?.join(','),
      brandId: _brandIds?.join(','),
      config: updatedConfig,
      showCountdown: widget.arguments.showCountdown,
      countdownDuration: widget.arguments.countdownDuration,
      allowFilterMultipleCategory: widget.arguments.allowFilterMultipleCategory,
      categoryMenuStyle: widget.arguments.categoryMenuStyle,
      categoryMenuShowDepth: widget.arguments.categoryMenuShowDepth,
      filtersApplied: true, // Mark that filters are applied
    );

    // Store basic filter values in ProductModel for backdrop screen
    final productModel = context.read<ProductModel>();
    productModel.categoryIds = _categoryIds;
    productModel.tagIds = _tagIds;
    productModel.brandIds = _brandIds;
    productModel.listingLocationId = _listingLocationId;

    print('🔍 [FiltersScreen] ProductModel updated');
    print('🔍 [FiltersScreen] Navigating to backdrop with filtersApplied=true');
    print('🔍 [FiltersScreen] Category IDs: $_categoryIds');
    print('🔍 [FiltersScreen] Category Name: ${widget.arguments.cateName}');

    // Navigate to backdrop screen with filters applied
    // Use FluxNavigate.pushReplacementNamed to ensure proper navigation handling
    // This replaces FiltersScreen with backdrop, keeping the navigation stack correct
    unawaited(
      FluxNavigate.pushReplacementNamed(
        RouteList.backdrop,
        arguments: finalArguments,
        context: context,
        forceRootNavigator: false,
      ),
    );
    
    print('🔍 [FiltersScreen] Navigation completed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: kToolbarHeight + 16,
        title: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            widget.arguments.cateName ?? S.of(context).filter,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoadingPrices
          ? const Center(child: CircularProgressIndicator())
          : ChangeNotifierProvider<FilterBrandModel>(
              create: (_) => FilterBrandModel(),
              child: Consumer<ProductPriceModel>(
                builder: (context, productPriceModel, child) {
                  return ChangeNotifierProvider<NewAttributeFilterSystem>(
                    create: (_) => NewAttributeFilterSystem()..fetchAttributes(),
                    child: NewFilterSystem(
                      showAttribute: true,
                      onFilter: _handleAttributeApply,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
