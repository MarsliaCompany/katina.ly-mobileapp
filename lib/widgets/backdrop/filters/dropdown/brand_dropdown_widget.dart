import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../../common/config.dart';
import '../../../../common/enums/load_state.dart';
import '../../../../models/entities/brand.dart';
import '../../../../models/index.dart';

class BrandDropdownWidget extends StatefulWidget {
  const BrandDropdownWidget({
    super.key,
    this.onChanged,
    this.brandId,
  });

  final List<String>? brandId;
  final void Function(List<String>?)? onChanged;

  @override
  State<BrandDropdownWidget> createState() => _BrandDropdownWidgetState();
}

class _BrandDropdownWidgetState extends State<BrandDropdownWidget> {
  late List<String> _brandId;
  String? _selectedBrandName;

  @override
  void initState() {
    super.initState();
    _brandId = widget.brandId ?? [];
  }

  void _updateSelectedBrandName(List<Brand> brands) {
    if (_brandId.isNotEmpty && brands.isNotEmpty) {
      try {
        final selectedBrand = brands.firstWhere(
          (brand) => brand.id?.toString() == _brandId.first,
        );
        _selectedBrandName = selectedBrand.name;
      } catch (e) {
        _selectedBrandName = null;
      }
    } else {
      _selectedBrandName = null;
    }
  }

  @override
  void didUpdateWidget(BrandDropdownWidget oldWidget) {
    if (oldWidget.brandId != widget.brandId) {
      _brandId = widget.brandId ?? [];
    }
    super.didUpdateWidget(oldWidget);
  }

  void _onBrandChanged(String? brandId, String? brandName) {
    setState(() {
      if (brandId == null) {
        _brandId = [];
        _selectedBrandName = null;
      } else {
        if (_brandId.contains(brandId)) {
          _brandId.remove(brandId);
          _selectedBrandName = null;
        } else {
          _brandId = [brandId];
          _selectedBrandName = brandName;
        }
      }
    });
    widget.onChanged?.call(_brandId.isEmpty ? null : _brandId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FilterBrandModel>(
      builder: (_, model, __) {
        final listBrand = model.listVisibleBrand.toList();

        if (listBrand.isEmpty) {
          return const SizedBox();
        }

        // Update selected brand name when brands are available
        _updateSelectedBrandName(listBrand);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _brandId.isNotEmpty ? _brandId.first : null,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              hint: const Text('اختر العلامة التجارية'),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(S.of(context).all ?? 'الكل'),
                ),
                ...listBrand.map((brand) {
                  return DropdownMenuItem<String>(
                    value: brand.id?.toString(),
                    child: Text(brand.name ?? ''),
                  );
                }),
              ],
              onChanged: (value) {
                if (value != null) {
                  final selectedBrand = listBrand.firstWhere(
                    (b) => b.id?.toString() == value,
                  );
                  _onBrandChanged(value, selectedBrand.name);
                  
                  // If brand has children, update selection to show them
                  if (selectedBrand.hasChildren) {
                    model.updateSelectedParents([selectedBrand.id.toString()]);
                  }
                } else {
                  _onBrandChanged(null, null);
                }
              },
            ),
            
            // Show back button if we're viewing child filters
            if (model.selectedParentIds != null && model.selectedParentIds!.isNotEmpty)
              TextButton(
                onPressed: () {
                  model.updateSelectedParents(null);
                },
                child: Text(S.of(context).back),
              ),
          ],
        );
      },
    );
  }
}
