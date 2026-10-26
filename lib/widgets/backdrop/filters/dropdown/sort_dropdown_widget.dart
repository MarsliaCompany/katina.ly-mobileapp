import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../../models/entities/filter_sorty_by.dart';
import '../../../../services/services.dart';

class SortDropdownWidget extends StatefulWidget {
  const SortDropdownWidget({
    super.key,
    required this.filterSortBy,
    required this.onFilterChanged,
  });

  final FilterSortBy? filterSortBy;
  final Function(FilterSortBy? filterSortBy) onFilterChanged;

  @override
  State<SortDropdownWidget> createState() => _SortDropdownWidgetState();
}

class _SortDropdownWidgetState extends State<SortDropdownWidget> {
  String? _selectedSortValue;

  @override
  void initState() {
    super.initState();
    _updateSelectedValue();
  }

  @override
  void didUpdateWidget(SortDropdownWidget oldWidget) {
    if (oldWidget.filterSortBy != widget.filterSortBy) {
      _updateSelectedValue();
    }
    super.didUpdateWidget(oldWidget);
  }

  void _updateSelectedValue() {
    if (widget.filterSortBy?.groupOrderBy != null) {
      _selectedSortValue = widget.filterSortBy!.groupOrderBy;
    } else if (widget.filterSortBy?.displaySpecial != null) {
      _selectedSortValue = widget.filterSortBy!.onSale ?? false
          ? 'onSale'
          : 'featured';
    } else {
      _selectedSortValue = null;
    }
  }

  List<OrderByType> get supportedSortByOptions => Services()
      .widget
      .supportedSortByOptions;

  void _onSortChanged(String? value) {
    if (value == null) {
      widget.onFilterChanged(FilterSortBy());
      return;
    }

    FilterSortBy? newFilterSortBy;

    if (value == 'featured') {
      newFilterSortBy = widget.filterSortBy?.applyFeatured(true) ??
          FilterSortBy(featured: true);
    } else if (value == 'onSale') {
      newFilterSortBy = widget.filterSortBy?.applyOnSale(true) ??
          FilterSortBy(onSale: true);
    } else {
      final filterData = value.split('-');
      final orderBy = filterData[0];
      final order = filterData.length > 1 ? filterData[1] : null;
      newFilterSortBy = widget.filterSortBy
          ?.applyOrderBy(orderBy)
          .applyOrder(order) ??
          FilterSortBy().applyOrderBy(orderBy).applyOrder(order);
    }

    widget.onFilterChanged(newFilterSortBy);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> sortOptions = [];

    // Add special options
    if (supportedSortByOptions.contains(OrderByType.featured)) {
      sortOptions.add({
        'value': 'featured',
        'label': S.of(context).featured,
      });
    }
    if (supportedSortByOptions.contains(OrderByType.onSale)) {
      sortOptions.add({
        'value': 'onSale',
        'label': S.of(context).onSale,
      });
    }

    // Add order by options
    if (supportedSortByOptions.contains(OrderByType.date)) {
      sortOptions.add({
        'value': 'date-desc',
        'label': S.of(context).dateLatest,
      });
      sortOptions.add({
        'value': 'date-asc',
        'label': S.of(context).dateOldest,
      });
    }
    if (supportedSortByOptions.contains(OrderByType.price)) {
      sortOptions.add({
        'value': 'price-asc',
        'label': S.of(context).priceLowToHigh,
      });
      sortOptions.add({
        'value': 'price-desc',
        'label': S.of(context).priceHighToLow,
      });
    }
    if (supportedSortByOptions.contains(OrderByType.title)) {
      sortOptions.add({
        'value': 'title-asc',
        'label': S.of(context).titleAToZ,
      });
      sortOptions.add({
        'value': 'title-desc',
        'label': S.of(context).titleZToA,
      });
    }
    if (supportedSortByOptions.contains(OrderByType.menu_order)) {
      sortOptions.add({
        'value': 'menu_order-asc',
        'label': S.of(context).menuOrder,
      });
    }
    if (supportedSortByOptions.contains(OrderByType.popularity)) {
      sortOptions.add({
        'value': 'popularity-null',
        'label': S.of(context).popularity,
      });
    }
    if (supportedSortByOptions.contains(OrderByType.rating)) {
      sortOptions.add({
        'value': 'rating-desc',
        'label': S.of(context).averageRating,
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).sortBy ?? 'الترتيب',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedSortValue,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            hint: const Text('اختر طريقة الترتيب'),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: const Text('الافتراضي'),
              ),
              ...sortOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(option['label']!),
                );
              }),
            ],
            onChanged: _onSortChanged,
          ),
        ],
      ),
    );
  }
}




