// Copyright 2018-present the Flutter authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/material.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../modules/dynamic_layout/helper/helper.dart';
import '../../services/service_config.dart';
import 'backdrop_constants.dart';

const Cubic _kAccelerateCurve = Cubic(0.548, 0.0, 0.757, 0.464);
const Cubic _kDecelerateCurve = Cubic(0.23, 0.94, 0.41, 1.0);
const double _kPeakVelocityTime = 0.248210;
const double _kPeakVelocityProgress = 0.379146;

class _FrontLayer extends StatelessWidget {
  const _FrontLayer({this.onTap, this.child, this.visible});

  final VoidCallback? onTap;
  final Widget? child;
  final bool? visible;

  @override
  Widget build(BuildContext context) {
    var radius = visible! ? 12.0 : 16.0;

    return Material(
      elevation: 16.0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: visible! ? 10.0 : 40.0,
              alignment: AlignmentDirectional.centerStart,
            ),
          ),
          Expanded(
            child: child!,
          ),
        ],
      ),
    );
  }
}

class _BackdropTitle extends AnimatedWidget {
  final Function? onPress;
  final Widget frontTitle;
  final Widget backTitle;
  final bool? visible;
  final Color? titleColor;

  const _BackdropTitle({
    required super.listenable,
    this.onPress,
    this.visible,
    this.titleColor,
    required this.frontTitle,
    required this.backTitle,
  });

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = CurvedAnimation(
      parent: listenable as Animation<double>,
      curve: const Interval(0.0, 0.78),
    );

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.titleLarge!.copyWith(
        color: titleColor ?? Colors.white,
      ),
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      child: Stack(
        children: <Widget>[
          Opacity(
            opacity: CurvedAnimation(
              parent: ReverseAnimation(animation),
              curve: const Interval(0.5, 1.0),
            ).value,
            child: FractionalTranslation(
              translation: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(0.5, 0.0),
              ).evaluate(animation),
              child: backTitle,
            ),
          ),
          Opacity(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.5, 1.0),
            ).value,
            child: FractionalTranslation(
              translation: Tween<Offset>(
                begin: const Offset(-0.25, 0.0),
                end: Offset.zero,
              ).evaluate(animation),
              child: frontTitle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds a Backdrop.
///
/// A Backdrop widget has two layers, front and back. The front layer is shown
/// by default, and slides down to show the back layer, from which a user
/// can make a selection. The user can also configure the titles for when the
/// front or back layer is showing.
class Backdrop extends StatefulWidget {
  final Widget frontLayer;
  final Widget backLayer;
  final Widget frontTitle;
  final Widget backTitle;
  final Widget? appbarCategory;
  final AnimationController controller;
  final bool showFilter;
  final bool isBlog;
  final VoidCallback? onTapShareButton;
  final bool hasAppBar;

  // إضافة callback لتطبيق المرشحات
  final VoidCallback? onApplyFilters;

  /// This color is pick from the Horizontal Config on Home Screen
  /// use to override the Backdrop color
  final Color? bgColor;

  const Backdrop({
    required this.frontLayer,
    required this.backLayer,
    required this.frontTitle,
    required this.backTitle,
    required this.controller,
    this.appbarCategory,
    this.showFilter = true,
    this.isBlog = false,
    this.bgColor,
    this.onTapShareButton,
    this.hasAppBar = false,
    this.onApplyFilters,
  });

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop>
    with SingleTickerProviderStateMixin {
  final GlobalKey _backdropKey = GlobalKey(debugLabel: 'Backdrop');
  late AnimationController _controller;
  late Animation<RelativeRect> _layerAnimation;

  // متغير لتتبع ما إذا تم تطبيق المرشحات
  bool _filtersApplied = false;

  /// background color
  bool get useBackgroundColor =>
      productFilterColor?.useBackgroundColor ?? false;

  bool get userPrimaryColorLight =>
      productFilterColor?.usePrimaryColorLight ?? false;

  Color get systemBackgroundColor => useBackgroundColor
      ? Theme.of(context).colorScheme.surface
      : (userPrimaryColorLight
      ? Theme.of(context).primaryColorLight
      : Theme.of(context).primaryColor);

  Color get backgroundColor =>
      widget.bgColor ??
          ((productFilterColor?.backgroundColor != null
              ? HexColor(productFilterColor?.backgroundColor)
              : systemBackgroundColor))
              .withValueOpacity(
              productFilterColor?.backgroundColorOpacity.toDouble() ?? 1.0);

  /// label color
  Color get systemLabelColor => (productFilterColor?.useAccentColor ?? false)
      ? Theme.of(context).colorScheme.secondary
      : Colors.white;

  Color get labelColor {
    /// use the label color from bgColor
    if (widget.bgColor != null || productFilterColor?.labelColor == null) {
      return backgroundColor.getColorBasedOnBackground;
    }

    return (productFilterColor?.labelColor != null
        ? HexColor(productFilterColor?.labelColor)
        : systemLabelColor)
        .withValueOpacity(
        productFilterColor?.labelColorOpacity.toDouble() ?? 1.0);
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    // فتح المرشحات تلقائياً عند بدء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_filtersApplied) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get _frontLayerVisible {
    final status = _controller.status;
    return status == AnimationStatus.completed ||
        status == AnimationStatus.forward;
  }

  void _toggleBackdropLayerVisibility() {
    setState(() {
      _frontLayerVisible ? _controller.reverse() : _controller.forward();
    });
  }

  // دالة لتطبيق المرشحات وإغلاق قائمة المرشحات
  void _applyFiltersAndClose() {
    setState(() {
      _filtersApplied = true;
    });

    // استدعاء callback إذا كان موجوداً
    widget.onApplyFilters?.call();

    // إغلاق المرشحات وعرض المنتجات
    if (!_frontLayerVisible) {
      _controller.forward();
    }
  }

  Animation<RelativeRect> _getLayerAnimation(Size layerSize, double layerTop) {
    Curve firstCurve;
    Curve secondCurve;
    double firstWeight;
    double secondWeight;
    Animation animation;

    if (_frontLayerVisible) {
      firstCurve = _kAccelerateCurve;
      secondCurve = _kDecelerateCurve;
      firstWeight = _kPeakVelocityTime;
      secondWeight = 1.0 - _kPeakVelocityTime;
      animation = CurvedAnimation(
        parent: _controller.view,
        curve: const Interval(0.0, 0.78),
      );
    } else {
      firstCurve = _kDecelerateCurve.flipped;
      secondCurve = _kAccelerateCurve.flipped;
      firstWeight = 1.0 - _kPeakVelocityTime;
      secondWeight = _kPeakVelocityTime;
      animation = _controller.view;
    }

    return TweenSequence(
      <TweenSequenceItem<RelativeRect>>[
        TweenSequenceItem<RelativeRect>(
          tween: RelativeRectTween(
            begin: RelativeRect.fromLTRB(
              0.0,
              layerTop,
              0.0,
              layerTop - layerSize.height,
            ),
            end: RelativeRect.fromLTRB(
              0.0,
              layerTop * _kPeakVelocityProgress,
              0.0,
              (layerTop - layerSize.height) * _kPeakVelocityProgress,
            ),
          ).chain(CurveTween(curve: firstCurve)),
          weight: firstWeight,
        ),
        TweenSequenceItem<RelativeRect>(
          tween: RelativeRectTween(
            begin: RelativeRect.fromLTRB(
              0.0,
              layerTop * _kPeakVelocityProgress,
              0.0,
              (layerTop - layerSize.height) * _kPeakVelocityProgress,
            ),
            end: RelativeRect.fill,
          ).chain(CurveTween(curve: secondCurve)),
          weight: secondWeight,
        ),
      ],
    ).animate(animation as Animation<double>);
  }

  Widget _buildStack(BuildContext context, BoxConstraints constraints) {
    const layerTitleHeight = 20.0;
    final layerSize = constraints.biggest;
    final layerTop = layerSize.height - layerTitleHeight;
    _layerAnimation = _getLayerAnimation(layerSize, layerTop);

    return Stack(
      key: _backdropKey,
      fit: StackFit.expand,
      children: <Widget>[
        // طبقة الخلفية (المرشحات)
        Container(
          color: backgroundColor,
          child: Theme(
            data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  secondary: labelColor,
                ),
                textTheme: Theme.of(context).textTheme.copyWith(
                  titleMedium:
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: labelColor,
                  ),
                  titleLarge:
                  Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: labelColor,
                  ),
                )),
            child: Column(
              children: [
                Expanded(child: widget.backLayer),
                // زر تطبيق المرشحات
                if (!_frontLayerVisible)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _applyFiltersAndClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: labelColor,
                        foregroundColor: backgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text(
                        'تطبيق المرشحات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // الطبقة الأمامية (المنتجات)
        PositionedTransition(
          rect: _layerAnimation,
          child: _FrontLayer(
            onTap: widget.showFilter ? _toggleBackdropLayerVisibility : null,
            visible: _frontLayerVisible,
            child: widget.frontLayer,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          if (!Layout.isDisplayDesktop(context))
            AppBar(
              primary: !widget.hasAppBar,
              backgroundColor: backgroundColor,
              elevation: 0.0,
              titleSpacing: 0.0,
              title: _BackdropTitle(
                listenable: _controller.view,
                titleColor: labelColor,
                onPress:
                widget.showFilter ? _toggleBackdropLayerVisibility : null,
                frontTitle: widget.frontTitle,
                backTitle: widget.backTitle,
                visible: _frontLayerVisible,
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: labelColor,
                ),
                onPressed: () {
                  if (kIsWeb) {
                    eventBus.fire(const EventOpenCustomDrawer());
                  }
                  Navigator.pop(context);
                },
              ),
              actions: <Widget>[
                if (dynamicLinkConfig.allowShareLink &&
                    ServerConfig().isWooType &&
                    !ServerConfig().isListingType &&
                    !widget.isBlog)
                  IconButton(
                    icon: Icon(
                      Icons.share,
                      size: 18.0,
                      color: labelColor,
                    ),
                    onPressed: () => widget.onTapShareButton?.call(),
                  ),
                if (widget.showFilter)
                  IconButton(
                    icon: AnimatedIcon(
                      icon: AnimatedIcons.close_menu,
                      progress: _controller,
                    ),
                    color: labelColor,
                    onPressed: _toggleBackdropLayerVisibility,
                  ),
              ],
            ),
          if (!ServerConfig().isListingType && widget.appbarCategory != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _frontLayerVisible
                  ? Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context)
                      .colorScheme
                      .copyWith(
                    secondary: labelColor,
                    surface: backgroundColor,
                  )
                      .copyWith(surface: backgroundColor),
                ),
                child: widget.appbarCategory!,
              )
                  : const SizedBox(),
            ),
          Expanded(
            child: Row(
              children: <Widget>[
                Layout.isDisplayDesktop(context)
                    ? Container(
                  width: BackdropConstants.drawerWidth,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(bottom: 32),
                  color: backgroundColor,
                  child: Column(
                    children: [
                      Expanded(child: widget.backLayer),
                      // زر تطبيق المرشحات للشاشات الكبيرة
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onApplyFilters?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: labelColor,
                            foregroundColor: backgroundColor,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: Text(
                            'تطبيق المرشحات',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    : const SizedBox(),
                Expanded(
                  child: LayoutBuilder(
                    builder: _buildStack,
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