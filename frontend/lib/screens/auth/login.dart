import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/auth/widget/auth_from_field.dart';
import 'package:frontend/widget/app_button.dart';
import 'package:frontend/widget/or_divide_widget.dart';
import 'package:frontend/widget/social_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController emailEditingController = TextEditingController();
  final TextEditingController passwordEditingController =
      TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailEditingController.dispose();
    passwordEditingController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    await ref
        .read(authProvider.notifier)
        .login(
          email: emailEditingController.text.trim(),
          password: passwordEditingController.text,
        );

    if (!mounted) {
      return;
    }

    final authState = ref.read(authProvider);
    authState.whenOrNull(
      error: (error, stackTrace) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceAll('Execption', ''))),
        );
      },
      data: (user) {
        if (user != null) {
          Navigator.pushNamedAndRemoveUntil(context, 'home', (route) => false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(18.0),
            child: Column(
              spacing: 12,
              mainAxisAlignment: .center,
              crossAxisAlignment: .center,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppStyle.carosBoldStyle(context),
                    children: [
                      TextSpan(
                        text: 'Log in',
                        style: AppStyle.carosBoldStyle(context).copyWith(
                          decorationColor: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationThickness: 10,
                        ),
                      ),
                      TextSpan(text: ' to Chatbox'),
                    ],
                  ),
                ),

                Text(
                  'Welcome back! Sign in using your social \naccount or email to continue us',
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: .center,
                  spacing: 10,
                  children: [
                    SocialBotton(
                      iconPath: AppImages.facebook,
                      boderColor: AppColors.black,
                    ),
                    SocialBotton(
                      iconPath: AppImages.google,
                      boderColor: AppColors.black,
                    ),
                    SocialBotton(
                      iconPath: AppImages.apple,
                      boderColor: AppColors.black,
                      color: AppColors.black,
                    ),
                  ],
                ),
                OrDivideWidget(
                  dividerColor: AppColors.black,
                  textColor: AppColors.black,
                ),

                AuthFormField(
                  label: 'Email',
                  controller: emailEditingController,
                ),
                AuthFormField(
                  label: 'Password',
                  controller: passwordEditingController,
                  obscureText: _obscurePassword,
                  showVisibilityButton: true,
                  onVisibilityToggle: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),

                SizedBox(height: 100),
                auth.isLoading
                    ? Center(child: CircularProgressIndicator())
                    : AppButton(
                        label: 'Log In',
                        onTap: _handleLogin,
                        backgroundColor: AppColors.primary,
                      ),
                SizedBox(height: 30),
                Text(
                  'Forget Password?',
                  style: AppStyle.carosBoldStyle(
                    context,
                  ).copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
