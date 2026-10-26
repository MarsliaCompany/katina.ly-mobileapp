import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';

import '../common/constants.dart';
import '../services/services.dart';
import 'entities/blog.dart';
import 'entities/category.dart';
import 'entities/tag.dart';

class BlogModel with ChangeNotifier {
  List<Blog>? blogList = [];

  final _service = Services();
  CancelableOperation<List<Blog>>? _cancelLoadBlogs;
  static const Duration _kBackgroundSyncTimeout = Duration(seconds: 3);

  bool isFetching = false;
  bool? isEnd;
  List<String>? categoryIds;
  String? categoryName;
  List<String>? tagIds;
  String? errMsg;

  List<Category> _categories = [];

  List<Category> get categories => _categories;

  List<Tag> _tags = [];

  List<Tag> get tags => _tags;

  Future<void> init({
    String? name,
    List<String>? category,
    List<Blog>? blogs,
  }) async {
    await _cancelLoadBlogs?.cancel();
    blogList = blogs ?? [];
    isFetching = false;
    isEnd = false;
    categoryName = name;
    categoryIds = category;
    notifyListeners();
  }

  Future<void> onFilter({
    List<String>? categoryIds,
    String? categoryName,
    List<String>? tagIds,
    String? orderBy,
    String? order,
    String? lang,
    bool? boostEngine,
  }) async {
    blogList = <Blog>[];
    notifyListeners();
    await getBlogsList(
      categoryIds: categoryIds,
      categoryName: categoryName,
      tagIds: tagIds,
      order: order,
      orderBy: orderBy,
      lang: lang,
      boostEngine: boostEngine,
    );
  }

  Future<void> getBlogsList({
    List<String>? categoryIds,
    String? categoryName,
    List<String>? tagIds,
    String? orderBy,
    String? order,
    String? lang,
    int page = 1,
    bool? boostEngine,
    String? search,
    String? author,
    List<String>? include,
  }) async {
    try {
      if (categoryIds?.isNotEmpty ?? false) {
        this.categoryIds = categoryIds;
        if (categoryName != null && categoryName.isNotEmpty) {
          this.categoryName = categoryName;
        }
      } else {
        categoryIds = null;
        this.categoryName = categoryName;
      }

      if (tagIds?.isNotEmpty ?? false) {
        this.tagIds = tagIds;
      }

      printLog('[♻️ getBlogsList] by Category: $categoryIds and Tag: $tagIds');

      await _cancelLoadBlogs?.cancel();
      isFetching = true;
      isEnd = false;
      notifyListeners();
      final fetchFuture = _service.api.fetchBlogsByCategory(
        categoryId: categoryIds?.join(','),
        tagId: tagIds?.join(','),
        page: page,
        order: order,
        orderBy: orderBy,
        boostEngine: boostEngine,
        search: search,
        author: author,
        include: include,
      );

      final bool hasCachedFirstPage =
          (blogList?.isNotEmpty ?? false) && (page == 0 || page == 1);
      final guardedFuture = hasCachedFirstPage
          ? fetchFuture.timeout(_kBackgroundSyncTimeout)
          : fetchFuture;

      _cancelLoadBlogs = CancelableOperation.fromFuture(guardedFuture);
      final blogs = await _cancelLoadBlogs?.value;
      if (blogs != null) {
        if (blogs.isEmpty) {
          isEnd = true;
        }

        if (page == 0 || page == 1) {
          blogList = blogs;
        } else {
          blogList = [...blogList!, ...blogs];
        }
      }
      isFetching = false;
      notifyListeners();
    } on TimeoutException catch (err, trace) {
      errMsg = err.toString();
      printError(err, trace);
      isFetching = false;
      notifyListeners();
    } catch (err, trace) {
      errMsg = err.toString();
      isFetching = false;
      printError(err, trace);
      notifyListeners();
    }
  }

  Future<List<Category>> getCategoryList() async {
    _categories = await _service.api.getBlogCategories();
    notifyListeners();
    return _categories;
  }

  Future<List<Tag>> getTagList() async {
    _tags = await _service.api.getBlogTags();
    notifyListeners();
    return _tags;
  }

  @override
  void dispose() {
    _cancelLoadBlogs?.cancel();
    super.dispose();
  }
}
