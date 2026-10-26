import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../../common/config.dart';
import '../../../../common/constants.dart';
import '../../../../common/tools/price_tools.dart';
import '../../../../models/app_model.dart';

class PriceDropdownWidget extends StatefulWidget {
  const PriceDropdownWidget({
    super.key,
    this.currentMinPrice,
    this.currentMaxPrice,
    this.minFilterPrice,
    this.maxFilterPrice,
    this.onChanged,
  });

  final double? currentMinPrice;
  final double? currentMaxPrice;
  final double? minFilterPrice;
  final double? maxFilterPrice;
  final void Function(double, double)? onChanged;

  @override
  State<PriceDropdownWidget> createState() => _PriceDropdownWidgetState();
}

class _PriceDropdownWidgetState extends State<PriceDropdownWidget> {
  AppModel get appModel => context.read<AppModel>();

  double get minFilterPrice =>
      min(widget.currentMinPrice ?? 0, widget.minFilterPrice ?? 0);
  double get maxFilterPrice =>
      max(widget.currentMaxPrice ?? kMaxPriceFilter, widget.maxFilterPrice ?? kMaxPriceFilter);

  double _currentMinPrice = 0.0;
  double _currentMaxPrice = 0.0;
  String? _selectedPriceRange;

  @override
  void initState() {
    super.initState();
    _currentMinPrice = widget.currentMinPrice ?? 0;
    _currentMaxPrice = widget.currentMaxPrice ?? maxFilterPrice;
    _updateSelectedPriceRange();
  }

  @override
  void didUpdateWidget(PriceDropdownWidget oldWidget) {
    if (oldWidget.currentMinPrice != widget.currentMinPrice) {
      _currentMinPrice = widget.currentMinPrice ?? 0;
    }
    if (oldWidget.currentMaxPrice != widget.currentMaxPrice) {
      _currentMaxPrice = widget.currentMaxPrice ?? maxFilterPrice;
    }
    _updateSelectedPriceRange();
    super.didUpdateWidget(oldWidget);
  }

  void _updateSelectedPriceRange() {
    if (_currentMinPrice == 0 && _currentMaxPrice == maxFilterPrice) {
      _selectedPriceRange = null;
    } else {
      final currency = appModel.currency;
      final currencyRate = appModel.currencyRate;
      final minPriceStr = PriceTools.getCurrencyFormatted(
        _currentMinPrice,
        currencyRate,
        currency: currency,
      );
      final maxPriceStr = PriceTools.getCurrencyFormatted(
        _currentMaxPrice,
        currencyRate,
        currency: currency,
      );
      _selectedPriceRange = '$minPriceStr - $maxPriceStr';
    }
  }

  List<Map<String, double>> _generatePriceRanges() {
    final ranges = <Map<String, double>>[];
    final step = (maxFilterPrice - minFilterPrice) / 5;
    
    for (int i = 0; i < 5; i++) {
      final min = minFilterPrice + (step * i);
      final max = i == 4 ? maxFilterPrice : minFilterPrice + (step * (i + 1));
      ranges.add({'min': min, 'max': max});
    }
    
    return ranges;
  }

  void _onPriceRangeChanged(Map<String, double>? range) {
    if (range == null) {
      _currentMinPrice = 0;
      _currentMaxPrice = maxFilterPrice;
      _selectedPriceRange = null;
    } else {
      _currentMinPrice = range['min']!;
      _currentMaxPrice = range['max']!;
      final currency = appModel.currency;
      final currencyRate = appModel.currencyRate;
      final minPriceStr = PriceTools.getCurrencyFormatted(
        _currentMinPrice,
        currencyRate,
        currency: currency,
      );
      final maxPriceStr = PriceTools.getCurrencyFormatted(
        _currentMaxPrice,
        currencyRate,
        currency: currency,
      );
      _selectedPriceRange = '$minPriceStr - $maxPriceStr';
    }
    widget.onChanged?.call(_currentMinPrice, _currentMaxPrice);
  }

  @override
  Widget build(BuildContext context) {
    final priceRanges = _generatePriceRanges();
    final currency = appModel.currency;
    final currencyRate = appModel.currencyRate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).price,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Map<String, double>>(
            value: _selectedPriceRange == null
                ? null
                : priceRanges.firstWhere(
                    (range) =>
                        (range['min']! - _currentMinPrice).abs() < 0.01 &&
                        (range['max']! - _currentMaxPrice).abs() < 0.01,
                    orElse: () => priceRanges.first,
                  ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            hint: const Text('اختر نطاق السعر'),
            items: [
              DropdownMenuItem<Map<String, double>>(
                value: null,
                child: Text(S.of(context).all ?? 'الكل'),
              ),
              ...priceRanges.map((range) {
                final minPriceStr = PriceTools.getCurrencyFormatted(
                  range['min']!,
                  currencyRate,
                  currency: currency,
                );
                final maxPriceStr = PriceTools.getCurrencyFormatted(
                  range['max']!,
                  currencyRate,
                  currency: currency,
                );
                return DropdownMenuItem<Map<String, double>>(
                  value: range,
                  child: Text('$minPriceStr - $maxPriceStr'),
                );
              }),
            ],
            onChanged: _onPriceRangeChanged,
          ),
        ],
      ),
    );
  }
}




