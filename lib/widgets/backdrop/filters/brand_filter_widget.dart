import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../common/config.dart';
import '../../../common/enums/load_state.dart';
import '../../../models/entities/brand.dart';
import '../../../models/index.dart';
import 'widgets/brand_item.dart';
import 'widgets/menu_title_widget.dart';

class BrandFilterWidget extends StatefulWidget {
  const BrandFilterWidget({
    super.key,
    this.useExpansionStyle = true,
    this.onChanged,
    this.brandId,
  });

  final bool useExpansionStyle;
  final List<String>? brandId;
  final void Function(List<String>?)? onChanged;

  @override
  State<BrandFilterWidget> createState() => _BrandFilterWidgetState();
}

class _BrandFilterWidgetState extends State<BrandFilterWidget> {
  late List<String> _brandId;

  void _update(Brand brand) {
    setState(() {
      if (_brandId.contains(brand.id.toString())) {
        _brandId.remove(brand.id.toString());
      } else {
        _brandId.add(brand.id.toString());
      }

      EasyDebounce.debounce(
        'debounceFilterBranch',
        const Duration(milliseconds: 1000),
        () {
          widget.onChanged?.call(_brandId);
        },
      );
    });
  }

  @override
  void initState() {
    _brandId = widget.brandId ?? [];
    super.initState();
  }

  @override
  void didUpdateWidget(BrandFilterWidget oldWidget) {
    if (oldWidget.brandId != widget.brandId) {
      _brandId = widget.brandId ?? [];
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FilterBrandModel>(
      builder: (_, model, __) {
        // Get current visible brands based on selection
        final visibleBrands = model.listVisibleBrand.toList();
        
        if (visibleBrands.isEmpty) {
          return const SizedBox();
        }

        return Column(
          children: [
            // Show current level of brands
            SizedBox(
              height: 130,
              child: ListView.separated(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: visibleBrands.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final brand = visibleBrands[i];
                  final isSelected = _brandId.contains(brand.id?.toString());
                  
                  return Container(
                    margin: const EdgeInsets.all(4),
                    child: BrandItem(
                      brand: brand,
                      onTap: () {
                        _update(brand);
                        
                        // If brand has children, update selection to show them
                        if (brand.hasChildren) {
                          model.updateSelectedParents([brand.id.toString()]);
                        }
                      },
                      isBrandNameShown: true,
                      isLogoCornerRounded: true,
                      isSelected: isSelected,
                    ),
                  );
                },
              ),
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
