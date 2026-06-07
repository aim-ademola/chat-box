import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/auth/widget/auth_from_field.dart';
import 'package:frontend/screens/auth/widget/auth_shell.dart';
import 'package:frontend/widget/app_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController cPasswordController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    cPasswordController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (passwordController.text != cPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    await ref
        .read(authProvider.notifier)
        .register(
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
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
      data: (data) {
        if (data != null) {
          Navigator.pushReplacementNamed(context, "login");
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
      title: 'Create your\n',
      highlight: 'account',
      subtitle:
          'Start chatting with friends, groups, and family in one clean conversation space.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: AppStyle.circularTextStyle(
              size: 15,
              weight: FontWeight.w500,
              color: palette.secondaryText,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, 'login'),
            child: const Text('Log in'),
          ),
        ],
      ),
      children: [
        AuthFormField(
          label: 'Full name',
          controller: nameController,
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),
        AuthFormField(
          label: 'Email address',
          controller: emailController,
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),
        AuthFormField(
          label: 'Password',
          controller: passwordController,
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          showVisibilityButton: true,
          textInputAction: TextInputAction.next,
          onVisibilityToggle: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        const SizedBox(height: 18),
        AuthFormField(
          label: 'Confirm password',
          controller: cPasswordController,
          icon: Icons.verified_user_outlined,
          obscureText: _obscureConfirmPassword,
          showVisibilityButton: true,
          textInputAction: TextInputAction.done,
          onVisibilityToggle: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        const SizedBox(height: 28),
        auth.isLoading
            ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            : AppButton(
                label: 'Create account',
                onTap: _handleRegister,
                backgroundColor: colorScheme.primary,
              ),
      ],
    );
  }
}
