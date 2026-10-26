import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../common/config.dart';
import '../common/constants.dart';
import '../common/tools.dart';
import '../data/local_sync_repository.dart';
import '../frameworks/woocommerce/services/woocommerce_api.dart';
import '../services/index.dart';
import 'entities/filter_attribute.dart';
import 'entities/hierarchical_attribute.dart';
import 'mixins/language_mixin.dart';

class FilterAttributeModel with ChangeNotifier, LanguageMixin {
  final Services _service = Services();
  static const int _rootParentKey = -1;
  static const Duration _kBackgroundSyncTimeout = Duration(seconds: 3);
  final LocalSyncRepository _localSyncRepository = LocalSyncRepository();
  _PendingAttributesUpdate? _pendingAttributesUpdate;

  /// List all attributes
  List<FilterAttribute>? lstProductAttribute;

  final Set<int> _hierarchyChildIds = {};

  Iterable<FilterAttribute>? get listVisibleAttribute {
    final visible =
        lstProductAttribute?.where((element) => element.isVisible);
    if (!(hierarchicalAttributes?.isNotEmpty ?? false)) {
      return visible;
    }
    return visible?.where((attr) {
      final id = attr.id;
      if (id == null) {
        return true;
      }
      return !_hierarchyChildIds.contains(id);
    });
  }

  /// List all sub attributes of each attribute by id
  Map<int, List<SubAttribute>> lstSubAttribute = {};

  /// Current status of each attribute by id
  Map<int, bool> isEndSub = {};

  /// Current loading status of each attribute by id
  Map<int, bool> isLoadingSub = {};

  /// Current pages of each attribute by id
  Map<int, int> currentPages = {};

  /// Loading status of all attributes
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<HierarchicalAttribute>? hierarchicalAttributes;
  final Map<int, List<HierarchicalAttribute>> _childrenCache = {};
  final Map<int, Future<List<HierarchicalAttribute>>> _pendingChildRequests = {};
  final Set<int> _loadingParents = {};
  bool _isLoadingHierarchy = false;
  bool get isLoadingHierarchy => _isLoadingHierarchy;
  bool get hasHierarchicalAttributes =>
      hierarchicalAttributes?.isNotEmpty ?? false;

  bool isParentLoading(int? parentId) =>
      _loadingParents.contains(_cacheKey(parentId));

  List<HierarchicalAttribute> getCachedChildren(int? parentId) =>
      _childrenCache[_cacheKey(parentId)] ?? const [];

  String? getAttributeName(int? attributeId, {String? lang}) {
    final attribute = lstProductAttribute
        ?.firstWhereOrNull((element) => element.id == attributeId);

    if (attribute == null) {
      return null;
    }

    if (lang == null || lang.isEmpty) {
      return attribute.name;
    }

    final overridedName = kProductVariantLanguage[lang]
            ?[attribute.name?.toLowerCase()]
        ?.toString();
    return overridedName ?? attribute.name;
  }

