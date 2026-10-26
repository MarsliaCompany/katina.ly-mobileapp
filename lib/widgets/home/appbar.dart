import 'package:flutter/material.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:provider/provider.dart';

import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../models/app_model.dart';
import '../../models/cart/cart_base.dart';
import '../../models/notification_model.dart';
import '../../modules/dynamic_layout/helper/helper.dart';
import '../../modules/multi_site/multi_site_factory.dart';
import '../../routes/flux_navigate.dart';
import 'preview_overlay.dart';

class HomeAppBar extends StatefulWidget {
  final configs;
  final bool isPinAppBar;

  const HomeAppBar({
    super.key,
    this.configs,
    this.isPinAppBar = false,
  });

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  @override
  Widget build(BuildContext context) {
    if (Layout.isDisplayDesktop(context)) {
      return const SliverToBoxAdapter();
    }

    List<dynamic> horizonLayout = widget.configs['HorizonLayout'] ?? [];
    Map logoConfig = horizonLayout.firstWhere(
        (element) => element['layout'] == 'logo',
        orElse: () => Map<String, dynamic>.from({}));
    var config = LogoConfig.fromJson(logoConfig);

    // تباين واضح لأيقونة القائمة الجانبية والبحث على خلفية الهيدر
    config
      ..iconColor = HexColor('071018')
      ..iconBackground = HexColor('FCC376')
      ..iconOpacity = 1.0
      ..iconRadius = 12
      ..iconSize = 26
      ..iconSpreadRadius = 8
      ..menuIcon = MenuIcon(name: 'bars', fontFamily: 'CupertinoIcons')
      ..searchIcon = MenuIcon(name: 'search', fontFamily: 'CupertinoIcons');

    return SliverAppBar(
      pinned: widget.isPinAppBar,
      snap: true,
      floating: true,
      titleSpacing: 0,
      elevation: 0,
      forceElevated: true,
      backgroundColor: config.color ??
          Theme.of(context)
              .colorScheme
              .surface
              .withValueOpacity(config.opacity),
      title: PreviewOverlay(
          index: 0,
          config: logoConfig as Map<String, dynamic>?,
          builder: (value) {
            final appModel = Provider.of<AppModel>(context, listen: true);
            return Selector<CartModel, int>(
              selector: (_, cartModel) => cartModel.totalCartQuantity,
              builder: (context, totalCart, child) {
                return LogoWidget(
                  config: config,
                  multiSiteArgument:
                      MultiSiteFactory.instance.createArgument(context),
                  logo: appModel.themeConfig.logo,
                  notificationCount:
                      Provider.of<NotificationModel>(context).unreadCount,
                  totalCart: totalCart,
                  onSearch: () {
                    FluxNavigate.pushNamed(
                      RouteList.homeSearch,
                      context: context,
                    );
                  },
                  onCheckout: () {
                    FluxNavigate.pushNamed(
                      RouteList.cart,
                      context: context,
                    );
                  },
                  onTapNotifications: () {
                    FluxNavigate.pushNamed(
                      RouteList.notify,
                      context: context,
                    );
                  },
                  onTapDrawerMenu: () =>
                      NavigateTools.onTapOpenDrawerMenu(context),
                );
              },
            );
          }),
    );
  }
}
