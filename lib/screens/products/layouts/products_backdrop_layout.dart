import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:flux_ui/flux_ui.dart';

import '../../../common/constants.dart';
import '../../../models/entities/product.dart';
import '../../../routes/flux_navigate.dart';
import '../../../widgets/asymmetric/asymmetric_view.dart';
import '../../../widgets/backdrop/backdrop.dart';
import '../../../../widgets/backdrop/filter.dart';
import '../../../widgets/product/product_list.dart';
import '../filter_mixin/products_filter_mixin.dart';
import '../products_backdrop.dart';
import '../widgets/category_menu.dart';
import 'products_layout.dart';
import '../../../../widgets/backdrop/new_filter_system.dart';
import '../../../../models/filters/new_attribute_system.dart';
import 'package:provider/provider.dart';

class ProductsBackdropLayout extends ProductsLayout {
  const ProductsBackdropLayout({
    super.key,
    super.products,
    super.config,
    super.countdownDuration,
    super.autoFocusSearch,
  });

  @override
  StateProductsBackdropLayout createState() => StateProductsBackdropLayout();
}

class StateProductsBackdropLayout
    extends StateProductLayout<ProductsBackdropLayout> {
  @override
  Widget renderProductsLayout({
    List<Product>? products,
    required bool isFetching,
    String? errMsg,
    bool? isEnd,
    double? width,
    required String layout,
  }) {
    // Check if filters are applied and no products found
    final hasNoProducts = filtersApplied && 
        !isFetching && 
        (products == null || products.isEmpty) && 
        errMsg == null;

    // Show products if filters are applied OR if products are available
    final shouldShowProducts = filtersApplied ||
        (products != null && products.isNotEmpty) ||
        isFetching ||
        errMsg != null;

    return renderScaffold(
      routeName: RouteList.backdrop,
      resizeToAvoidBottomInset: false,
      disableSafeArea: true,
      child: ChangeNotifierProvider<NewAttributeFilterSystem>(
        create: (_) => NewAttributeFilterSystem()..fetchAttributes(),
        child: Builder(
          builder: (providerContext) {
            Future<void> applyHierarchicalFilter(
              Map<String, dynamic> payload,
            ) async {
              final selections = (payload['attributeSelections'] as List?)
                  ?.whereType<Map>()
                  .toList();

              if (selections == null || selections.isEmpty) {
                // No selection -> do nothing
                return;
              }

              await filterAttrModel.getFilterAttributes(
                categoryIds: categoryIds?.join(','),
                brandIds: brandIds?.join(','),
              );

              onFilter(
                attributeSelections: selections,
                categoryId: categoryIds,
                tagId: tagIds,
                brandIds: brandIds,
                listingLocationId: listingLocationId,
              );

              // Close filter layer and show products
              if (filterController.status != AnimationStatus.completed) {
                filterController.forward();
              }
            }

            return ProductBackdrop(
              backdrop: Backdrop(
                hasAppBar: hasAppBar,
                bgColor: productConfig.backgroundColor,
                frontLayer: hasNoProducts
                    ? _buildNoProductsWidget()
                    : (shouldShowProducts
                        ? (layout.isListView
                            ? ProductList(
                                products: products,
                                onRefresh: onRefresh,
                                onLoadMore: onLoadMore,
                                isFetching: isFetching,
                                errMsg: errMsg,
                                isEnd: isEnd,
                                layout: layout,
                                width: width,
                                ratioProductImage: ratioProductImage,
                                productListItemHeight: productListItemHeight,
                                animationConfig: productConfig.animationConfig,
                              )
                            : AsymmetricView(
                                products: products,
                                isFetching: isFetching,
                                isEnd: isEnd,
                                onLoadMore: onLoadMore,
                                width: width))
                        : const SizedBox.expand()),
                backLayer: NewFilterSystem(
                  showAttribute: true,
                  onFilter: (payload) {
                    unawaited(applyHierarchicalFilter(payload));
                  },
                ),
                onApplyFilters: () {
                  final payload =
                      providerContext.read<NewAttributeFilterSystem>().buildFilterPayload();
                  unawaited(applyHierarchicalFilter(payload));
                },
                frontTitle: productConfig.showCountDown
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentTitle),
                          CountDownTimer(widget.countdownDuration),
                        ],
                      )
                    : Text(currentTitle),
                backTitle: Center(child: Text(S.of(context).filter)),
                controller: filterController,
                appbarCategory: ProductCategoryMenu(
                  selectedCategories: categoryIds,
                  onTap: onTapProductCategoryMenu,
                  getStackSelectedCategory: () => stackSelectedCategory,
                ),
                onTapShareButton: () async {
                  await shareProductsLink(context);
                },
              ),
              expandingBottomSheet: renderBottomSheet(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoProductsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد منتجات حالياً في هذا القسم',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'لم نتمكن من العثور على منتجات تطابق معايير البحث',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // زر إرسال طلب جديد
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to parts-request-form screen
                FluxNavigate.pushNamed(
                  RouteList.partsRequestForm,
                  context: context,
                );
              },
              icon: const Icon(Icons.send),
              label: const Text('إرسال طلب جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Clear filters and reload products
                onFilter(
                  minPrice: null,
                  maxPrice: null,
                  categoryId: null,
                  tagId: null,
                  brandIds: null,
                  sortBy: null,
                  attributes: null,
                  listingLocationId: null,
                );
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('مسح جميع الفلاتر'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                side: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}