  Future<void> getFilterAttributes({
    String? categoryIds,
    String? tagIds,
    String? brandIds,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final cacheKey = _buildAttributesCacheKey(
        categoryIds: categoryIds,
        tagIds: tagIds,
        brandIds: brandIds,
      );

      _pendingAttributesUpdate = null;
      final snapshot = _localSyncRepository.readSnapshot<List<FilterAttribute>>(
        cacheKey,
        _deserializeAttributes,
      );

      if (snapshot != null) {
        lstProductAttribute = snapshot.data;
        notifyListeners();
      }

      String? latestFingerprint;
      final fetchFuture = _service.api.getFilterAttributes(
        categoryIds: categoryIds,
        tagIds: tagIds,
        brandIds: brandIds,
        expectedFingerprint: snapshot?.fingerprint,
        onFingerprint: (fingerprint) => latestFingerprint = fingerprint,
      );

      if (fetchFuture == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final futureWithTimeout = snapshot != null
          ? fetchFuture.timeout(_kBackgroundSyncTimeout)
          : fetchFuture;

      List<FilterAttribute>? attributes;
      try {
        attributes = await futureWithTimeout;
      } on CacheHitException {
        _isLoading = false;
        notifyListeners();
        return;
      } on TimeoutException catch (err, trace) {
        printError(err, trace);
        _isLoading = false;
        notifyListeners();
        return;
      }

      attributes ??= const [];

      if (latestFingerprint?.isNotEmpty ?? false) {
        await _localSyncRepository.writeSnapshot(
          cacheKey,
          attributes.map((e) => e.toJson()).toList(),
          fingerprint: latestFingerprint!,
        );
      }

      if (snapshot != null) {
        _pendingAttributesUpdate =
            _PendingAttributesUpdate(attributes: attributes);
        _isLoading = false;
        notifyListeners();
        _showBackgroundUpdateSnackBar();
      } else {
        lstProductAttribute = attributes;
        notifyListeners();
      }

      // Don't need to load sub attributes for WooCommerce base plugin because
      // we have customized the API response to return the sub attributes when
      // getting attribute data
      if (ServerConfig().isWooPluginSupported) {
        // Add sub attributes from subAttributes of each attribute in lstProductAttribute
        for (var item in lstProductAttribute ?? []) {
          if (item.id != null && item.subAttributes != null) {
            lstSubAttribute[item.id!] = item.subAttributes ?? [];
          }
        }
      } else if (lstProductAttribute != null) {
        final getSubAttributesFutures = <Future>[];
        for (var item in lstProductAttribute!) {
          getSubAttributesFutures.add(getSubAttributes(attributeId: item.id!));
        }
        await Future.wait(getSubAttributesFutures);
      }

      await loadHierarchicalAttributes();
    } catch (e, trace) {
      printError(e, trace);
    }
    _isLoading = false;
    notifyListeners();
  }

  List<FilterAttribute> _deserializeAttributes(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    final result = <FilterAttribute>[];
    for (final item in raw) {
      if (item is Map) {
        result.add(FilterAttribute.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  String _buildAttributesCacheKey({
    String? categoryIds,
    String? tagIds,
    String? brandIds,
  }) {
    return LocalSyncKeys.filterAttributes(
      categoryIds: categoryIds,
      tagIds: tagIds,
      brandIds: brandIds,
    );
  }

  void _showBackgroundUpdateSnackBar() {
    final context = App.fluxStoreNavigatorKey.currentContext;
    if (_pendingAttributesUpdate == null) {
      return;
    }
    if (context == null) {
      _applyPendingAttributesUpdate();
      return;
    }
    showKatinaUpdateSnackBar(context, _applyPendingAttributesUpdate);
  }

  void _applyPendingAttributesUpdate() {
    final payload = _pendingAttributesUpdate;
    if (payload == null) {
      return;
    }
    lstProductAttribute = payload.attributes;
    _pendingAttributesUpdate = null;
    notifyListeners();
  }

  Future<void> loadHierarchicalAttributes() async {
    if (_isLoadingHierarchy) {
      return;
    }
    try {
      _isLoadingHierarchy = true;
      notifyListeners();
      debugPrint('[HPA][Model] Loading root attributes...');
      await loadRootAttributes(forceRefresh: true);
    } finally {
      debugPrint('[HPA][Model] Finished root load, count=${hierarchicalAttributes?.length ?? 0}');
      _isLoadingHierarchy = false;
      notifyListeners();
    }
  }

  static const int _maxSubAttributePages = 50;

  Future<List<SubAttribute>?> getSubAttributes(
      {required int attributeId}) async {
    try {
      if (isEndSub[attributeId] == true ||
          isLoadingSub[attributeId] == true) {
        return lstSubAttribute[attributeId];
      } else {
        isLoadingSub[attributeId] = true;
        notifyListeners();
      }
      var fetchedPages = 0;
      var hasMore = true;
      var subAttributes = List<SubAttribute>.from(
        lstSubAttribute[attributeId] ?? const [],
      );

      while (hasMore && fetchedPages < _maxSubAttributePages) {
        fetchedPages += 1;
        final page =
            currentPages[attributeId] = (currentPages[attributeId] ?? 0) + 1;
        final data = (await _service.api.getSubAttributes(
              id: attributeId,
              page: page,
              perPage: apiPageSize,
            )) ??
            <SubAttribute>[];

        if (data.isEmpty) {
          isEndSub[attributeId] = true;
          break;
        }

        subAttributes.addAll(data);
        hasMore = data.length >= apiPageSize;
        if (!hasMore) {
          isEndSub[attributeId] = true;
        }
      }

      lstSubAttribute.update(
        attributeId,
        (value) => subAttributes,
        ifAbsent: () => subAttributes,
      );

      final subAttributeIds = subAttributes
          .map((e) => e.id)
          .toSet()
          .toList()
          .where((e) => e != null)
          .toList(); // Get distinct list id and remove null id

      lstSubAttribute[attributeId]
          ?.retainWhere((element) => subAttributeIds.remove(element.id));

      isLoadingSub[attributeId] = false;
      notifyListeners();

      return lstSubAttribute[attributeId];
    } catch (e, trace) {
      printError(e, trace);
    }
    isLoadingSub[attributeId] = false;
    notifyListeners();
    return lstSubAttribute[attributeId];
  }

  Future<List<HierarchicalAttribute>> loadRootAttributes(
          {bool forceRefresh = false}) =>
      loadChildren(null, forceRefresh: forceRefresh);

  Future<List<HierarchicalAttribute>> loadChildren(
    int? parentId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(parentId);

    if (forceRefresh) {
      _childrenCache.remove(cacheKey);
    }

    if (_childrenCache.containsKey(cacheKey)) {
      return _childrenCache[cacheKey]!;
    }

    if (_pendingChildRequests.containsKey(cacheKey)) {
      return _pendingChildRequests[cacheKey]!;
    }

    final completer = _fetchChildren(parentId, cacheKey);
    _pendingChildRequests[cacheKey] = completer;
    return completer;
  }

  Future<List<HierarchicalAttribute>> _fetchChildren(
      int? parentId, int cacheKey) async {
    try {
      _loadingParents.add(cacheKey);
      notifyListeners();
      debugPrint('[HPA][Model] Fetching children for parent=${parentId ?? 'root'}');
      final data =
          await _service.getHierarchicalAttributes(parentId: parentId) ?? [];
      debugPrint('[HPA][Model] Received ${data.length} nodes for parent=${parentId ?? 'root'}');

      if (parentId == null) {
        hierarchicalAttributes = data;
      } else if (data.isNotEmpty) {
        _hierarchyChildIds.addAll(data.map((node) => node.id));
      }

      _childrenCache[cacheKey] = data;
      _logHierarchySnapshot(data,
          depth: parentId == null ? 0 : parentId.toString().length);
      return data;
    } catch (e, trace) {
      printError(e, trace);
      return [];
    } finally {
      _loadingParents.remove(cacheKey);
      _pendingChildRequests.remove(cacheKey);
      notifyListeners();
    }
  }

  void resetHierarchyCaches() {
    _childrenCache.clear();
    _pendingChildRequests.clear();
    _loadingParents.clear();
    _hierarchyChildIds.clear();
    hierarchicalAttributes = null;
    notifyListeners();
  }

  int _cacheKey(int? parentId) => parentId ?? _rootParentKey;

  void _logHierarchySnapshot(List<HierarchicalAttribute> nodes,
      {int depth = 0}) {
    for (final node in nodes) {
      final indent = ''.padLeft(depth * 2, '-');
      debugPrint(
        '[Hierarchy]$indent Node ID=${node.id}, parents=${node.parentIds.isEmpty ? '[root]' : node.parentIds}, children=${node.children.length}',
      );
    }
  }
}

class _PendingAttributesUpdate {
  final List<FilterAttribute> attributes;

  const _PendingAttributesUpdate({
    required this.attributes,
  });
}

