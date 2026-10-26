part of 'products_filter_mixin.dart';

extension ProductsFilterMixinWidgetExtension on ProductsFilterMixin {
  void showFilterBottomSheet() {
    showModalBottomSheet(
      context: App.fluxStoreNavigatorKey.currentContext!,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeNotifierProvider.value(
        value: brandModel,
        child: Stack(
          children: [
            GestureDetector(
              onTap: Navigator.of(context).pop,
              child: Container(color: Colors.transparent),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15.0),
                          topRight: Radius.circular(15.0),
                        ),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Stack(
                        children: [
                          const DragHandler(),
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: StatefulBuilder(
                              builder:
                                  (BuildContext context, StateSetter setState) {
                                // Trick Chot to rebuild FilterWidget
                                return FilterWidget(
                                  showAttribute: true,
                                  onFilter: (Map<String, dynamic> filters) {
                                    setState(() {});
                                    return onFilter(
                                      minPrice: filters['minPrice'],
                                      maxPrice: filters['maxPrice'],
                                      categoryId: filters['categoryId'],
                                      categoryName: filters['categoryName'],
                                      tagId: filters['tagId'],
                                      listingLocationId: filters['listingLocationId'],
                                      sortBy: filters['sortBy'],
                                      isSearch: filters['isSearch'],
                                      brandIds: filters['brandIds'],
                                      attributes: filters['attributes'],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Widget renderFilters(
    BuildContext context, {
    Widget? title,
    Widget? trailingWidget,
  }) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.primary.withOpacity(0.08);
    final borderColor = theme.colorScheme.primary.withOpacity(0.25);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            baseColor,
            theme.colorScheme.primary.withOpacity(0.04),
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.slider_horizontal_3,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              child: title ?? renderFilterTitle(context),
            ),
          ),
          if (trailingWidget == null) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: 40,
              child: VerticalDivider(
                width: 16,
                indent: 4,
                endIndent: 4,
                color: theme.colorScheme.primary.withOpacity(0.35),
              ),
            ),
            const SizedBox(width: 12),
          ],
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: showFilterBottomSheet,
            child: trailingWidget ??
                Row(
                  children: [
                    Text(
                      S.of(context).filter,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget renderFilterTitle(BuildContext context) {
    var appModel = context.read<AppModel>();
    final currency = appModel.currency;
    final currencyRate = appModel.currencyRate;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _renderFilterSortByTag(context),
          const SizedBox(width: 5),
          for (int i = 0; i < lstSelectedAttribute.length; i++)
            ...List.generate(
              lstSelectedAttribute.values.elementAt(i).length,
              (index) {
                final attribute = lstSelectedAttribute.keys.elementAt(i);
                final subAttribute =
                    lstSelectedAttribute.values.elementAt(i)[index];
                final attributeName = attribute.name?.capitalize();
                final subAttributeName = subAttribute.name;
                return FilterLabel(
                  label: '$attributeName: $subAttributeName',
                  onTap: () {
                    final selectedSubAttribute = List<SubAttribute>.from(
                        lstSelectedAttribute.values.elementAt(i));

                    selectedSubAttribute.removeAt(index);

                    if (selectedSubAttribute.isEmpty) {
                      lstSelectedAttribute
                          .remove(lstSelectedAttribute.keys.elementAt(i));
                    } else {
                      lstSelectedAttribute.update(
                        lstSelectedAttribute.keys.elementAt(i),
                        (value) => selectedSubAttribute,
                      );
                    }

                    onFilter();
                  },
                );
              },
            ),
          if (tagIds?.isNotEmpty ?? false)
            ...List.generate(
              tagIds!.length,
              (index) {
                final id = tagIds![index];
                final tagName = tagModel.getTagName(id).capitalize();
                return FilterLabel(
                  label: '#$tagName',
                  onTap: () {
                    final selectedTags = tagIds
                      ?..removeWhere((element) => element == id);
                    onFilter(tagId: selectedTags);
                  },
                );
              },
            ),
          if (brandIds?.isNotEmpty ?? false)
            ...List.generate(
              brandIds!.length,
              (index) {
                final id = brandIds![index];
                // Use BrandLayoutModel as a fallback if FilterBrandModel
                // doesn't load this brand in time
                final brandLayoutModel = context.read<BrandLayoutModel>();
                final brand = brandModel.getBrandById(id) ??
                    brandLayoutModel.getBrandById(id);
                final brandName = brand?.name?.capitalize() ?? id;
                return FilterLabel(
                  leading: brand != null
                      ? FluxImage(imageUrl: brand.image ?? '')
                      : null,
                  label: brandName,
                  onTap: () {
                    final selectedBrandIds = brandIds
                      ?..removeWhere((element) => element == id);
                    onFilter(brandIds: selectedBrandIds);
                  },
                );
              },
            ),
          if (minPrice != null && maxPrice != null && maxPrice != 0)
            FilterLabel(
              onTap: () {
                resetPrice();
                onFilter(minPrice: 0.0, maxPrice: 0.0);
              },
              label:
                  '${PriceTools.getCurrencyFormatted(minPrice, currencyRate, currency: currency)!} - ${PriceTools.getCurrencyFormatted(maxPrice, currencyRate, currency: currency)!}',
            ),
          if (categoryIds != null && showTagCategoryImage)
            ...List.generate(categoryIds?.length ?? 0, (int index) {
              final idCategory = categoryIds![index];
              final category =
                  context.read<CategoryModel>().categoryList[idCategory];

              if (category == null) {
                return const SizedBox();
              }

              return FilterLabel(
                label: category.name ?? '',
                leading: FluxImage(imageUrl: category.image ?? ''),
                onTap: () {
                  final selectedBrandIds = categoryIds
                    ?..removeWhere((element) => element == idCategory);
                  onFilter(categoryId: selectedBrandIds);
                },
              );
            }),
        ],
      ),
    );
  }

  Widget _renderFilterSortByTag(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (filterSortBy.displaySpecial != null)
          FilterLabel(
            label: filterSortBy.displaySpecial!,
            onTap: () {
              filterSortBy = filterSortBy.applyOnSale(null).applyFeatured(null);
              onFilter();
            },
            leading: filterSortBy.onSale ?? false
                ? Icon(
                    CupertinoIcons.tag_solid,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  )
                : Icon(
                    CupertinoIcons.star_circle_fill,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
          ),
        if (filterSortBy.displayOrderBy != null)
          FilterLabel(
            label: filterSortBy.displayOrderBy!,
            icon: filterSortBy.orderType == null
                ? null
                : (filterSortBy.orderType!.isAsc
                    ? Icon(
                        CupertinoIcons.sort_up,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withValueOpacity(0.6),
                      )
                    : Icon(
                        CupertinoIcons.sort_down,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withValueOpacity(0.6),
                      )),
            onTap: () {
              filterSortBy = filterSortBy.applyOrder(null).applyOrderBy(null);
              onFilter();
            },
          ),
      ],
    );
  }
}

class FilterParams {
  final double? minPrice;
  final double? maxPrice;
  final List<String>? categoryId;
  final String? categoryName;
  final List<String>? tagId;
  final String? listingLocationId;
  final FilterSortBy? sortBy;
  final bool? isSearch;
  final List<String>? brandIds;
  final Map<FilterAttribute, List<SubAttribute>>? attributes;

  const FilterParams({
    this.minPrice,
    this.maxPrice,
    this.categoryId,
    this.categoryName,
    this.tagId,
    this.listingLocationId,
    this.sortBy,
    this.isSearch,
    this.brandIds,
    this.attributes,
  });
}
