import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:inspireui/inspireui.dart' show Skeleton;
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../common/extensions/extensions.dart';
import '../../../models/category/category_model.dart';
import '../../../models/index.dart' show BackDropArguments, Category;
import '../../../routes/flux_navigate.dart';
import '../../../widgets/common/index.dart';
import '../../../widgets/common/parallax_image.dart';
import '../../../widgets/common/refresh_scroll_physics.dart';
import '../../index.dart';

class CardCategories extends StatefulWidget {
  /// Not support enableLargeCategory
  static const String type = 'card';
  final bool enableParallax;
  final double? parallaxImageRatio;
  final ScrollController? scrollController;

  const CardCategories({
    required this.enableParallax,
    this.parallaxImageRatio,
    this.scrollController,
  });

  @override
  BaseScreen<CardCategories> createState() => _StateCardCategories();
}

class _StateCardCategories extends BaseScreen<CardCategories> {
  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();

  CategoryModel get categoryModel =>
      Provider.of<CategoryModel>(context, listen: false);

  bool hasChildren(id) {
    return categoryModel.categories!
        .where((o) => o.parent == id)
        .toList()
        .isNotEmpty;
  }

  List<Category> getSubCategories(id) {
    return categoryModel.getCategory(parentId: id) ?? <Category>[];
  }

  void navigateToBackDrop(Category category) {
    FluxNavigate.pushNamed(
      RouteList.filters,
      arguments: BackDropArguments(
        cateId: category.id,
        cateName: category.name,
        allowFilterMultipleCategory: false,
      ),
      context: context,
    );
  }

