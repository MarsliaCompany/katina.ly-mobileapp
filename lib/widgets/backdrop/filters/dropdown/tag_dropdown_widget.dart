import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:provider/provider.dart';

import '../../../../models/index.dart' show BlogModel, ProductModel, Tag, TagModel;

class TagDropdownWidget extends StatefulWidget {
  const TagDropdownWidget({
    super.key,
    this.onChanged,
    this.isUseBlog = false,
    this.isBlog = false,
    this.tagId,
    this.allowMultiple = false,
  });

  final Function(List<String> tagId)? onChanged;
  final bool isUseBlog;
  final bool isBlog;
  final List<String>? tagId;
  final bool allowMultiple;

  @override
  State<TagDropdownWidget> createState() => _TagDropdownWidgetState();
}

class _TagDropdownWidgetState extends State<TagDropdownWidget> {
  ProductModel get productModel => context.read<ProductModel>();
  BlogModel get blogModel => context.read<BlogModel>();

  List<String>? get tagId =>
      widget.isUseBlog ? blogModel.tagIds : productModel.tagIds;

  List<String> _tagId = [];
  String? _selectedTagName;

  @override
  void initState() {
    super.initState();
    _tagId = widget.tagId ?? tagId ?? [];
  }

  void _updateSelectedTagName(List<Tag> tags) {
    if (_tagId.isNotEmpty && tags.isNotEmpty) {
      try {
        final selectedTag = tags.firstWhere(
          (tag) => tag.id == _tagId.first,
        );
        _selectedTagName = selectedTag.name;
      } catch (e) {
        _selectedTagName = null;
      }
    } else {
      _selectedTagName = null;
    }
  }

  @override
  void didUpdateWidget(TagDropdownWidget oldWidget) {
    if (oldWidget.tagId != widget.tagId) {
      _tagId = widget.tagId ?? tagId ?? [];
    }
    super.didUpdateWidget(oldWidget);
  }

  void _onTagChanged(String? tagId, String? tagName) {
    setState(() {
      if (tagId == null) {
        _tagId = [];
        _selectedTagName = null;
      } else {
        if (widget.allowMultiple) {
          if (_tagId.contains(tagId)) {
            _tagId.remove(tagId);
          } else {
            _tagId.add(tagId);
          }
        } else {
          _tagId = [tagId];
          _selectedTagName = tagName;
        }
      }
    });
    widget.onChanged?.call(_tagId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isUseBlog) {
      return Selector<BlogModel, List<Tag>>(
        selector: (_, model) => model.tags,
        builder: (_, tagList, child) {
          if (tagList.isEmpty) {
            return const SizedBox();
          }
          return _buildDropdown(tagList);
        },
      );
    }
    return Consumer<TagModel>(
      builder: (_, TagModel tagModel, __) {
        var tagList = tagModel.listVisibleTag?.toList() ?? [];

        if (tagList.isEmpty && !tagModel.isLoading) {
          return const SizedBox();
        }

        return _buildDropdown(tagList);
      },
    );
  }

  Widget _buildDropdown(List<Tag> tagList) {
    // Update selected tag name when tags are available
    _updateSelectedTagName(tagList);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).tag,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _tagId.isNotEmpty ? _tagId.first : null,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            hint: const Text('اختر العلامة'),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(S.of(context).all ?? 'الكل'),
              ),
              ...tagList.map((tag) {
                return DropdownMenuItem<String>(
                  value: tag.id,
                  child: Text(tag.name ?? ''),
                );
              }),
            ],
            onChanged: (value) {
              if (value != null) {
                final selectedTag = tagList.firstWhere(
                  (t) => t.id == value,
                );
                _onTagChanged(value, selectedTag.name);
              } else {
                _onTagChanged(null, null);
              }
            },
          ),
        ],
      ),
    );
  }
}

