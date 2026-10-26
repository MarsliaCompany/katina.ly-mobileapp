import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/boxes.dart';
import '../../models/category/category_model.dart';
import '../../models/entities/category.dart';
import '../../models/entities/filter_attribute.dart';
import '../../models/filter_attribute_model.dart';
import '../../models/user_model.dart';
import '../../services/services.dart';
import '../../widgets/backdrop/filters/dropdown/attribute_dropdown_widget.dart';
import '../../widgets/backdrop/filters/hierarchical_filter_column.dart';
import '../../widgets/common/loading_body.dart';

class CreateProductNativeScreen extends StatefulWidget {
  const CreateProductNativeScreen({super.key});

  @override
  State<CreateProductNativeScreen> createState() =>
      _CreateProductNativeScreenState();
}

class _CreateProductNativeScreenState extends State<CreateProductNativeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();
  final _priceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();

  final _picker = ImagePicker();
  File? _featuredImage;
  final List<File> _galleryImages = [];

  bool _isSubmitting = false;
  bool _inStock = true;
  int _currentStep = 0;

  final Set<String> _selectedCategoryIds = {};
  Map<FilterAttribute, List<SubAttribute>> _selectedAttributes = {};
  String? _loadedAttributeCategoryIds;
  String? _vendorBrandId;
  String? _vendorBrandLabel;
  int? _vendorBrandAttributeId;

  @override
  void initState() {
    super.initState();
    _hydrateVendorBrandContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureInitialData();
    });
  }

  void _hydrateVendorBrandContext() {
    final user = UserBox().userInfo;
    _vendorBrandId = user?.vendorBrandId;
    _vendorBrandLabel = user?.vendorBrandLabel;
    _vendorBrandAttributeId = int.tryParse(_vendorBrandId ?? '');
  }

  Future<void> _ensureInitialData() async {
    final categoryModel = context.read<CategoryModel>();
    final attributeModel = context.read<FilterAttributeModel>();

    if ((categoryModel.categories?.isEmpty ?? true)) {
      unawaited(categoryModel.getCategories());
    }
    final shouldReloadAttributes = attributeModel.lstProductAttribute?.isEmpty ?? true;
    if (shouldReloadAttributes) {
      unawaited(attributeModel.getFilterAttributes());
    } else if (!attributeModel.hasHierarchicalAttributes &&
        !attributeModel.isLoadingHierarchy) {
      unawaited(attributeModel.loadHierarchicalAttributes());
    }

    if (_vendorBrandAttributeId != null) {
      unawaited(attributeModel.loadChildren(_vendorBrandAttributeId));
    }
  }

  @override
  void dispose() {
    _shortDescController.dispose();
    _longDescController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _nameController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _pickFeaturedImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _featuredImage = File(picked.path));
    }
  }

  Future<void> _pickGalleryImage() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _galleryImages.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _shortDescController.clear();
    _longDescController.clear();
    _priceController.clear();
    _salePriceController.clear();
    _nameController.clear();
    _skuController.clear();
    setState(() {
      _featuredImage = null;
      _galleryImages.clear();
      _selectedCategoryIds.clear();
      _selectedAttributes.clear();
      _inStock = true;
      _currentStep = 0;
      _loadedAttributeCategoryIds = null;
    });
  }

  Future<void> _reloadAttributesForSelectedCategories() async {
    final attributeModel = context.read<FilterAttributeModel>();
    final categoryIds = _selectedCategoryIds.isEmpty
        ? null
        : _selectedCategoryIds.toList(growable: false).join(',');

    if (categoryIds == _loadedAttributeCategoryIds) {
      return;
    }

    _loadedAttributeCategoryIds = categoryIds;
    await attributeModel.getFilterAttributes(categoryIds: categoryIds);
    if (!mounted) return;
    setState(() {
      _selectedAttributes = {};
    });
  }

  void _showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: action,
        ),
      );
  }

  Future<int?> _uploadImage(File file, String? cookie) async {
    final bytes = await file.readAsBytes();
    final base64Image = base64.encode(bytes);
    final body = {
      'title': {'rendered': file.path.split('/').last},
      'media_attachment': base64Image,
    };

    _showSnackBar('جاري رفع الصورة...');
    final result = await Services().api.uploadImage(body, cookie);
    if (result is Map && result['id'] != null) {
      _showSnackBar('تم رفع الصورة بنجاح');
      return int.tryParse(result['id'].toString()) ?? result['id'] as int?;
    }
    _showSnackBar('فشل رفع الصورة، يرجى المحاولة مجددًا');
    return null;
  }

  Future<void> _handleSubmit({required bool publish}) async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      _showMessage(S.of(context).pleaseInputFillAllFields);
      return;
    }

    final user = context.read<UserModel>().user;
    final jwtToken = user?.jwtToken;
    final cookie = user?.cookie;
    if (jwtToken == null || jwtToken.isEmpty || cookie == null) {
      _showMessage(S.of(context).loginToYourAccount);
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      final List<int> imageIds = [];
      if (_featuredImage != null) {
        final id = await _uploadImage(_featuredImage!, cookie);
        if (id != null) {
          imageIds.add(id);
        }
      }
      for (final file in _galleryImages) {
        final id = await _uploadImage(file, cookie);
        if (id != null) {
          imageIds.add(id);
        }
      }

      final attributeModel = context.read<FilterAttributeModel>();
      final payload = _buildPayload(
        publish: publish,
        imageIds: imageIds,
        attributeModel: attributeModel,
      );

      await Services().api.uploadDokanProduct(
        token: jwtToken,
        payload: payload,
      );

      if (publish) {
        await _onPublishSuccess();
      } else {
        _showSnackBar('تم حفظ المنتج كمسودة');
        _resetForm();
      }
    } catch (err) {
      _showMessage(err.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onPublishSuccess() async {
    if (!mounted) {
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).successful),
        content: const Text('تم نشر المنتج بنجاح على متجر كاتينا!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).back),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إضافة منتج آخر'),
          ),
        ],
      ),
    );

    if (result == true) {
      _resetForm();
      _showSnackBar('تمت إعادة ضبط الحقول، يمكنك إضافة منتج جديد الآن');
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Map<String, dynamic> _buildPayload({
    required bool publish,
    required List<int> imageIds,
    required FilterAttributeModel attributeModel,
  }) {
    final productName = _nameController.text.trim();
    final vendorEntry = _buildVendorBrandAttributeEntry(attributeModel);
    final attributeEntries = _selectedAttributes.entries
        .where((entry) => entry.key.id != null)
        .toList(growable: true);

    if (vendorEntry != null &&
        attributeEntries.every((entry) => entry.key.id != _vendorBrandAttributeId)) {
      attributeEntries.insert(0, vendorEntry);
    }

    return {
      'status': publish ? 'publish' : 'draft',
      'title': productName,
      'name': productName,
      'regular_price': _priceController.text.trim(),
      'sale_price': _salePriceController.text.trim().isEmpty
          ? null
          : _salePriceController.text.trim(),
      'short_description': _shortDescController.text.trim(),
      'content': _longDescController.text.trim(),
      'excerpt': _shortDescController.text.trim(),
      'featured_image': imageIds.isNotEmpty ? imageIds.first : null,
      'image_ids': imageIds,
      'categories': _selectedCategoryIds
          .map((id) => {'id': id})
          .toList(growable: false),
      'attributes': attributeEntries
          .map((entry) => {
                'id': entry.key.id,
                'options': entry.value
                    .map((e) => (e.name ?? '').trim())
                    .where((name) => name.isNotEmpty)
                    .toList(growable: false),
              })
          .where((item) => (item['options'] as List).isNotEmpty)
          .toList(growable: false),
      'sku': _skuController.text.trim(),
      'stock_status': _inStock ? 'instock' : 'outofstock',
    }..removeWhere((key, value) => value == null || (value is String && value.isEmpty));
  }

  MapEntry<FilterAttribute, List<SubAttribute>>? _buildVendorBrandAttributeEntry(
      FilterAttributeModel attributeModel) {
    if (_vendorBrandAttributeId == null) {
      return null;
    }

    final attribute = attributeModel.lstProductAttribute
        ?.firstWhereOrNull((element) => element.id == _vendorBrandAttributeId);
    if (attribute == null) {
      return null;
    }

    final optionName = _vendorBrandLabel?.isNotEmpty == true
        ? _vendorBrandLabel!
        : attribute.name ?? 'Brand';

    final subAttribute = SubAttribute(
      id: _vendorBrandAttributeId,
      name: optionName,
    );

    return MapEntry(attribute, [subAttribute]);
  }

  void _showMessage(String? message) {
    if (!mounted || message == null || message.isEmpty) return;
    _showSnackBar(message);
  }

  @override
  Widget build(BuildContext context) {
    final categoryModel = context.watch<CategoryModel>();
    final attributeModel = context.watch<FilterAttributeModel>();

    final isLoading = categoryModel.isLoading == true ||
        attributeModel.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).addProduct),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => _handleSubmit(publish: false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: const Text('حفظ كمسودة'),
          ),
          TextButton(
            onPressed: _isSubmitting ? null : () => _handleSubmit(publish: true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(S.of(context).publish),
          ),
        ],
      ),
      body: LoadingBody(
        isLoading: isLoading || _isSubmitting,
        child: Form(
          key: _formKey,
          child: Stepper(
            currentStep: _currentStep,
            controlsBuilder: (context, details) {
              final isLastStep = _currentStep >= 2;

              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    if (!isLastStep)
                      ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _currentStep += 1),
                        child: Text(S.of(context).continues),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _isSubmitting ? null : () => _handleSubmit(publish: true),
                          child: Text(S.of(context).publish),
                        ),
                      ),
                    const SizedBox(width: 12),
                    if (isLastStep)
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isSubmitting ? null : () => _handleSubmit(publish: false),
                          child: const Text('حفظ كمسودة'),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : (_currentStep > 0
                                ? () => setState(() => _currentStep -= 1)
                                : null),
                        child: Text(S.of(context).cancel),
                      ),
                  ],
                ),
              );
            },
            onStepContinue: _currentStep < 2
                ? () => setState(() => _currentStep += 1)
                : null,
            onStepCancel: _currentStep > 0
                ? () => setState(() => _currentStep -= 1)
                : null,
            steps: [
              Step(
                title: Text(S.of(context).editProductInfo),
                isActive: _currentStep >= 0,
                content: _buildGeneralSection(categoryModel),
              ),
              Step(
                title: Text(S.of(context).images),
                isActive: _currentStep >= 1,
                content: _buildMediaSection(),
              ),
              Step(
                title: Text(S.of(context).attributes),
                isActive: _currentStep >= 2,
                content: _buildAttributesSection(attributeModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSection(
    CategoryModel categoryModel,
  ) {
    final categories = categoryModel.categories ?? const <Category>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(labelText: S.of(context).productName),
          validator: (value) =>
              value == null || value.isEmpty ? S.of(context).pleaseInputFillAllFields : null,
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: S.of(context).price),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? S.of(context).pleaseInputFillAllFields : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _salePriceController,
                decoration: InputDecoration(labelText: S.of(context).salePrice),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _shortDescController,
          decoration: InputDecoration(labelText: S.of(context).shortDescription),
          maxLines: 2,
        ),
        TextFormField(
          controller: _longDescController,
          decoration: InputDecoration(labelText: S.of(context).description),
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        Text(S.of(context).category, style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: categories
              .map((category) => FilterChip(
                    label: Text(category.name ?? ''),
                    selected: _selectedCategoryIds.contains(category.id?.toString()),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          if (category.id != null) {
                            _selectedCategoryIds.add(category.id.toString());
                          }
                        } else {
                          _selectedCategoryIds.remove(category.id?.toString());
                        }
                      });
                      unawaited(_reloadAttributesForSelectedCategories());
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _skuController,
          decoration: const InputDecoration(labelText: 'SKU'),
        ),
        SwitchListTile.adaptive(
          title: Text(S.of(context).inStock),
          value: _inStock,
          onChanged: (value) => setState(() => _inStock = value),
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.of(context).images,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickFeaturedImage,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: _featuredImage == null
                ? Center(child: Text(S.of(context).uploadImage))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_featuredImage!, fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(S.of(context).gallery, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final image in _galleryImages)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(image, width: 100, height: 100, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _galleryImages.remove(image)),
                  ),
                ],
              ),
            GestureDetector(
              onTap: _pickGalleryImage,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttributesSection(FilterAttributeModel attributeModel) {
    debugPrint('[HPA][UI] hasHierarchy=${attributeModel.hasHierarchicalAttributes} '
        'roots=${attributeModel.hierarchicalAttributes?.length ?? 0} '
        'isLoadingHierarchy=${attributeModel.isLoadingHierarchy}');
    final hasHierarchy = attributeModel.hasHierarchicalAttributes;

    if (attributeModel.isLoadingHierarchy || attributeModel.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasHierarchy) {
      final lockedLabel = _vendorBrandLabel?.isNotEmpty == true
          ? _vendorBrandLabel!
          : S.of(context).brand ?? 'العلامة التجارية';
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_vendorBrandAttributeId == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لم يتم تعيين ماركة افتراضية لهذا الحساب، يمكنك تحديدها يدويًا من القوائم أدناه.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_vendorBrandAttributeId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.factory, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lockedLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('مقفلة'),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                    )
                  ],
                ),
              ),
            HierarchicalFilterColumn(
              selectedAttribute: _selectedAttributes,
              onChanged: (map) {
                setState(() => _selectedAttributes = map);
              },
              lockedRootId: _vendorBrandAttributeId,
              lockedRootLabel: lockedLabel,
            ),
          ],
        ),
      );
    }

    final attributes =
        attributeModel.listVisibleAttribute ?? const <FilterAttribute>[];
    if (attributes.isEmpty) {
      return Text(S.of(context).noData);
    }

    return AttributeDropdownWidget(
      selectedAttribute: _selectedAttributes,
      onChanged: (map) {
        setState(() {
          _selectedAttributes = map;
        });
      },
    );
  }
}
