import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../app.dart';
import '../common/config.dart';
import '../common/constants.dart';
import '../common/tools.dart';
import '../data/local_sync_repository.dart';
import '../frameworks/woocommerce/services/woocommerce_api.dart';
import '../routes/flux_navigate.dart';
import '../services/index.dart';
import 'entities/back_drop_arguments.dart';
import 'entities/brand.dart';
import 'entities/filter_attribute.dart';
import 'entities/product.dart';
import 'entities/product_variation.dart';

class ProductModel with ChangeNotifier {
  final Services _service = Services();
  final LocalSyncRepository _localSyncRepository = LocalSyncRepository();
  _PendingProductsUpdate? _pendingProductsUpdate;
  List<List<Product?>> products = [];
  String? message;

  /// current select product id/name
  List<String>? categoryIds;
  List<String>? brandIds;
  String? listingLocationId;
  String? categoryName;
  List<String>? tagIds;
  String? search;
  Map<String, dynamic>? _attributeFilters;

  // list products for products screen
  bool isFetching = false;
  List<Product>? productsList;
  String? errMsg;
  bool? isEnd;

  // Separate recent searches for products and listings
  List<Product>? _recentProductSearch;
  List<Product>? _recentListingSearch;

  List<Product>? get recentSearch {
    if (_isListingOnly) return _recentListingSearch;
    if (_isListeoWithDokan) {
      return productType ? _recentProductSearch : _recentListingSearch;
    }

    return _recentProductSearch;
  }

  set recentSearch(List<Product>? value) {
    if (_isListingOnly) {
      _recentListingSearch = value;
    } else if (_isListeoWithDokan) {
      productType ? _recentProductSearch = value : _recentListingSearch = value;
    } else {
      _recentProductSearch = value;
    }
    notifyListeners();
  }

  List<ProductVariation> variations = [];
  List<String> variationsFeatureImages = [];
  ProductVariation? selectedVariation;
  List<Product>? lstGroupedProduct;
  String? cardPriceRange;
  String detailPriceRange = '';
  bool _isLoading = false;

  // determine the Product type or Listing type
  bool productType = false;

  bool get isLoading => _isLoading;

  CancelableOperation? _cancelLoadProduct;

  bool get _isListingOnly => ServerConfig().isListingSingleApp;
  bool get _isListeoWithDokan =>
      ServerConfig().isListeoType && ServerConfig().multiVendorType == 'dokan';
  bool get _isVendorType => ServerConfig().isVendorType();
  static const Duration _kBackgroundSyncTimeout = Duration(seconds: 3);

  void clearProductVariations() {
    variations.clear();
    variationsFeatureImages = [];
    selectedVariation = null;
    notifyListeners();
  }

  void changeSelectedVariation(ProductVariation? variation) {
    selectedVariation = variation;

    if (kProductDetail.showSelectedImageVariant) {
      eventBus.fire(EventChangeSelectedVariation(variation));
    }
    notifyListeners();
  }

  void changeProductVariations(
    List<ProductVariation> newVariations, {
    bool notify = true,
  }) {
    variationsFeatureImages = [];
    variations.clear();
    variations.addAll(newVariations);
    variationsFeatureImages
        .addAll(variations.map((e) => e.imageFeature).whereType<String>());
    if (notify) {
      notifyListeners();
    }
  }

  void setCategoryName(String? name) {
    categoryName = name;
  }

  Future<List<Product>?> fetchGroupedProducts(
      {required Product product}) async {
    lstGroupedProduct = [];
    if (product.groupedProducts == null) {
      return lstGroupedProduct;
    }

    for (var productID in product.groupedProducts as Iterable<int>) {
      // Load product instead of listing if it is listing app
      await _service.api.overrideGetProduct(productID)!.then((product) {
        if (product != null) {
          lstGroupedProduct!.add(product);
        }
      });
    }
    return lstGroupedProduct;
  }

  void changeDetailPriceRange(String? currency, Map<String, dynamic> rates) {
    if (lstGroupedProduct!.isNotEmpty) {
      var currentPrice = double.parse(lstGroupedProduct![0].price!);
      var max = currentPrice;
      var min = 0;
      for (var product in lstGroupedProduct!) {
        min = double.parse(product.price!).toInt();
        if (min > max) {
          var temp = min;
          max = min.toDouble();
          min = temp;
        }
        detailPriceRange = currentPrice != max
            ? '${PriceTools.getCurrencyFormatted(currentPrice, rates, currency: currency)} - ${PriceTools.getCurrencyFormatted(max, rates, currency: currency)}'
            : PriceTools.getCurrencyFormatted(currentPrice, rates,
                    currency: currency)
                .toString();
      }
    }
  }

