import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/auth/widget/auth_from_field.dart';
import 'package:frontend/screens/auth/widget/auth_shell.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return AuthShell(
      title: 'Log in\nto ',
      highlight: 'Chatbox',
      subtitle:
          'Welcome back. Continue with your account and pick up every conversation where you left it.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'New to Chatbox?',
            style: AppStyle.circularTextStyle(
              size: 15,
              weight: FontWeight.w500,
              color: palette.secondaryText,
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, 'register'),
            child: const Text('Create account'),
          ),
        ],
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 14,
          children: [
            SocialBotton(
              iconPath: AppImages.facebook,
              boderColor: colorScheme.outline,
            ),
            SocialBotton(
              iconPath: AppImages.google,
              boderColor: colorScheme.outline,
            ),
            SocialBotton(
              iconPath: AppImages.apple,
              boderColor: colorScheme.outline,
              color: AppColors.black,
            ),
          ],
        ),
        const SizedBox(height: 22),
        OrDivideWidget(
          dividerColor: colorScheme.outline.withValues(alpha: 0.18),
          textColor: palette.secondaryText,
        ),
        const SizedBox(height: 22),
        AuthFormField(
          label: 'Email address',
          controller: emailEditingController,
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),
        AuthFormField(
          label: 'Password',
          controller: passwordEditingController,
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          showVisibilityButton: true,
          textInputAction: TextInputAction.done,
          onVisibilityToggle: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: Text(
              'Forgot password?',
              style: AppStyle.circularTextStyle(
                size: 14,
                weight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        auth.isLoading
            ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            : AppButton(
                label: 'Log In',
                onTap: _handleLogin,
                backgroundColor: colorScheme.primary,
              ),
      ],
    );
  }
}
