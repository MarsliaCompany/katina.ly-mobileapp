import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:provider/provider.dart';

import '../../../common/config.dart';
import '../../../common/tools.dart';
import '../../../common/tools/flash.dart';
import '../../../models/entities/brand.dart';
import '../../../models/index.dart' show AppModel, UserModel;
import '../../../routes/flux_navigate.dart';
import '../../../screens/home/privacy_term_screen.dart';
import '../../../screens/users/registration/mixins/config_register_mixin.dart';
import '../../../services/services.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../models/role.dart';
import '../services/index.dart';

class WholesaleSignUpScreen extends StatefulWidget {
  const WholesaleSignUpScreen();

  @override
  State<WholesaleSignUpScreen> createState() => _WholesaleSignUpScreenState();
}

class _WholesaleSignUpScreenState extends State<WholesaleSignUpScreen>
    with ConfigRegisterMixin {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _emailController = TextEditingController();
  final _services = MembershipServices();

  List<WholesaleRole>? _roles;
  String? _selectedRole;
  List<Brand> _rootBrands = [];
  bool _isLoadingBrands = false;
  String? _selectedBrandId;
  String? _selectedBrandLabel;

  String? firstName, lastName, emailAddress, username, password, phoneNumber;
  bool isChecked = false;
  bool isLoading = false;

  final firstNameNode = FocusNode();
  final lastNameNode = FocusNode();
  final usernameNode = FocusNode();
  final emailNode = FocusNode();
  final passwordNode = FocusNode();
  final phoneNumberNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      _roles = await _services.getRoles(context);
      setState(() {
        if (_roles?.isNotEmpty ?? false) {
          _selectedRole = _roles?.first.key;
        }
      });
      if (mounted) {
        _loadRootBrands();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    firstNameNode.dispose();
    lastNameNode.dispose();
    emailNode.dispose();
    passwordNode.dispose();
    usernameNode.dispose();
    phoneNumberNode.dispose();
    super.dispose();
  }

  Future<void> _loadRootBrands() async {
    try {
      setState(() {
        _isLoadingBrands = true;
      });
      final brands = await Services().api.getBrands(page: 1, perPage: 100) ?? [];
      if (!mounted) return;
      final roots = brands
          .where((brand) => (brand.parentIds == null || brand.parentIds!.isEmpty))
          .toList();
      setState(() {
        _rootBrands = roots.isNotEmpty ? roots : brands;
      });
    } catch (e) {
      // يمكن عرض تنبيه في المستقبل إذا لزم الأمر
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBrands = false;
        });
      }
    }
  }

  String? _resolveBrandLabel(String? id) {
    if (id == null) {
      return null;
    }
    for (final brand in _rootBrands) {
      if ('${brand.id}' == id) {
        return brand.name?.trim().isNotEmpty == true ? brand.name : null;
      }
    }
    return null;
  }

  void _snackBar(String text) {
    if (mounted) {
      final snackBar = SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: S.of(context).close,
          onPressed: () {
            // Some code to undo the change.
          },
        ),
      );

      _scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
    }
  }

  Future<void> _onRegisterSuccess() async {
    final user = Provider.of<UserModel>(context, listen: false).user;

    if ((user?.isVender != true) &&
        _selectedRole == 'vendor' &&
        (!kVendorConfig.enableAutoApplicationApproval)) {
      // show dialog under approval
      await context.showFluxDialogText(
        title: S.of(context).accountApprovalTitle,
        body: S.of(context).accountIsPendingApproval,
        primaryAction: S.of(context).ok,
      );
    } else {
      // register success
      await FlashHelper.message(
        context,
        message: S.of(context).registerSuccess,
        duration: const Duration(seconds: 1),
      );
    }
  }

  Future<void> _submitRegister(
      {String? firstName,
      String? lastName,
      String? emailAddress,
      String? password,
      String? username,
      String? phoneNumber}) async {
    final invalidFirstName = firstName?.trim().isEmpty ?? true;
    final invalidLastName = lastName?.trim().isEmpty ?? true;
    final invalidUsername =
        (requireUsernameWhenRegister && (username?.trim().isEmpty ?? true));
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
      _snackBar(S.of(context).pleaseInputFillAllFields);
      return;
    }
    if (isChecked == false) {
      _snackBar(S.of(context).pleaseAgreeTerms);
      return;
    }

    if (!emailAddress.validateEmail()) {
      _snackBar(S.of(context).errorEmailFormat);
      return;
    }

    if (password == null || password.length < 8) {
      _snackBar(S.of(context).errorPasswordFormat);
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });
      final isVendor = _selectedRole == 'vendor';
      final isDelivery = _selectedRole == 'delivery';
      final isOwner = _selectedRole == 'owner';

      if (isVendor && (_selectedBrandId?.isEmpty ?? true)) {
        setState(() {
          isLoading = false;
        });
        _snackBar('يرجى اختيار العلامة التجارية الرئيسية للتاجر');
        return;
      }

      final brandLabel = _selectedBrandLabel ?? _resolveBrandLabel(_selectedBrandId);

      if (isVendor || isDelivery || isOwner) {
        await Services().api.createUser(
          firstName: firstName,
          lastName: lastName,
          username: username ?? emailAddress,
          email: emailAddress,
          password: password,
          phoneNumber: phoneNumber,
          isVendor: isVendor,
          isDelivery: isDelivery,
          isOwner: isOwner,
          vendorBrandId: isVendor ? _selectedBrandId : null,
          vendorBrandLabel: isVendor ? brandLabel : null,
        );
      } else {
        await _services.signUp(
          username: username ?? emailAddress,
          email: emailAddress,
          firstName: firstName,
          lastName: lastName,
          password: password,
          phoneNumber: phoneNumber,
          selectedRole: _selectedRole,
        );
      }
      await _onRegisterSuccess();

      setState(() {
        isLoading = false;
      });
      NavigateTools.goBackLogin(context);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _snackBar(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: true);
    final themeConfig = appModel.themeConfig;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0.0,
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => Tools.hideKeyboard(context),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: AutofillGroup(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 10.0),
                      Center(
                        child: FluxImage(
                          imageUrl: themeConfig.logo,
                          width: MediaQuery.of(context).size.width / 2,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(
                        height: 30.0,
                      ),
                      CustomTextField(
                        key: const Key('registerFirstNameField'),
                        autofillHints: const [AutofillHints.givenName],
                        onChanged: (value) => firstName = value,
                        textCapitalization: TextCapitalization.words,
                        nextNode: lastNameNode,
                        showCancelIcon: true,
                        decoration: InputDecoration(
                          labelText: S.of(context).firstName,
                          hintText: S.of(context).enterYourFirstName,
                        ),
                      ),
                      if (_selectedRole == 'vendor') ...[
                        const SizedBox(height: 20.0),
                        _buildBrandSelector(),
                      ],
                      const SizedBox(height: 20.0),
                      CustomTextField(
                        key: const Key('registerLastNameField'),
                        autofillHints: const [AutofillHints.familyName],
                        focusNode: lastNameNode,
                        nextNode: showPhoneNumberWhenRegister
                            ? phoneNumberNode
                            : requireUsernameWhenRegister
                                ? usernameNode
                                : emailNode,
                        showCancelIcon: true,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) => lastName = value,
                        decoration: InputDecoration(
                          labelText: S.of(context).lastName,
                          hintText: S.of(context).enterYourLastName,
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      if (showPhoneNumberWhenRegister) ...[
                        CustomTextField(
                          key: const Key('registerPhoneField'),
                          autofillHints: const [AutofillHints.telephoneNumber],
                          focusNode: phoneNumberNode,
                          nextNode: requireUsernameWhenRegister
                              ? usernameNode
                              : emailNode,
                          showCancelIcon: true,
                          onChanged: (value) => phoneNumber = value,
                          decoration: InputDecoration(
                            labelText: S.of(context).phone,
                            hintText: S.of(context).enterYourPhoneNumber,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                      ],
                      if (requireUsernameWhenRegister) ...[
                        CustomTextField(
                          key: const Key('registerUsernameField'),
                          autofillHints: const [AutofillHints.familyName],
                          focusNode: usernameNode,
                          nextNode: emailNode,
                          showCancelIcon: true,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) => username = value,
                          decoration: InputDecoration(
                              labelText: S.of(context).username,
                              hintText: S.of(context).enterYourUsername),
                        ),
                        const SizedBox(height: 20.0),
                      ],
                      CustomTextField(
                        key: const Key('registerEmailField'),
                        focusNode: emailNode,
                        autofillHints: const [AutofillHints.email],
                        nextNode: passwordNode,
                        controller: _emailController,
                        onChanged: (value) => emailAddress = value,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                            labelText: S.of(context).email,
                            hintText: S.of(context).enterYourEmail),
                      ),
                      const SizedBox(height: 20.0),
                      CustomTextField(
                        key: const Key('registerPasswordField'),
                        focusNode: passwordNode,
                        autofillHints: const [AutofillHints.password],
                        showEyeIcon: true,
                        obscureText: true,
                        onChanged: (value) => password = value,
                        decoration: InputDecoration(
                          labelText: S.of(context).password,
                          hintText: S.of(context).enterYourPassword,
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      SelectRole(
                        roles: _roles ?? [],
                        value: _selectedRole,
                        onChanged: (val) {
                          setState(() {
                            _selectedRole = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20.0),
                      Row(
                        children: <Widget>[
                          Checkbox(
                            key: const Key('registerConfirmCheckbox'),
                            value: isChecked,
                            activeColor: Theme.of(context).primaryColor,
                            checkColor: Colors.white,
                            onChanged: (value) {
                              isChecked = !isChecked;
                              setState(() {});
                            },
                          ),
                          InkWell(
                            onTap: () {
                              isChecked = !isChecked;
                              setState(() {});
                            },
                            child: Text(
                              S.of(context).iwantToCreateAccount,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          isChecked = !isChecked;
                          setState(() {});
                        },
                        child: Row(
                          children: <Widget>[
                            Checkbox(
                              value: isChecked,
                              activeColor: Theme.of(context).primaryColor,
                              checkColor: Colors.white,
                              onChanged: (value) {
                                isChecked = !isChecked;
                                setState(() {});
                              },
                            ),
                            Expanded(
                              child: RichText(
                                maxLines: 2,
                                text: TextSpan(
                                  text: S.of(context).iAgree,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  children: <TextSpan>[
                                    const TextSpan(text: ' '),
                                    TextSpan(
                                      text: S.of(context).agreeWithPrivacy,
                                      style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          decoration: TextDecoration.underline),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => FluxNavigate.push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const PrivacyTermScreen(
                                                  showAgreeButton: false,
                                                ),
                                              ),
                                              forceRootNavigator: true,
                                              context: context,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Material(
                          color: Theme.of(context).primaryColor,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5.0)),
                          elevation: 0,
                          child: MaterialButton(
                            key: const Key('registerSubmitButton'),
                            onPressed: isLoading == true
                                ? null
                                : () async {
                                    await _submitRegister(
                                      firstName: firstName,
                                      lastName: lastName,
                                      emailAddress: emailAddress,
                                      password: password,
                                      username: username,
                                      phoneNumber: phoneNumber,
                                    );
                                  },
                            minWidth: 200.0,
                            elevation: 0.0,
                            height: 42.0,
                            child: Text(
                              isLoading == true
                                  ? S.of(context).loading
                                  : S.of(context).createAnAccount,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandSelector() {
    if (_isLoadingBrands) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rootBrands.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text('لا توجد علامات تجارية متاحة للتسجيل حالياً'),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedBrandId,
      decoration: const InputDecoration(
        labelText: 'العلامة التجارية الرئيسية',
        border: OutlineInputBorder(),
      ),
      items: _rootBrands
          .map(
            (brand) => DropdownMenuItem<String>(
              value: brand.id?.toString(),
              child: Text(brand.name ?? ''),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedBrandId = value;
          _selectedBrandLabel = _resolveBrandLabel(value);
        });
      },
    );
  }
}

class SelectRole extends StatelessWidget {
  final String? value;
  final Function? onChanged;
  final List<WholesaleRole> roles;

  const SelectRole({this.value, this.onChanged, required this.roles});

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const SizedBox();

    return RadioGroup<String>(
      groupValue: value,
      onChanged: (val) {
        onChanged?.call(val);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context).selectRole,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...roles.where((role) => role.key?.isNotEmpty ?? false).map(
                (role) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Radio<String>(value: role.key ?? ''),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(role.name ?? '',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 5),
                            Text(role.desc ?? '')
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