  ChildList getChildCategoryList(category) {
    return ChildList(
      children: [
        GestureDetector(
          onTap: () => navigateToBackDrop(category),
          child: SubItem(
            category,
            seeAll: S.of(context).seeAll,
          ),
        ),
        for (var category in getSubCategories(category.id))
          Parent(
            callback: (isSelected) {
              if (getSubCategories(category.id).isEmpty) {
                navigateToBackDrop(category);
              }
            },
            parent: SubItem(category),
            childList: ChildList(
              children: [
                for (var cate in getSubCategories(category.id))
                  Parent(
                    callback: (isSelected) {
                      if (getSubCategories(cate.id).isEmpty) {
                        FluxNavigate.pushNamed(
                          RouteList.filters,
                          arguments: BackDropArguments(
                            cateId: cate.id,
                            cateName: cate.name,
                            allowFilterMultipleCategory: false,
                          ),
                          context: context,
                        );
                      }
                    },
                    parent: SubItem(cate, level: 1),
                    childList: ChildList(
                      children: [
                        for (var cate in getSubCategories(cate.id))
                          Parent(
                            callback: (isSelected) {
                              FluxNavigate.pushNamed(
                                RouteList.filters,
                                arguments: BackDropArguments(
                                  cateId: cate.id,
                                  cateName: cate.name,
                                  allowFilterMultipleCategory: false,
                                ),
                                context: context,
                              );
                            },
                            parent: SubItem(cate, level: 2),
                            childList: const ChildList(children: []),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kEnableLargeCategories) {
      return PagingList<CategoryModel, Category>(
        lengthLoadingWidget: 6,
        loadingWidget: const _CardSkeleton(),
        itemBuilder: (_, category, index) {
          return _CategoryCardItem(
            category,
            onTap: () {
              if (category.hasChildren ?? false) {
                FluxNavigate.pushNamed(
                  RouteList.subCategories,
                  arguments: SubcategoryArguments(
                    parentId: category.id!.toString(),
                    categoryName: category.name,
                    allowFilterMultipleCategory: false,
                  ),
                  context: context,
                );
                return;
              }
              FluxNavigate.pushNamed(
                RouteList.filters,
                arguments: BackDropArguments(
                  cateId: category.id,
                  cateName: category.name,
                  allowFilterMultipleCategory: false,
                ),
                context: context,
              );
            },
            enableParallax: widget.enableParallax,
            parallaxImageRatio: widget.parallaxImageRatio,
          );
        },
      );
    }

    return Consumer<CategoryModel>(
      builder: (context, provider, child) {
        if (provider.isFirstLoad) {
          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            physics: const RefreshScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (_, __) => const _CardSkeleton(),
            itemCount: 8,
          );
        }

        var categories = provider.rootCategories ?? <Category>[];
        if (categories.isEmpty) {
          categories = provider.categories!;
        }

        if (categories.isEmpty) {
          return Center(
            child: Text(S.of(context).noData),
          );
        }

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          physics: const RefreshScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            childAspectRatio: 0.85,
          ),
          itemCount: categories.length,
          itemBuilder: (_, index) {
            final category = categories[index];
            return _CategoryCardItem(
                category,
                onTap: hasChildren(category.id)
                  ? () {
                FluxNavigate.pushNamed(
                  RouteList.subCategories,
                  arguments: SubcategoryArguments(
                    parentId: category.id!.toString(),
                    categoryName: category.name,
                    allowFilterMultipleCategory: false,
                  ),
                  context: context,
                );
              }
                    : () {
                  FluxNavigate.pushNamed(
                    RouteList.backdrop,
                    arguments: BackDropArguments(
                      cateId: category.id,
                      cateName: category.name,
                      allowFilterMultipleCategory: false,
                    ),
                    context: context,
                  );
                },
                enableParallax: widget.enableParallax,
                parallaxImageRatio: widget.parallaxImageRatio,
            );
          },
        );
      },
    );
  }
}

class _CategoryCardItem extends StatelessWidget {
  final Category category;
  final bool enableParallax;
  final double? parallaxImageRatio;
  final VoidCallback? onTap;

  const _CategoryCardItem(
      this.category, {
        this.enableParallax = false,
        this.parallaxImageRatio,
        this.onTap,
      });

  /// Render category Image support caching on ios/android
  /// also fix loading on Web
  Widget renderCategoryImage(maxWidth) {
    final image = category.image ?? '';
    if (image.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }
    var imageProxy = '';

    if (kImageProxy.isNotEmpty) {
      imageProxy = '$kImageProxy${maxWidth}x,q30/';
    }

    var urlProxy = '$imageProxy$image';

    if (Configurations.webProxy.isNotEmpty && imageProxy.isEmpty) {
      urlProxy = image.addWebProxy();
    }

    if (image.isURL && kIsWeb) {
      return FadeInImage.memoryNetwork(
        image: urlProxy,
        fit: BoxFit.contain,
        width: maxWidth * 0.45,
        height: maxWidth * 0.45,
        placeholder: kTransparentImage,
      );
    }

    return FluxImage(
      imageUrl: category.image!,
      fit: BoxFit.contain,
      width: maxWidth * 0.45,
      height: maxWidth * 0.45,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (enableParallax) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: constraints.maxWidth * 0.5,
                      width: constraints.maxWidth * 0.5,
                      child: ParallaxImage(
                        image: category.image ?? '',
                        name: category.name ?? '',
                        ratio: 2.2,
                        width: constraints.maxWidth * 0.5,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category.name?.toUpperCase() ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBD38D),
              borderRadius: BorderRadius.circular(12),
            ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                      child: renderCategoryImage(constraints.maxWidth),
                    ),
                    ),
                  ),
                  ),
                const SizedBox(height: 12),
                Text(
                      category.name ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                    fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                ],
            ),
          );
        },
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBD38D),
            borderRadius: BorderRadius.circular(12),
          ),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Expanded(
                child: Skeleton(
                  width: double.infinity,
                  height: double.infinity,
                ),
                ),
              const SizedBox(height: 12),
                Skeleton(
                width: constraints.maxWidth * 0.7,
                height: 16,
                ),
              ],
          ),
        );
      },
    );
  }
}

class SubItem extends StatelessWidget {
  final Category category;
  final String seeAll;
  final int level;

  const SubItem(this.category, {this.seeAll = '', this.level = 0});

  void showProductList(BuildContext context) {
    FluxNavigate.pushNamed(
      RouteList.filters,
      arguments: BackDropArguments(
        cateId: category.id,
        cateName: category.name,
        allowFilterMultipleCategory: false,
      ),
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return SizedBox(
      width: screenSize.width,
      child: FittedBox(
        fit: BoxFit.cover,
        child: Container(
          width:
          screenSize.width / (2 / (screenSize.height / screenSize.width)),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                width: 0.5,
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValueOpacity(level == 0 && seeAll == '' ? 0.2 : 0),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 5),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 15.0),
              for (int i = 1; i <= level; i++)
                Container(
                  width: 10.0,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 1.5,
                        color: Theme.of(context)
                            .primaryColor
                            .withValueOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  seeAll != '' ? seeAll : category.name!,
                  style: const TextStyle(
                    fontSize: 17,
                  ),
                ),
              ),
              if ((category.totalProduct ?? 0) > 0)
                GestureDetector(
                  onTap: () => showProductList(context),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                    child: Text(
                      S.of(context).nItems(category.totalProduct.toString()),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_right),
                onPressed: () => showProductList(context),
              )
            ],
          ),
        ),
      ),
    );
  }
}