import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:inspireui/inspireui.dart';
import 'package:provider/provider.dart';

import '../../../common/config.dart';
import '../../../common/tools.dart';
import '../../../common/tools/phone_tools.dart';
import '../../../common/tools/biometrics_tools.dart';
import '../../../data/boxes.dart';
import '../../../models/index.dart';
import '../../../modules/dynamic_layout/helper/helper.dart';
import '../../../services/index.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/phone_number_field_widget.dart';
import '../../../widgets/common/login_animation.dart';
import '../../base_screen.dart';
import 'login_screen_web.dart';
import 'mixins/mixin_animation_button_login.dart';
import 'mixins/mixin_login.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Layout.isDisplayDesktop(context)) {
      return const LoginScreenWeb();
    }
    return const LoginScreenMobile();
  }
}

class LoginScreenMobile extends StatefulWidget {
  const LoginScreenMobile();

  @override
  BaseScreen<LoginScreenMobile> createState() => _LoginPageState();
}

class _LoginPageState extends BaseScreen<LoginScreenMobile>
    with TickerProviderStateMixin, AnimationButtonLoginMixin, LoginMixin {
  late BuildContext _parentContext;

  final _passwordFocusNode = FocusNode();
  String _latestPhoneInput = '';

  Future _biometricsLogin(BuildContext context) async {
    var didAuth = await BiometricsTools.instance.localAuth(context);
    if (didAuth) {
      usernameCtrl.text = BiometricsBox().username ?? '';
      passwordCtrl.text = BiometricsBox().password ?? '';
      _onTapLogin();
    }
  }

  void _onTapLogin() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }

    passwordCtrl.text = passwordCtrl.text.trim();
    printLog(
        '[LoginScreen] Attempting login with username="${usernameCtrl.text}"');
    runLogin(context);
  }

  @override
  TextEditingController passwordCtrl = TextEditingController();

  @override
  TextEditingController usernameCtrl = TextEditingController();

  @override
  String get loginUsernameValue {
    final manualInput = usernameCtrl.text.trim();
    final source = manualInput.isNotEmpty ? manualInput : _latestPhoneInput;
    final sanitized = normalizeLibyaPhoneNumber(source);
    return sanitized.isNotEmpty ? sanitized : source;
  }

  @override
  Future<void> beforeCallLogin(
      [AnimationButtonLoginType type =
          AnimationButtonLoginType.usernamePassword]) =>
      playAnimation(type);

  @override
  Future<void> afterCallLogin(bool isLoginSuccess,
      [AnimationButtonLoginType type =
          AnimationButtonLoginType.usernamePassword]) =>
      stopAnimation(type);

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _parentContext = context;
    final appModel = Provider.of<AppModel>(context);
    final screenSize = MediaQuery.sizeOf(context);

    final themeConfig = appModel.themeConfig;
    final forgetPasswordUrl =
        appModel.appConfig?.forgetPassword ?? ServerConfig().forgetPassword;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.0,
        actions: !Services().widget.isRequiredLogin &&
            !ModalRoute.of(context)!.canPop
            ? [
          IconButton(
            onPressed: loginDone,
            icon: const Icon(Icons.close, size: 25),
          )
        ]
            : null,
      ),
      body: SafeArea(
        child: AutoHideKeyboard(
          child: IgnorePointer(
            ignoring: isLoading,
            child: Center(
              child: Consumer<UserModel>(
                builder: (context, model, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    alignment: Alignment.center,
                    width: screenSize.width /
                        (2 / (screenSize.height / screenSize.width)),
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: AutofillGroup(
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            flex: 1,
                            child: FractionallySizedBox(
                              widthFactor: 0.8,
                              child: FluxImage(
                                imageUrl: themeConfig.logo,
                                fit: BoxFit.contain,
                                useExtendedImage: false,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16.0),
                                  Text(
                                    S.of(context).phoneNumber,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8.0),
                                  PhoneNumberFieldWidget(
                                    phoneController: usernameCtrl,
                                    labelText: null,
                                    textInputAction: TextInputAction.next,
                                    labelStyle: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    onPhoneNumberChanged: (value) {
                                      final rawValue = value.phoneNumber ??
                                          value.parseNumber() ??
                                          '';
                                      _latestPhoneInput = rawValue;
                                      final normalized =
                                          normalizeLibyaPhoneNumber(rawValue);
                                      printLog(
                                          '[LoginScreen] onPhoneNumberChanged raw=$rawValue normalized=$normalized');
                                    },
                                  ),
                                  const SizedBox(height: 16.0),
                                  Text(
                                    S.of(context).password,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8.0),
                                  CustomTextField(
                                    controller: passwordCtrl,
                                    focusNode: _passwordFocusNode,
                                    obscureText: true,
                                    showEyeIcon: true,
                                    hintText: S.of(context).password,
                                  ),
                                  const SizedBox(height: 24.0),
                                  if (kLoginSetting.isResetPasswordSupported)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => launchForgetPasswordURL(
                                                forgetPasswordUrl),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              Theme.of(context).primaryColor,
                                        ),
                                        child:
                                            Text(S.of(context).resetPassword),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 20.0),
                                  StaggerAnimation(
                                    key: const Key('loginPhoneButton'),
                                    titleButton: S.of(context).signIn,
                                    buttonController:
                                        loginButtonController.view as AnimationController,
                                    onTap: () => isLoading ? null : _onTapLogin(),
                                  ),
                                  const SizedBox(height: 16.0),
                                  TextButton(
                                    onPressed:
                                        isLoading ? null : () => loginWithSMS(context),
                                    child: Text(S.of(context).signInWithSMS),
                                  ),
                                  const SizedBox(height: 24.0),
                                  if (kLoginSetting.enableRegister)
                                    Column(
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: <Widget>[
                                            Text(S.of(context).dontHaveAccount),
                                            GestureDetector(
                                              onTap: () {
                                                NavigateTools.navigateRegister(context);
                                              },
                                              child: Text(
                                                ' ${S.of(context).signup}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      Theme.of(context).primaryColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 12.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}