# 🎨 أمثلة التخصيص والتحسين - Filter-First Feature

هذا الملف يحتوي على أمثلة عملية لتخصيص وتحسين ميزة الفلاتر.

---

## 📋 جدول المحتويات

1. [إضافة زر تخطي الفلاتر](#1-إضافة-زر-تخطي-الفلاتر)
2. [إضافة زر إعادة تعيين الفلاتر](#2-إضافة-زر-إعادة-تعيين-الفلاتر)
3. [عرض عداد المنتجات](#3-عرض-عداد-المنتجات)
4. [حفظ الفلاتر المفضلة](#4-حفظ-الفلاتر-المفضلة)
5. [إضافة فلاتر سريعة](#5-إضافة-فلاتر-سريعة)
6. [تخصيص شكل الفلاتر](#6-تخصيص-شكل-الفلاتر)

---

## 1. إضافة زر تخطي الفلاتر

للمستخدمين الذين يريدون رؤية جميع المنتجات بدون فلاتر.

### الموقع
`lib/screens/products/filters_screen.dart`

### الكود

```dart
// في الـ AppBar
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        widget.arguments.cateName ?? S.of(context).filter,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      // ✨ إضافة زر تخطي
      actions: [
        TextButton(
          onPressed: () {
            // الانتقال مباشرة للمنتجات بدون فلاتر
            FluxNavigate.pushReplacementNamed(
              RouteList.backdrop,
              arguments: widget.arguments,
              context: context,
            );
          },
          child: Text(
            S.of(context).skipFilters ?? 'تخطي',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
    // ... باقي الكود
  );
}
```

### الترجمة (إضافي)
في ملف الترجمة `lib/config/strings.dart` أو JSON:

```json
{
  "skipFilters": "تخطي الفلاتر",
  "skipFilters_en": "Skip Filters"
}
```

---

## 2. إضافة زر إعادة تعيين الفلاتر

لإعادة جميع الفلاتر إلى الوضع الافتراضي.

### الموقع
`lib/screens/products/filters_screen.dart`

### الكود

```dart
class _FiltersScreenState extends State<FiltersScreen> {
  // ... المتغيرات الموجودة
  
  // ✨ دالة إعادة التعيين
  void _resetFilters() {
    setState(() {
      _minPrice = null;
      _maxPrice = null;
      _categoryIds = widget.arguments.cateId?.split(',');
      _categoryIds?.removeWhere((element) => element.isEmpty);
      _tagIds = null;
      _brandIds = null;
      _listingLocationId = null;
      _sortBy = null;
      _selectedAttributes = null;
    });
    
    // رسالة تأكيد (اختياري)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).filtersReset ?? 'تم إعادة تعيين الفلاتر'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.arguments.cateName ?? S.of(context).filter),
        actions: [
          // ✨ زر إعادة التعيين
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: S.of(context).resetFilters ?? 'إعادة تعيين',
            onPressed: _resetFilters,
          ),
        ],
      ),
      body: _isLoadingPrices
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Consumer<ProductPriceModel>(
                    builder: (context, productPriceModel, child) {
                      return FilterWidget(
                        // ... الـ parameters الموجودة
                      );
                    },
                  ),
                ),
                // ✨ أزرار في الأسفل
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // زر إعادة التعيين
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetFilters,
                          child: Text(S.of(context).reset ?? 'إعادة تعيين'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // زر التطبيق
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _applyFilters,
                          child: Text(S.of(context).apply ?? 'تطبيق'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
```

---

## 3. عرض عداد المنتجات

لعرض عدد المنتجات المطابقة للفلاتر في الوقت الفعلي.

### الموقع
`lib/screens/products/filters_screen.dart`

### الكود

```dart
class _FiltersScreenState extends State<FiltersScreen> {
  // ... المتغيرات الموجودة
  int _matchingProductsCount = 0;
  bool _isCountingProducts = false;
  
  // ✨ دالة حساب المنتجات المطابقة
  Future<void> _updateProductCount() async {
    setState(() {
      _isCountingProducts = true;
    });
    
    try {
      final productModel = context.read<ProductModel>();
      
      // إنشاء معايير البحث
      final params = FilterProductParams(
        categoryIds: _categoryIds,
        tagIds: _tagIds,
        brandIds: _brandIds,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        attributes: _selectedAttributes,
        sortBy: _sortBy,
      );
      
      // الحصول على العدد
      final count = await productModel.getProductCount(params);
      
      setState(() {
        _matchingProductsCount = count;
        _isCountingProducts = false;
      });
    } catch (e) {
      setState(() {
        _isCountingProducts = false;
      });
    }
  }
  
  void _onFilter({
    // ... parameters موجودة
  }) {
    setState(() {
      // ... تحديث الفلاتر
    });
    
    // ✨ تحديث العداد
    _updateProductCount();
  }
  
  @override
  void initState() {
    super.initState();
    _categoryIds = widget.arguments.cateId?.split(',');
    _categoryIds?.removeWhere((element) => element.isEmpty);
    _initFilterPrices();
    
    // ✨ حساب العدد الأولي
    _updateProductCount();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.arguments.cateName ?? S.of(context).filter),
      ),
      body: Column(
        children: [
          // ✨ عرض عداد المنتجات
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isCountingProducts)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.inventory_2_outlined,
                    color: Theme.of(context).primaryColor,
                  ),
                const SizedBox(width: 8),
                Text(
                  _isCountingProducts
                      ? 'جاري الحساب...'
                      : '$_matchingProductsCount ${S.of(context).products ?? "منتج"} متطابق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          // ... باقي المحتوى
        ],
      ),
    );
  }
}
```

---

## 4. حفظ الفلاتر المفضلة

للسماح للمستخدم بحفظ مجموعات فلاتر معينة واستخدامها لاحقاً.

### إنشاء نموذج البيانات

```dart
// lib/models/entities/saved_filter.dart

class SavedFilter {
  final String id;
  final String name;
  final String? categoryId;
  final List<String>? tagIds;
  final List<String>? brandIds;
  final double? minPrice;
  final double? maxPrice;
  final Map<FilterAttribute, List<SubAttribute>>? attributes;
  final FilterSortBy? sortBy;
  final DateTime createdAt;
  
  SavedFilter({
    required this.id,
    required this.name,
    this.categoryId,
    this.tagIds,
    this.brandIds,
    this.minPrice,
    this.maxPrice,
    this.attributes,
    this.sortBy,
    required this.createdAt,
  });
  
  // تحويل من/إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'tagIds': tagIds,
      'brandIds': brandIds,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'sortBy': sortBy?.toString(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  factory SavedFilter.fromJson(Map<String, dynamic> json) {
    return SavedFilter(
      id: json['id'],
      name: json['name'],
      categoryId: json['categoryId'],
      tagIds: json['tagIds']?.cast<String>(),
      brandIds: json['brandIds']?.cast<String>(),
      minPrice: json['minPrice'],
      maxPrice: json['maxPrice'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
```

### خدمة الحفظ

```dart
// lib/services/saved_filters_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SavedFiltersService {
  static const String _key = 'saved_filters';
  
  // حفظ فلتر جديد
  Future<void> saveFilter(SavedFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    final filters = await getSavedFilters();
    
    filters.add(filter);
    
    final jsonList = filters.map((f) => f.toJson()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }
  
  // الحصول على جميع الفلاتر المحفوظة
  Future<List<SavedFilter>> getSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    
    if (jsonString == null) return [];
    
    final jsonList = json.decode(jsonString) as List;
    return jsonList.map((j) => SavedFilter.fromJson(j)).toList();
  }
  
  // حذف فلتر
  Future<void> deleteFilter(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final filters = await getSavedFilters();
    
    filters.removeWhere((f) => f.id == id);
    
    final jsonList = filters.map((f) => f.toJson()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }
}
```

### واجهة الحفظ والتحميل

```dart
// في filters_screen.dart

class _FiltersScreenState extends State<FiltersScreen> {
  final SavedFiltersService _savedFiltersService = SavedFiltersService();
  List<SavedFilter> _savedFilters = [];
  
  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
  }
  
  Future<void> _loadSavedFilters() async {
    final filters = await _savedFiltersService.getSavedFilters();
    setState(() {
      _savedFilters = filters;
    });
  }
  
  // ✨ حفظ الفلاتر الحالية
  Future<void> _saveCurrentFilters() async {
    final nameController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حفظ الفلاتر'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'اسم مجموعة الفلاتر',
            hintText: 'مثال: ملابس صيفية رخيصة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final filter = SavedFilter(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  categoryId: _categoryIds?.join(','),
                  tagIds: _tagIds,
                  brandIds: _brandIds,
                  minPrice: _minPrice,
                  maxPrice: _maxPrice,
                  attributes: _selectedAttributes,
                  sortBy: _sortBy,
                  createdAt: DateTime.now(),
                );
                
                await _savedFiltersService.saveFilter(filter);
                await _loadSavedFilters();
                
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ الفلاتر بنجاح')),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
  
  // ✨ تحميل فلاتر محفوظة
  void _loadSavedFilter(SavedFilter filter) {
    setState(() {
      _categoryIds = filter.categoryId?.split(',');
      _tagIds = filter.tagIds;
      _brandIds = filter.brandIds;
      _minPrice = filter.minPrice;
      _maxPrice = filter.maxPrice;
      _selectedAttributes = filter.attributes;
      _sortBy = filter.sortBy;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحميل "${filter.name}"')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.arguments.cateName ?? S.of(context).filter),
        actions: [
          // ✨ زر حفظ الفلاتر
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            tooltip: 'حفظ الفلاتر',
            onPressed: _saveCurrentFilters,
          ),
          // ✨ زر عرض الفلاتر المحفوظة
          IconButton(
            icon: const Icon(Icons.bookmarks),
            tooltip: 'الفلاتر المحفوظة',
            onPressed: () => _showSavedFiltersDialog(),
          ),
        ],
      ),
      // ... باقي الكود
    );
  }
  
  // ✨ عرض قائمة الفلاتر المحفوظة
  void _showSavedFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الفلاتر المحفوظة'),
        content: SizedBox(
          width: double.maxFinite,
          child: _savedFilters.isEmpty
              ? const Center(child: Text('لا توجد فلاتر محفوظة'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _savedFilters.length,
                  itemBuilder: (context, index) {
                    final filter = _savedFilters[index];
                    return ListTile(
                      leading: const Icon(Icons.filter_list),
                      title: Text(filter.name),
                      subtitle: Text(
                        'تم الحفظ: ${DateFormat('dd/MM/yyyy').format(filter.createdAt)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check),
                            color: Colors.green,
                            onPressed: () {
                              _loadSavedFilter(filter);
                              Navigator.pop(context);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () async {
                              await _savedFiltersService.deleteFilter(filter.id);
                              await _loadSavedFilters();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. إضافة فلاتر سريعة

فلاتر جاهزة ومعرّفة مسبقاً للوصول السريع.

### الكود

```dart
// lib/screens/products/filters_screen.dart

class _FiltersScreenState extends State<FiltersScreen> {
  // ✨ الفلاتر السريعة
  final List<Map<String, dynamic>> _quickFilters = [
    {
      'icon': Icons.flash_on,
      'title': 'عروض اليوم',
      'color': Colors.orange,
      'onSale': true,
    },
    {
      'icon': Icons.star,
      'title': 'الأعلى تقييماً',
      'color': Colors.amber,
      'sortBy': FilterSortBy.rating,
    },
    {
      'icon': Icons.trending_up,
      'title': 'الأكثر مبيعاً',
      'color': Colors.green,
      'sortBy': FilterSortBy.popularity,
    },
    {
      'icon': Icons.attach_money,
      'title': 'السعر: منخفض-عالي',
      'color': Colors.blue,
      'sortBy': FilterSortBy.priceAsc,
    },
    {
      'icon': Icons.new_releases,
      'title': 'الأحدث',
      'color': Colors.purple,
      'sortBy': FilterSortBy.newest,
    },
  ];
  
  void _applyQuickFilter(Map<String, dynamic> filter) {
    setState(() {
      if (filter['onSale'] == true) {
        // تطبيق فلتر العروض
        // يتطلب إضافة support في ProductModel
      }
      if (filter['sortBy'] != null) {
        _sortBy = filter['sortBy'];
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تطبيق: ${filter['title']}')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ✨ شريط الفلاتر السريعة
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickFilters.length,
              itemBuilder: (context, index) {
                final filter = _quickFilters[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _applyQuickFilter(filter),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: (filter['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: filter['color'],
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            filter['icon'],
                            color: filter['color'],
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            filter['title'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: filter['color'],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          // ... باقي الفلاتر
        ],
      ),
    );
  }
}
```

---

## 6. تخصيص شكل الفلاتر

### نمط Material 3

```dart
// lib/screens/products/filters_screen.dart

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.arguments.cateName ?? S.of(context).filter),
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.95),
          ],
        ),
      ),
      child: // ... المحتوى
    ),
  );
}
```

### فلاتر بشكل Cards

```dart
Widget _buildFilterCard({
  required String title,
  required IconData icon,
  required Widget child,
}) {
  return Card(
    elevation: 2,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: ExpansionTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ],
    ),
  );
}
```

---

## 🎨 نصائح إضافية

### 1. Animation للفلاتر
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  // ... properties
)
```

### 2. Haptic Feedback
```dart
import 'package:flutter/services.dart';

void _onFilterSelected() {
  HapticFeedback.lightImpact();
  // ... apply filter
}
```

### 3. Debouncing للـ Price Slider
```dart
import 'package:easy_debounce/easy_debounce.dart';

void _onPriceChanged(double min, double max) {
  EasyDebounce.debounce(
    'price-filter',
    const Duration(milliseconds: 500),
    () {
      _minPrice = min;
      _maxPrice = max;
      _updateProductCount();
    },
  );
}
```

---

## 📝 ملاحظات نهائية

- اختبر كل تخصيص بشكل جيد قبل النشر
- تأكد من التوافق مع مختلف أحجام الشاشات
- اهتم بتجربة المستخدم (UX)
- استخدم الـ Analytics لقياس فعالية الفلاتر

---

**Happy Customizing! 🎨**

*آخر تحديث: 16 ديسمبر 2024*
