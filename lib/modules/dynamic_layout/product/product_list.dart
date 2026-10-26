import 'package:flutter/material.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:provider/provider.dart';

import '../../../common/constants.dart';
import '../../../common/tools.dart';
import '../../../models/entities/product.dart';
import '../../../models/index.dart' show AppModel;
import '../../../models/entities/back_drop_arguments.dart';
import '../../../routes/flux_navigate.dart';
import '../../../screens/detail/mixins/detail_product_price_mixin.dart';
import '../../../services/index.dart';
import '../../../widgets/common/parallax_image.dart';
import '../config/product_config.dart';
import '../helper/helper.dart';
import 'future_builder.dart';

const _widthPercentForWebLayout = 0.32;

/// ProductList widget that uses ProductFutureBuilder and ProductListDefault
class ProductList extends StatelessWidget {
  final ProductConfig config;
  final bool cleanCache;

  const ProductList({
    super.key,
    required this.config,
    this.cleanCache = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = Layout.isDisplayDesktop(context)
            ? constraints.maxWidth
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HeaderView with title and "See All" button
            if (config.name?.isNotEmpty == true || config.showSeeAll)
              Container(
                decoration: BoxDecoration(
                  color: config.backgroundColor != null
                      ? HexColor(config.backgroundColor!)
                      : null,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(config.borderRadius ?? 12.0),
                    topRight: Radius.circular(config.borderRadius ?? 12.0),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: config.hMargin ?? 9.0,
                  vertical: config.vMargin ?? 10.0,
                ),
                child: HeaderView(
                  headerText: config.name ?? '',
                  showSeeAll: config.showSeeAll,
                  callback: config.showSeeAll
                      ? () {
                    FluxNavigate.pushNamed(
                      RouteList.backdrop,
                      arguments: BackDropArguments(
                        config: config.jsonData,
                        data: [],
                      ),
                      context: context,
                    );
                  }
                      : null,
                ),
              ),
            // Product list
            ProductFutureBuilder(
              config: config,
              cleanCache: cleanCache,
              child: ({
                required maxWidth,
                required maxHeight,
                required List<Product> products,
              }) {
                return ProductListDefault(
                  maxWidth: maxWidth,
                  products: products,
                  config: config,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class ProductListDefault extends StatelessWidget {
  final maxWidth;
  final List<Product>? products;
  final int? row;
  final ProductConfig config;
  final Color? background;
  final DetailProductPriceStateUI? priceData;

  const ProductListDefault({
    super.key,
    this.maxWidth,
    this.products,
    this.row = 1,
    required this.config,
    this.background,
    this.priceData,
  });

  String get layout => config.layout ?? Layout.threeColumn;

  List<Widget> renderProducts(
      BuildContext context, {
        required double productCardWidth,
        double? spaceWidth,
        DetailProductPriceStateUI? priceData,
      }) {
    final listProducts = products ?? [];
    final isDesktop = Layout.isDisplayDesktop(context);
    var ratioProductImage =
        Provider.of<AppModel>(context, listen: false).ratioProductImage;

    /// allow override imageRatio when there is single Row
    if (config.rows == 1) {
      ratioProductImage = config.imageRatio;
    }

    if (isDesktop) {
      return [
        if (listProducts.isNotEmpty)
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Services().widget.renderProductCardView(
                item: listProducts[i],
                width: productCardWidth,
                maxWidth: maxWidth,
                ratioProductImage: ratioProductImage,
                config: config,
                useDesktopStyle: true,
                priceData: priceData,
              ),
            )
      ];
    }

    return [
      if (spaceWidth != null)
        SizedBox(
          width: spaceWidth,
        ),
      if (listProducts.isNotEmpty)
        for (var i = 0; i < listProducts.length; i++)
          Services().widget.renderProductCardView(
            item: listProducts[i],
            width: productCardWidth,
            maxWidth: maxWidth,
            ratioProductImage: ratioProductImage,
            config: config,
            priceData: priceData,
          )
    ];
  }

  Widget renderHorizontal(BuildContext context,
      {bool enableBackground = false}) {
    final isDesktop = Layout.isDisplayDesktop(context);
    final isCarouselView = config.layout == Layout.carousel;

    final productCardWidth = isDesktop
        ? maxWidth * _widthPercentForWebLayout
        : Layout.buildProductWidth(
      screenWidth: maxWidth,
      layout: layout,
    );

    final padding = !isCarouselView &&
        (enableBackground ||
            config.cardDesign.isSimpleCard ||
            config.cardDesign.isFlat)
        ? 0.0
        : 12.0;
    final horizontalWidth = maxWidth - padding;
    final listProducts = products is List ? (products as List) : [];
    final scrollController = ScrollController();

    /// wrap the product for Desktop mode
    if (Layout.isDisplayDesktop(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 13,
        ),
        child: FlexSeparated.row(
          separationSize: 24242424,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: renderProducts(
            context,
            productCardWidth: productCardWidth,
            spaceWidth: enableBackground == false
                ? null
                : (config.spaceWidth ?? productCardWidth),
          ),
        ),
      );
    }

    final backgroundHeight = config.backgroundHeight?.toDouble();
    late final horizontalWidget;

    switch (config.layout) {
      case Layout.carousel:
        final isMobileDisplay = Tools.isPhone(MediaQuery.of(context)) ||
            Tools.isBuilder; //check is in FluxBuilder or not
        final maxHeight = isMobileDisplay ? 350.0 : 610.0; // magic number
        final screenWidth = MediaQuery.of(context).size.width;

        // Calculate product card width for horizontal scroll
        final productCardWidthForScroll = Layout.buildProductWidth(
          screenWidth: horizontalWidth,
          layout: layout,
        );
        // Use smaller spacing for carousel, ignore large spaceWidth values
        final spacing = (config.spaceWidth != null && config.spaceWidth! < 20.0)
            ? config.spaceWidth!.toDouble()
            : 2.0;

        horizontalWidget = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: backgroundHeight ?? maxHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < listProducts.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: i < listProducts.length - 1 ? spacing : 0,
                          ),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            color: Colors.white,
                            child: Container(
                              width: productCardWidthForScroll,
                              padding: const EdgeInsets.all(4),
                              child: Services().widget.renderProductCardView(
                                item: listProducts[i],
                                width: productCardWidthForScroll - 8,
                                maxWidth: maxWidth,
                                ratioProductImage: config.rows == 1
                                    ? config.imageRatio
                                    : Provider.of<AppModel>(context, listen: false)
                                    .ratioProductImage,
                                config: config,
                                priceData: priceData,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        horizontalWidget = Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            physics: config.isSnapping ?? false
                ? CustomScrollPhysic(
                width: Layout.buildProductWidth(
                    screenWidth: horizontalWidth, layout: layout))
                : const ScrollPhysics(),
            child: FlexSeparated.row(
              separationSize: 13,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: renderProducts(
                context,
                productCardWidth: productCardWidth,
                spaceWidth: enableBackground == false
                    ? null
                    : (config.spaceWidth ?? productCardWidth),
              ),
            ),
          ),
        );
    }

    final body = Container(
      color: background ??
          Theme.of(context)
              .colorScheme
              .surface
              .withValueOpacity(enableBackground ? 0.0 : 1.0),
      padding: isCarouselView
          ? EdgeInsets.zero
          : EdgeInsetsDirectional.only(start: padding),
      constraints: BoxConstraints(
        minHeight: config.productListItemHeight,
      ),
      child: horizontalWidget,
    );

    // Wrap body with Stack to add arrows at screen edges for carousel
    Widget finalBody = body;
    if (isCarouselView && listProducts.length > 1) {
      finalBody = Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          // Left arrow at screen left edge
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                elevation: 4,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    if (scrollController.hasClients) {
                      final productCardWidthForScroll = Layout.buildProductWidth(
                        screenWidth: horizontalWidth,
                        layout: layout,
                      );
                      final spacing = (config.spaceWidth != null && config.spaceWidth! < 20.0)
                          ? config.spaceWidth!.toDouble()
                          : 2.0;
                      final position = scrollController.position.pixels;
                      final newPosition = (position - productCardWidthForScroll - spacing).clamp(
                        0.0,
                        scrollController.position.maxScrollExtent,
                      );
                      scrollController.animateTo(
                        newPosition,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: HexColor("#f9c374"),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Right arrow at screen right edge
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                elevation: 4,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    if (scrollController.hasClients) {
                      final productCardWidthForScroll = Layout.buildProductWidth(
                        screenWidth: horizontalWidth,
                        layout: layout,
                      );
                      final spacing = (config.spaceWidth != null && config.spaceWidth! < 20.0)
                          ? config.spaceWidth!.toDouble()
                          : 2.0;
                      final position = scrollController.position.pixels;
                      final newPosition = (position + productCardWidthForScroll + spacing).clamp(
                        0.0,
                        scrollController.position.maxScrollExtent,
                      );
                      scrollController.animateTo(
                        newPosition,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: HexColor("#f9c374"),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return HandleAutoSlide.list(
      enable: config.enableAutoSliding,
      durationAutoSliding: config.durationAutoSliding,
      numberOfItems: listProducts.length,
      controller: scrollController,
      child: finalBody,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products == null) return const SizedBox();

    final haveCustomBackground =
        config.backgroundImage != null || config.backgroundColor != null;
    final backgroundHeight = config.backgroundHeight?.toDouble();
    final backgroundWidth = (config.backgroundWidthMode ?? false)
        ? maxWidth
        : config.backgroundWidth?.toDouble();

    var body = renderHorizontal(
      context,
      enableBackground: haveCustomBackground,
    );

    if (haveCustomBackground) {
      body = Stack(
        children: [
          if (config.backgroundColor != null)
            Container(
              height: backgroundHeight ??
                  Layout.buildProductHeight(
                    layout: layout,
                    defaultHeight: maxWidth,
                  ),
              width: backgroundWidth,
              margin: config.marginBGP,
              decoration: BoxDecoration(
                color: config.backgroundColor,
                borderRadius: BorderRadius.circular(config.backgroundRadius),
              ),
            ),
          if (config.backgroundImage != null)
            Container(
              margin: config.marginBGP,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(config.backgroundRadius),
                child: config.enableParallax
                    ? ParallaxImage(
                  image: config.backgroundImage!,
                  fit: ImageTools.boxFit(config.backgroundBoxFit),
                  height: backgroundHeight,
                  ratio: config.parallaxImageRatio,
                  width: backgroundWidth,
                )
                    : FluxImage(
                  imageUrl: config.backgroundImage!,
                  fit: ImageTools.boxFit(config.backgroundBoxFit),
                  height: backgroundHeight,
                  width: backgroundWidth,
                ),
              ),
            ),
          Padding(
            padding: config.paddingBGP ?? EdgeInsets.zero,
            child: body,
          ),
        ],
      );
    }

    return BackgroundColorWidget(
      enable: config.enableBackground,
      child: body,
    );
  }
}