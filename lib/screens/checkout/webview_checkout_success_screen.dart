import 'package:flutter/material.dart';

import '../../common/constants.dart';
import '../../models/index.dart' show Order;
import 'widgets/success.dart';

class WebviewCheckoutSuccessScreen extends StatelessWidget {
  final Order? order;
  final String? orderNum;

  const WebviewCheckoutSuccessScreen({this.order, this.orderNum});

  void _goHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteList.dashboard,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goHome(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goHome(context),
          ),
          backgroundColor: kGrey200,
          elevation: 0.0,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: OrderedSuccess(
            order: order,
            orderNum: orderNum,
          ),
        ),
      ),
    );
  }
}
