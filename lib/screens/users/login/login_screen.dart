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
import '../katina_auth_style.dart';
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
      backgroundColor: KatinaAuthStyle.mist,
      body: AutoHideKeyboard(
        child: IgnorePointer(
          ignoring: isLoading,
          child: Consumer<UserModel>(
            builder: (context, model, child) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        KatinaAuthStyle.heroHeader(
                          context: context,
                          logo: FluxImage(
                            imageUrl: themeConfig.logo,
                            fit: BoxFit.contain,
                            useExtendedImage: false,
                          ),
                          title: 'مرحباً بك في كاتينة',
                          subtitle: 'سجّل دخولك لمتابعة طلباتك وتسوق قطع الغيار بسهولة',
                        ),
                        if (!Services().widget.isRequiredLogin &&
                            !ModalRoute.of(context)!.canPop)
                          PositionedDirectional(
                            top: MediaQuery.paddingOf(context).top + 4,
                            end: 8,
                            child: IconButton(
                              onPressed: loginDone,
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          width: screenSize.width,
                          constraints: const BoxConstraints(maxWidth: 520),
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                          decoration: KatinaAuthStyle.cardDecoration(context),
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  S.of(context).phoneNumber,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                PhoneNumberFieldWidget(
                                  phoneController: usernameCtrl,
                                  labelText: null,
                                  textInputAction: TextInputAction.next,
                                  onPhoneNumberChanged: (value) {
                                    final rawValue = value.phoneNumber ??
                                        value.parseNumber() ??
                                        '';
                                    _latestPhoneInput = rawValue;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  S.of(context).password,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                CustomTextField(
                                  controller: passwordCtrl,
                                  focusNode: _passwordFocusNode,
                                  obscureText: true,
                                  showEyeIcon: true,
                                  hintText: S.of(context).password,
                                ),
                                if (kLoginSetting.isResetPasswordSupported)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: isLoading
                                          ? null
                                          : () => launchForgetPasswordURL(
                                              forgetPasswordUrl),
                                      child: Text(S.of(context).resetPassword),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                StaggerAnimation(
                                  key: const Key('loginPhoneButton'),
                                  titleButton: S.of(context).signIn,
                                  buttonController: loginButtonController.view
                                      as AnimationController,
                                  onTap: () => isLoading ? null : _onTapLogin(),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () => loginWithSMS(context),
                                    child: Text(S.of(context).signInWithSMS),
                                  ),
                                ),
                                if (kLoginSetting.enableRegister) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(S.of(context).dontHaveAccount),
                                      GestureDetector(
                                        onTap: () =>
                                            NavigateTools.navigateRegister(
                                                context),
                                        child: Text(
                                          ' ${S.of(context).signup}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: KatinaAuthStyle.goldDeep,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}