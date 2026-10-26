import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../models/entities/filter_sorty_by.dart';
import '../../../models/index.dart';
import '../../../modules/analytics/analytics.dart';
import '../../../modules/dynamic_layout/config/product_config.dart';
import '../../../routes/flux_navigate.dart';
import '../../../services/services.dart';
import '../../../widgets/product/product_bottom_sheet.dart';
import '../../common/app_bar_mixin.dart';
import '../filter_mixin/products_filter_mixin.dart';
import '../products_mixin.dart';

abstract class ProductsLayout extends StatefulWidget {
  final List<Product>? products;
  final ProductConfig? config;
  final Duration countdownDuration;
  final bool autoFocusSearch;

  const ProductsLayout({
    super.key,
    this.products,
    this.config,
    this.countdownDuration = Duration.zero,
    this.autoFocusSearch = true,
  });
}

abstract class StateProductLayout<T extends ProductsLayout> extends State<T>
    with
        SingleTickerProviderStateMixin,
        AppBarMixin,
        ProductsMixin,
        ProductsFilterMixin {
  late AnimationController filterController;
  bool _filtersApplied = false; // Track if filters have been applied

  bool get hasAppBar => showAppBar(RouteList.backdrop);
  
  // Expose _filtersApplied to mixin
  @override
  bool get filtersApplied => _filtersApplied;
  
  @override
  set filtersApplied(bool value) {
    _filtersApplied = value;
  }

  ProductConfig get productConfig => widget.config ?? ProductConfig.empty();

  ProductModel get productModel => context.read<ProductModel>();

  UserModel get userModel => context.read<UserModel>();

  AppModel get appModel => context.read<AppModel>();

  /// Image ratio from Product Cart
  double get ratioProductImage => appModel.ratioProductImage;

  double get productListItemHeight => kProductDetail.productListItemHeight;

  bool get showBottomCornerCart => kAdvanceConfig.showBottomCornerCart;

  String? _currentTitle;

  String get currentTitle {
    if (search != null) {
      return S.of(context).results;
    }
    return _currentTitle ?? productModel.categoryName ?? S.of(context).results;
  }

  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _currentTitle = productConfig.name ??
        ((productModel.categoryIds?.isNotEmpty ?? false)
            ? categoryModel
            .getCategoryById(productModel.categoryIds!.first)
            ?.name
            : null);
    
    // Initialize filterController first with default value (filters visible)
    filterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    // Reset to show filters (backLayer) by default
    filterController.reset();
    
    _initFilter();
    Analytics.triggerViewListProduct(widget.products, context);

    /// only request to server if there is empty config params
    // / If there is config, load the products one
  }

  void _initFilter() {
    WidgetsBinding.instance.endOfFrame.then((_) async {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      var productType = false;
      bool shouldApplyFilters = false;

      print('🔍 [ProductsLayout] _initFilter called');
      print('🔍 [ProductsLayout] routeArgs type: ${routeArgs.runtimeType}');

      if (routeArgs is BackDropArguments) {
        productType = routeArgs.config?['productType'] ?? false;
        print('🔍 [ProductsLayout] filtersApplied: ${routeArgs.filtersApplied}');
        print('🔍 [ProductsLayout] cateId: ${routeArgs.cateId}');
        print('🔍 [ProductsLayout] cateName: ${routeArgs.cateName}');
        
        // Check if filters were applied from FiltersScreen
        if (routeArgs.filtersApplied) {
          shouldApplyFilters = true;
          _filtersApplied = true;
          // Show products (frontLayer) immediately since filters are already applied
          filterController.value = 1.0;
          print('🔍 [ProductsLayout] Filters applied, showing products layer');
        }
      }

      productModel.fetchProductsByCategory(
          productType: productType, notify: false);

      await initFilter(config: productConfig);

      // Apply filters from config if they were set in FiltersScreen
      if (shouldApplyFilters && routeArgs is BackDropArguments) {
        final config = routeArgs.config;
        if (config != null) {
          final attributeSelections = config['attributeSelections'];
          if (attributeSelections is List && attributeSelections.isNotEmpty) {
            await filterAttrModel.getFilterAttributes(
              categoryIds: routeArgs.cateId,
              brandIds: routeArgs.brandId,
            );
          }

          // Parse sortBy from config if it exists
          FilterSortBy? parsedSortBy;
          if (config['sortBy'] != null) {
            try {
              // Try to parse from map
              if (config['sortBy'] is Map) {
                parsedSortBy = FilterSortBy.fromMap(config['sortBy'] as Map);
              }
            } catch (e) {
              parsedSortBy = null;
            }
          }
          
          // Apply filters from config
          onFilter(
            minPrice: config['minPrice'] as double?,
            maxPrice: config['maxPrice'] as double?,
            categoryId: routeArgs.cateId?.split(','),
            categoryName: routeArgs.cateName,
            tagId: routeArgs.tag?.split(','),
            brandIds: routeArgs.brandId?.split(','),
            listingLocationId: config['listingLocationId'] as String?,
            sortBy: parsedSortBy,
            attributeSelections:
                attributeSelections is List ? attributeSelections : null,
            attributes:
                (attributeSelections is List)
                    ? null
                    : config['selectedAttributes']
                        as Map<FilterAttribute, List<SubAttribute>>?,
            fetchProduct: true,
          );
        }
      }

      if (mounted) {
        _streamSubscription = eventBus.on<EventRefreshProductsList>().listen(
              (event) {
            onRefresh();
          },
        );
        // Only call onRefresh if filters were not applied (onFilter will trigger getProductList)
        if (!shouldApplyFilters) {
          unawaited(onRefresh());
        } else {
          // If filters were applied, ensure we rebuild to show products
          rebuild();
        }
      }
    });
  }

  @override
  void clearProductList() {
    productModel.setProductsList([]);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    filterController.dispose();
    super.dispose();
  }

  @override
  Future<void> getProductList({bool forceLoad = false}) async {
    await productModel.getProductsList(
      boostEngine: widget.config?.boostEngine,
      categoryId: categoryIds,
      minPrice: minPrice,
      maxPrice: maxPrice,
      page: page,
      lang: appModel.langCode,
      orderBy: filterSortBy.orderByType?.name,
      order: filterSortBy.orderType?.name,
      featured: filterSortBy.featured,
      onSale: filterSortBy.onSale,
      tagId: tagIds,
      attributes: getAttributes(),
      userId: userModel.user?.id,
      listingLocation: listingLocationId,
      include: include,
      search: search,
      brandIds: brandIds,
    );
    Analytics.triggerSearchProduct(
      search,
      productModel.products.isEmpty,
      context,
    );
  }

  void onTapProductCategoryMenu(String? categoryId) {
    // Reset included products
    include = null;

    var selectedCategoryIds = categoryIds;
    if (selectedCategoryIds?.contains(categoryId) ?? false) {
      selectedCategoryIds?.remove(categoryId);
    } else if (categoryId != null) {
      // `ProductCategoryMenu` will be hidden if the selected category number is
      // not equal to 1. Some users do not want this behavior when they select
      // another category item in the list. Therefore, here only a single
      // category filter will be applied. If they want to filter multiple
      // categories on supported platforms, the only way is to open the filter
      // screen.

      // if (allowMultipleCategory) {
      //   selectedCategoryIds?.add(categoryId);
      // } else {
      selectedCategoryIds = [categoryId];
      // }
    }

    onFilter(categoryId: selectedCategoryIds);
  }

  Widget renderProductsLayout({
    List<Product>? products,
    required bool isFetching,
    String? errMsg,
    bool? isEnd,
    double? width,
    required String layout,
  });

  ExpandingBottomSheet? renderBottomSheet() {
    final isOnlyListingType = productModel.productsList
        ?.every((product) => product.isListing == true) ??
        false;

    final enable = Services().widget.enableShoppingCart(null) &&
        !isOnlyListingType &&
        kAdvanceConfig.showBottomCornerCart;
    return enable
        ? ExpandingBottomSheet(
      hideController: filterController,
    )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppModel, String>(
      selector: (context, provider) => provider.productListLayout,
      builder: (context, productListLayout, child) {
        return ListenableProvider.value(
          value: productModel,
          child: Consumer<ProductModel>(
            builder: (context, model, child) {
              return renderProductsLayout(
                products: model.productsList,
                isFetching: model.isFetching,
                errMsg: model.errMsg,
                isEnd: model.isEnd,
                width: MediaQuery.sizeOf(context).width,
                layout: productListLayout,
              );
            },
          ),
        );
      },
    );
  }

  @override
  void onCategorySelected(String? name) {
    productModel.categoryName = name;
    _currentTitle =
    (name?.isNotEmpty ?? false) ? '$name' : S.of(context).results;
  }

  @override
  void rebuild() {
    setState(() {});
  }

  @override
  void onCloseFilter() {
    // Mark that filters have been applied
    _filtersApplied = true;
    
    // Close filters and reload products
    filterController.forward();
    
    // Reload products with current filters
    page = 1;
    clearProductList();
    unawaited(getProductList(forceLoad: true));
  }
}