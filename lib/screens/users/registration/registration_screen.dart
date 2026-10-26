import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:provider/provider.dart';

import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../common/extensions/string_message_ext.dart';
import '../../../common/tools.dart';
import '../../../common/tools/flash.dart';
import '../../../models/index.dart'
    show AppModel, CartModel, PointModel, User, UserModel;
import '../../../modules/dynamic_layout/helper/helper.dart';
import '../../../modules/sms_login/sms_login.dart';
import '../../../modules/vendor_on_boarding/screen_index.dart';
import '../../../routes/flux_navigate.dart';
import '../../../services/service_config.dart';
import '../../../services/services.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/phone_number_field_widget.dart';
import '../../../widgets/common/webview.dart';
import '../../home/privacy_term_screen.dart';
import 'mixins/config_register_mixin.dart';
import 'registration_screen_web.dart';

enum RegisterType { customer, vendor, delivery, owner }

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Layout.isDisplayDesktop(context)) {
      return const RegistrationScreenWeb();
    }
    return const RegistrationScreenMobile();
  }
}

class RegistrationScreenMobile extends StatefulWidget {
  const RegistrationScreenMobile();

  @override
  State<RegistrationScreenMobile> createState() =>
      _RegistrationScreenMobileState();
}

class _RegistrationScreenMobileState extends State<RegistrationScreenMobile>
    with ConfigRegisterMixin {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? firstName, lastName, emailAddress, username, phoneNumber, password;
  RegisterType? _registerTypeSelected = RegisterType.customer;
  bool isChecked = false;

  bool isPlatformSupported = ![
    ConfigType.bigCommerce,
    ConfigType.notion,
    ConfigType.shopify,
    ConfigType.presta,
    ConfigType.opencart,
    ConfigType.magento,
  ].contains(ServerConfig().type);

  final firstNameNode = FocusNode();
  final lastNameNode = FocusNode();
  final phoneNumberNode = FocusNode();
  final emailNode = FocusNode();
  final passwordNode = FocusNode();
  final usernameNode = FocusNode();

  bool get _isSelectedVendorType =>
      _registerTypeSelected == RegisterType.vendor;
  bool get _isSelectedDeliveryType =>
      _registerTypeSelected == RegisterType.delivery;
  bool get _isSelectedOwnerType => _registerTypeSelected == RegisterType.owner;

  Future<bool> _showDialogUnderApproval() {
    return context.showFluxDialogText(
      title: S.of(context).accountApprovalTitle,
      body: S.of(context).accountIsPendingApproval,
      primaryAction: S.of(context).ok,
    );
  }

  Widget _buildLabeledTextField({
    required BuildContext context,
    required String label,
    String? hint,
    TextEditingController? controller,
    FocusNode? focusNode,
    FocusNode? nextNode,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    bool showEyeIcon = false,
    ValueChanged<String>? onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          controller: controller,
          focusNode: focusNode,
          nextNode: nextNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          showEyeIcon: showEyeIcon,
          hintText: hint,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _welcomeDiaLog(User user) {
    Provider.of<CartModel>(context, listen: false).setUser(user);
    Provider.of<PointModel>(context, listen: false).getMyPoint(user.cookie);
    final model = Provider.of<UserModel>(context, listen: false);

    /// Show VendorOnBoarding.
    if (kVendorConfig.vendorRegister &&
        Provider.of<AppModel>(context, listen: false).isMultiVendor &&
        user.isVender) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => VendorOnBoarding(
            user: user,
            onFinish: () {
              model.getUser();
              var email = user.email;
              _showMessage(
                '${S.of(ctx).welcome} $email!',
                isError: false,
              );
              var routeFound = false;
              var routeNames = [RouteList.dashboard, RouteList.productDetail];
              Navigator.popUntil(ctx, (route) {
                if (routeNames.any((element) =>
                route.settings.name?.contains(element) ?? false)) {
                  routeFound = true;
                }
                return routeFound || route.isFirst;
              });

              if (!routeFound) {
                Navigator.of(ctx).pushReplacementNamed(RouteList.dashboard);
              }
            },
          ),
        ),
      );
      return;
    }

    var email = user.email;
    _showMessage(
      '${S.of(context).welcome} $email!',
      isError: false,
    );
    if (Services().widget.isRequiredLogin) {
      Navigator.of(context).pushReplacementNamed(RouteList.dashboard);
      return;
    }
    var routeFound = false;
    var routeNames = [RouteList.dashboard, RouteList.productDetail];
    Navigator.popUntil(context, (route) {
      if (routeNames
          .any((element) => route.settings.name?.contains(element) ?? false)) {
        routeFound = true;
      }
      return routeFound || route.isFirst;
    });

    if (!routeFound) {
      Navigator.of(context).pushReplacementNamed(RouteList.dashboard);
    }
  }

  Future<void> _onRegisterSuccess(User user) async {
    if (!user.isVender && _registerTypeSelected == RegisterType.vendor) {
      await _showDialogUnderApproval();
    }
    _welcomeDiaLog(user);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    firstNameNode.dispose();
    lastNameNode.dispose();
    emailNode.dispose();
    passwordNode.dispose();
    phoneNumberNode.dispose();
    usernameNode.dispose();
    super.dispose();
  }

  void _showMessage(
      String text, {
        bool isError = true,
      }) {
    if (!mounted) {
      return;
    }
    FlashHelper.message(
      context,
      message: text.improveMessage(context),
      isError: isError,
    );
  }

  Future<void> _submitRegister({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? emailAddress,
    String? username,
    String? password,
    bool? isVendor,
    bool? isDelivery,
    bool? isOwner,
  }) async {
    // Check internet connection before attempting registration
    if (!await context.checkInternet()) {
      return;
    }
    final invalidFirstName = firstName?.trim().isEmpty ?? true;
    final invalidLastName = lastName?.trim().isEmpty ?? true;
    final invalidUsername = (requireUsernameWhenRegister &&
        (username?.trim().isEmpty ?? true && isPlatformSupported));
    final invalidEmail = emailAddress?.trim().isEmpty ?? true;
    final invalidPassword = password?.isEmpty ?? true;
    final invalidPhoneNumber = (showPhoneNumberWhenRegister &&
        requirePhoneNumberWhenRegister &&
        (phoneNumber?.trim().isEmpty ?? true));

    if (invalidFirstName ||
        invalidLastName ||
        invalidUsername ||
        invalidEmail ||
        invalidPassword ||
        invalidPhoneNumber) {
      _showMessage(S.of(context).pleaseInputFillAllFields);
    } else if (isChecked == false) {
      _showMessage(S.of(context).pleaseAgreeTerms);
    } else {
      if (!emailAddress.validateEmail()) {
        _showMessage(S.of(context).errorEmailFormat);
        return;
      }

      if (password == null || password.length < 8) {
        _showMessage(S.of(context).errorPasswordFormat);
        return;
      }

      if (showPhoneNumberWhenRegister &&
          (phoneNumber?.trim().isNotEmpty ?? false)) {
        final isPhoneUsed =
            await Services().api.isUserExisted(phone: phoneNumber);
        if (isPhoneUsed) {
          _showMessage('رقم الهاتف مستخدم مسبقًا، يرجى تغيير البيانات.');
          return;
        }
      }

      await Provider.of<UserModel>(context, listen: false).createUser(
        username: username,
        email: emailAddress,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        success: _onRegisterSuccess,
        fail: _showMessage,
        isVendor: isVendor,
        isDelivery: isDelivery,
        isOwner: isOwner,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appModel = Provider.of<AppModel>(context, listen: true);
    final themeConfig = appModel.themeConfig;
    final isShowRegisterOptions =
        isVendorRegister || isDeliveryRegister || isOwnerRegister;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0.0,
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => Tools.hideKeyboard(context),
            child: ListenableProvider.value(
              value: Provider.of<UserModel>(context),
              child: Consumer<UserModel>(
                builder: (context, value, child) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 10.0),
                            Center(
                              child: FractionallySizedBox(
                                widthFactor: 0.8,
                                child: FluxImage(
                                  useExtendedImage: false,
                                  imageUrl: themeConfig.logo,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 30.0,
                            ),
                            Text(
                              S.of(context).createAnAccount,
                              style: theme.textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30.0),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.dividerColor.withValues(alpha: 0.4),
                                ),
                              ),
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabeledTextField(
                                    context: context,
                                    label: S.of(context).firstName,
                                    focusNode: firstNameNode,
                                    nextNode: lastNameNode,
                                    hint: S.of(context).enterYourFirstName,
                                    onChanged: (value) => firstName = value,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabeledTextField(
                                    context: context,
                                    label: S.of(context).lastName,
                                    focusNode: lastNameNode,
                                    nextNode:
                                        showPhoneNumberWhenRegister ? phoneNumberNode : emailNode,
                                    hint: S.of(context).enterYourLastName,
                                    onChanged: (value) => lastName = value,
                                  ),
                                  const SizedBox(height: 16),
                                  if (showPhoneNumberWhenRegister) ...[
                                    Text(
                                      S.of(context).phoneNumber,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    PhoneNumberFieldWidget(
                                      phoneController: _phoneController,
                                      labelText: null,
                                      showFieldLabel: false,
                                      textInputAction: TextInputAction.next,
                                      onPhoneNumberChanged: (value) {
                                        final national = value.parseNumber() ?? '';
                                        phoneNumber = national;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildLabeledTextField(
                                    context: context,
                                    label: S.of(context).email,
                                    controller: _emailController,
                                    focusNode: emailNode,
                                    nextNode: requireUsernameWhenRegister && isPlatformSupported
                                        ? usernameNode
                                        : passwordNode,
                                    keyboardType: TextInputType.emailAddress,
                                    hint: S.of(context).enterYourEmailOrUsername,
                                    onChanged: (value) => emailAddress = value,
                                  ),
                                  const SizedBox(height: 16),
                                  if (requireUsernameWhenRegister && isPlatformSupported) ...[
                                    _buildLabeledTextField(
                                      context: context,
                                      label: S.of(context).username,
                                      focusNode: usernameNode,
                                      nextNode: passwordNode,
                                      hint: S.of(context).enterYourUsername,
                                      onChanged: (value) => username = value,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildLabeledTextField(
                                    context: context,
                                    label: S.of(context).password,
                                    focusNode: passwordNode,
                                    hint: S.of(context).enterYourPassword,
                                    obscureText: true,
                                    showEyeIcon: true,
                                    textInputAction: TextInputAction.done,
                                    onChanged: (value) => password = value,
                                  ),
                                  const SizedBox(height: 20),
                                  // Checkbox for privacy policy agreement with border
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.primaryColor,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Checkbox(
                                          value: isChecked,
                                          activeColor: theme.primaryColor,
                                          checkColor: Colors.white,
                                          side: BorderSide(
                                            color: theme.primaryColor,
                                            width: 2.0,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              isChecked = value ?? false;
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: RichText(
                                            maxLines: 3,
                                            text: TextSpan(
                                              text: S.of(context).bySignup,
                                              style: theme.textTheme.bodyLarge,
                                              children: [
                                                const WidgetSpan(child: SizedBox(width: 4)),
                                                TextSpan(
                                                  text: S.of(context).agreeWithPrivacy,
                                                  style: TextStyle(
                                                    color: theme.primaryColor,
                                                    decoration: TextDecoration.underline,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  recognizer: TapGestureRecognizer()
                                                    ..onTap = () {
                                                      final appModel =
                                                          Provider.of<AppModel>(context, listen: false);
                                                      final privacyUrl = appModel.appConfig?.settings.privacy ??
                                                          kAdvanceConfig.privacyPoliciesPageUrl;

                                                      if (privacyUrl != null && privacyUrl.isNotEmpty) {
                                                        FluxNavigate.push(
                                                          MaterialPageRoute(
                                                            builder: (context) => WebView(
                                                              privacyUrl,
                                                              title: S.of(context).agreeWithPrivacy,
                                                            ),
                                                          ),
                                                          forceRootNavigator: true,
                                                          context: context,
                                                        );
                                                      } else {
                                                        FluxNavigate.push(
                                                          MaterialPageRoute(
                                                            builder: (context) => const PrivacyTermScreen(
                                                              showAgreeButton: false,
                                                            ),
                                                          ),
                                                          forceRootNavigator: true,
                                                          context: context,
                                                        );
                                                      }
                                                    },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _registerTypeSelected ==
                                            RegisterType.vendor,
                                        onChanged: (value) {
                                          setState(() {
                                            _registerTypeSelected =
                                                value == true
                                                    ? RegisterType.vendor
                                                    : RegisterType.customer;
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          S.of(context).registerAsVendor,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        foregroundColor: theme.colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      onPressed: value.loading == true
                                          ? null
                                          : () {
                                              _submitRegister(
                                                firstName: firstName,
                                                lastName: lastName,
                                                phoneNumber: phoneNumber ??
                                                    _phoneController.text.trim(),
                                                emailAddress: emailAddress,
                                                username: username,
                                                password: password,
                                                isVendor: _isSelectedVendorType,
                                                isDelivery:
                                                    _isSelectedDeliveryType,
                                                isOwner: _isSelectedOwnerType,
                                              );
                                            },
                                      child: Text(
                                        value.loading == true
                                            ? S.of(context).loading
                                            : S.of(context).createAnAccount,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(child: Divider(color: theme.dividerColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text(S.of(context).or),
                                ),
                                Expanded(child: Divider(color: theme.dividerColor)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Redirect to SMS Login for registration
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  key: const Key('registerSMSButton'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: (value.loading == true || !isChecked)
                                      ? null
                                      : () async {
                                          if (!isChecked) {
                                            _showMessage(S.of(context).pleaseAgreeTerms);
                                            return;
                                          }
                                          if (kAdvanceConfig.enableNewSMSLogin) {
                                            final model = Provider.of<UserModel>(context, listen: false);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SMSLoginScreen(
                                                  onSuccess: (user) async {
                                                    await model.setUser(user);
                                                    Navigator.of(context).pop();
                                                    _onRegisterSuccess(user);
                                                  },
                                                ),
                                              ),
                                            );
                                          } else {
                                            Navigator.pushNamed(context, RouteList.loginSMS);
                                          }
                                        },
                                  child: Text(
                                    S.of(context).signInWithSMS,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10.0),
                            if (isShowRegisterOptions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: RadioGroup<RegisterType>(
                                  groupValue: _registerTypeSelected,
                                  onChanged: (RegisterType? value) {
                                    setState(() {
                                      _registerTypeSelected = value;
                                    });
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${S.of(context).registerAs}:',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      _buildRegisterType(
                                        RegisterType.customer,
                                        S.of(context).customer,
                                      ),
                                      if (isVendorRegister)
                                        _buildRegisterType(
                                          RegisterType.vendor,
                                          S.of(context).vendor,
                                        ),
                                      if (isOwnerRegister)
                                        _buildRegisterType(
                                          RegisterType.owner,
                                          S.of(context).owner,
                                        ),
                                      if (isDeliveryRegister)
                                        _buildRegisterType(
                                          RegisterType.delivery,
                                          S.of(context).deliveryBoy,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20.0),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 10.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    '${S.of(context).or} ',
                                  ),
                                  InkWell(
                                    onTap: () {
                                      final canPop =
                                          ModalRoute.of(context)!.canPop;
                                      if (canPop) {
                                        Navigator.pop(context);
                                      } else {
                                        NavigateTools.navigateToLogin(context,
                                            replacement: true);
                                      }
                                    },
                                    child: Text(
                                      S.of(context).loginToYourAccount,
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        decoration: TextDecoration.underline,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterType(RegisterType registerType, String label) {
    var description = '';
    switch (registerType) {
      case RegisterType.customer:
        description = ServerConfig().isListeoType
            ? S.of(context).customerRoleDescription
            : '';
        break;
      case RegisterType.owner:
        description = S.of(context).ownerRoleDescription;
        break;
      default:
        description = '';
    }

    return Row(
      children: [
        Radio<RegisterType>(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: registerType,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (description.isNotEmpty)
          InkWell(
            onTap: () => context.showFluxDialogText(
              title: label,
              body: description,
              primaryAction: S.of(context).ok,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
      ],
    );
  }
}