  Future<List<Product>?> fetchProductLayout(config, lang, {userId}) async {
    return _service.api.fetchProductsLayout(config: config, userId: userId);
  }

  void fetchProductsByCategory({
    List<String>? categoryId,
    List<String>? brandIds,
    categoryName,
    List<String>? tagId,
    listingLocationId,
    bool notify = true,
    bool productType = false,
  }) {
    categoryIds = categoryId;
    this.brandIds = brandIds ?? this.brandIds;
    this.categoryName = categoryName;
    tagIds = tagId;
    this.listingLocationId = listingLocationId;
    this.productType = productType;
    if (notify) notifyListeners();
  }

  void updateTagId({List<String>? tagId, bool notify = true}) {
    tagIds = tagId;
    if (notify) notifyListeners();
  }

  void setAttributeFilters(
    Map<FilterAttribute, List<SubAttribute>>? attributes, {
    bool notify = false,
  }) {
    if (attributes == null || attributes.isEmpty) {
      _attributeFilters = null;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    final payload = <String, dynamic>{};
    attributes.forEach((attribute, subs) {
      final normalizedSlug = _normalizeAttributeSlug(attribute);
      final termIds = subs
          .map((sub) => sub.id?.toString())
          .whereType<String>()
          .toList();
      if (normalizedSlug != null && termIds.isNotEmpty) {
        payload[normalizedSlug] =
            termIds.length == 1 ? termIds.first : termIds;
      }
    });
    _attributeFilters = payload.isEmpty ? null : payload;
    if (notify) {
      notifyListeners();
    }
  }

  String? _normalizeAttributeSlug(FilterAttribute attribute) {
    final slug = attribute.slug;
    if (slug != null && slug.isNotEmpty) {
      return slug.startsWith('pa_') ? slug : 'pa_${slug.replaceFirst('pa_', '')}';
    }
    final id = attribute.id;
    if (id != null) {
      return 'pa_$id';
    }
    return null;
  }

  Future<void> getProductsList({
    bool? boostEngine,
    List<String>? categoryId,
    minPrice,
    maxPrice,
    orderBy,
    order,
    List<String>? tagId,
    lang,
    required page,
    featured,
    onSale,
    listingLocation,
    userId,
    List? include,
    String? search,
    List<String>? brandIds,
    Map? attributes,
  }) async {
    try {
      if (isFetching) {
        await _cancelLoadProduct?.cancel();
      }

      isFetching = true;

      categoryIds = categoryId;
      this.search = search;
      tagIds = tagId;
      this.brandIds = brandIds;
      listingLocationId = listingLocation;
      isEnd = false;
      notifyListeners();
      String? cursor;
      if (ServerConfig().isNotion && (productsList?.isNotEmpty ?? false)) {
        if (page == 1) {
          cursor = null;
        } else {
          cursor = productsList!.last.id;
        }
      }

      final combinedAttributes = _normalizeAttributes(attributes);
      final normalizedPage = _normalizePage(page);
      final isFirstPage = normalizedPage <= 1;
      final cacheKey = isFirstPage
          ? _buildProductsCacheKey(
              categories: categoryId,
              tags: tagId,
              brands: brandIds,
              includes: include,
              search: search,
              attributes: combinedAttributes,
              orderBy: orderBy?.toString(),
              order: order?.toString(),
              listingLocation: listingLocation?.toString(),
              minPrice: _asNum(minPrice),
              maxPrice: _asNum(maxPrice),
              featured: _asBool(featured),
              onSale: _asBool(onSale),
              page: normalizedPage,
            )
          : null;
      _pendingProductsUpdate = null;

      SyncSnapshot<List<Product>>? snapshot;
      if (cacheKey != null) {
        snapshot = _localSyncRepository.readSnapshot<List<Product>>(
          cacheKey,
          _deserializeProductsSnapshot,
        );
        if (snapshot != null) {
          productsList = snapshot.data;
          isEnd = snapshot.data.isEmpty;
          errMsg = null;
          notifyListeners();
        }
      }

      printLog('[ProductModel] Fetching products with filters -> '
          'categoryId=$categoryId, tagId=$tagId, brandIds=$brandIds, '
          'attributes=$combinedAttributes');

      String? latestFingerprint;
      final fetchFuture = _service.api.fetchProductsByCategory(
        categoryId: categoryId?.join(','),
        tagId: tagId?.join(','),
        minPrice: minPrice,
        maxPrice: maxPrice,
        orderBy: orderBy,
        order: order,
        page: page,
        featured: featured,
        onSale: onSale,
        listingLocation: listingLocation,
        userId: userId,
        nextCursor: cursor,
        include: include?.join(','),
        search: search,
        productType: productType,
        boostEngine: boostEngine,
        brandIds: brandIds,
        attributes: combinedAttributes,
        expectedFingerprint: snapshot?.fingerprint,
        onFingerprint: (fingerprint) => latestFingerprint = fingerprint,
      );

      _cancelLoadProduct = CancelableOperation.fromFuture(
        snapshot != null
            ? fetchFuture.timeout(_kBackgroundSyncTimeout)
            : fetchFuture,
      );

      List<Product>? products;
      try {
        products = await _cancelLoadProduct!.value;
      } on CacheHitException {
        isFetching = false;
        errMsg = null;
        notifyListeners();
        return;
      } on TimeoutException catch (err, trace) {
        printError(err, trace);
        isFetching = false;
        errMsg = null;
        notifyListeners();
        return;
      }

      products ??= <Product>[];

      if (cacheKey != null && (latestFingerprint?.isNotEmpty ?? false)) {
        await _localSyncRepository.writeSnapshot(
          cacheKey,
          products.map((e) => e.toJson()).toList(),
          fingerprint: latestFingerprint!,
        );
      }

      if (snapshot != null && isFirstPage) {
        _pendingProductsUpdate = _PendingProductsUpdate(
          products: products,
          page: normalizedPage,
          search: search,
        );
        isFetching = false;
        errMsg = null;
        notifyListeners();
        _showBackgroundUpdateSnackBar();
      } else {
        _setProductsResult(products, normalizedPage, search: search);
        isFetching = false;
        errMsg = null;
        notifyListeners();
      }
    } catch (err, trace) {
      errMsg =
          'There is an issue with the app during request the data, please contact admin for fixing the issues $err';
      isFetching = false;
      printError(err, trace);
      notifyListeners();
    }
  }

  void _setProductsResult(
    List<Product> products,
    int page, {
    String? search,
  }) {
    isEnd = products.isEmpty;
    if (page <= 1) {
      productsList = products;
    } else {
      final current = productsList ?? <Product>[];
      productsList = [...current, ...products];
    }
    _updateRecentSearchCaches(search);
  }

  void _updateRecentSearchCaches(String? searchInput) {
    if (!(searchInput?.isNotEmpty ?? false)) {
      return;
    }
    if (_isListingOnly) {
      _recentListingSearch = productsList;
    } else if (_isListeoWithDokan) {
      productType
          ? _recentProductSearch = productsList
          : _recentListingSearch = productsList;
    } else {
      _recentProductSearch = productsList;
      if (!productType && _isVendorType) {
        _recentListingSearch = _recentProductSearch;
      }
    }
  }

  void _showBackgroundUpdateSnackBar() {
    final context = App.fluxStoreNavigatorKey.currentContext;
    if (_pendingProductsUpdate == null) {
      return;
    }
    if (context == null) {
      _applyPendingProductsUpdate();
      return;
    }
    showKatinaUpdateSnackBar(context, _applyPendingProductsUpdate);
  }

  void _applyPendingProductsUpdate() {
    final payload = _pendingProductsUpdate;
    if (payload == null) {
      return;
    }
    _setProductsResult(payload.products, payload.page, search: payload.search);
    _pendingProductsUpdate = null;
    notifyListeners();
  }

  String _buildProductsCacheKey({
    List<String>? categories,
    List<String>? tags,
    List<String>? brands,
    List? includes,
    String? search,
    Map<String, dynamic>? attributes,
    String? orderBy,
    String? order,
    String? listingLocation,
    num? minPrice,
    num? maxPrice,
    bool? featured,
    bool? onSale,
    int? page,
  }) {
    return LocalSyncKeys.products(
      categories: categories,
      tags: tags,
      brands: brands,
      includes: includes?.map((e) => e.toString()).toList(),
      search: search,
      attributes: attributes,
      orderBy: orderBy,
      order: order,
      listingLocation: listingLocation,
      minPrice: minPrice,
      maxPrice: maxPrice,
      featured: featured,
      onSale: onSale,
      page: page?.toString(),
    );
  }

  List<Product> _deserializeProductsSnapshot(dynamic raw) {
    if (raw is! List) {
      return <Product>[];
    }
    final result = <Product>[];
    for (final item in raw) {
      if (item is Map) {
        result.add(Product.fromLocalJson(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  Map<String, dynamic>? _normalizeAttributes(Map? attributes) {
    if (_attributeFilters != null) {
      return Map<String, dynamic>.from(_attributeFilters!);
    }
    if (attributes == null) {
      return null;
    }
    return Map<String, dynamic>.from(attributes as Map);
  }

  int _normalizePage(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 1;
    }
    return 1;
  }

  num? _asNum(dynamic value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  bool? _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  void setProductsList(List<Product> products, {bool notify = true}) {
    if (products.isNotEmpty) {
      isFetching = false;
    }
    productsList = products;
    isEnd = false;
    if (notify) notifyListeners();
  }

  Future<void> createProduct(
      List galleryImages,
      List<File> fileImages,
      String? cookie,
      String nameProduct,
      String? type,
      String? idCategory,
      double? salePrice,
      double regularPrice,
      String description,
      List<Map<String, dynamic>> metaData) async {
    Future uploadImage() async {
      try {
        if (fileImages.isNotEmpty) {
          for (var i = 0; i < fileImages.length; i++) {
            printLog('path ${path.basename(fileImages[i].path)}');
            await _service.api.uploadImage({
              'title': {'rendered': path.basename(fileImages[i].path)},
              'media_attachment': base64.encode(fileImages[i].readAsBytesSync())
            }, cookie)!.then((photo) {
              galleryImages.add('${photo['id']}');
            });
          }
        } else {
          return;
        }
      } catch (e) {
        rethrow;
      }
    }

    await uploadImage().then((_) async {
      var regularPriceMeta =
          metaData.firstWhereOrNull((e) => e['key'] == '_regular_price');
      await _service.api.createProduct(cookie, {
        'title': nameProduct,
        'product_type': type,
        'content': description,
        'regular_price':
            regularPriceMeta != null ? regularPriceMeta['value'] : regularPrice,
        'sale_price': salePrice,
        'image_ids': galleryImages,
        'categories': [
          {'id': idCategory}
        ],
        'status': kNewProductStatus,
        'meta_data': metaData
      });
    });
  }

  Future<void> deleteProduct({
    required String? productId,
    required String? cookie,
  }) async {
    _isLoading = true;
    notifyListeners();
    await _service.api.deleteProduct(cookie: cookie, productId: productId);
    _isLoading = false;
    notifyListeners();
  }

  /// Show the product list
  static Future showList({
    cateId,
    cateName,
    String? tag,
    List<Product>? products,
    Map<String, dynamic>? config,
    bool showCountdown = false,
    Duration countdownDuration = Duration.zero,
    Brand? brandByParams,
    required BuildContext context,
  }) async {
    try {
      await FluxNavigate.pushNamed(
        RouteList.backdrop,
        context: context,
        arguments: BackDropArguments(
          config: config,
          data: products ?? [],
          showCountdown: showCountdown,
          countdownDuration: countdownDuration,
          cateId: cateId,
          brandName: brandByParams?.name,
          brandId: brandByParams?.id,
          brandImg: brandByParams?.image,
          cateName: cateName,
          tag: tag,
        ),
      );
    } catch (e, trace) {
      printLog(e.toString());
      printLog(trace.toString());
    }
  }

  /// parse product from json
  static List<Product> parseProductList(
      List? response, Map<String, dynamic> config) {
    var list = <Product>[];

    if (response != null) {
      var products = [];

      /// sort include product
      var include = config['include'];
      if (include != null && include is List) {
        for (var productID in include) {
          var item = response.firstWhereOrNull(
              (element) => element['id'].toString() == productID.toString());
          if (item != null) {
            products.add(item);
          }
        }
      } else {
        products = response;
      }
      for (var item in products) {
        /// ignore the hidden catalog
        if (item['catalog_visibility'] == 'hidden') {
          continue;
        }

        var product = Product.fromJson(item);

        if ((kAdvanceConfig.hideOutOfStock) &&
            !product.inStock! &&
            !product.backordersAllowed) {
          /// hideOutOfStock product
          continue;
        }

        if (config['category'] != null &&
            config['category'].toString().isNotEmpty) {
          product.categoryId = config['category'].toString();
        }
        if (item['store'] != null) {
          if (item['store']['errors'] != null) {
            list.add(product);
            continue;
          }
          product = Services().widget.updateProductObject(product, item);
        }
        list.add(product);
      }
    }
    return list;
  }
}

class _PendingProductsUpdate {
  final List<Product> products;
  final int page;
  final String? search;

  const _PendingProductsUpdate({
    required this.products,
    required this.page,
    this.search,
  });
}
