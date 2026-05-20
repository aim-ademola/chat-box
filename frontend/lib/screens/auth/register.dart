import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/auth/widget/auth_from_field.dart';
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
                      TextSpan(text: 'Sign up with '),
                      TextSpan(
                        text: 'Email',
                        style: AppStyle.carosBoldStyle(context).copyWith(
                          decorationColor: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationThickness: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  'Get chatting with friends and family today by \nsigning up for our chat app!',
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 15),

                AuthFormField(label: 'Your Name', controller: nameController),
                AuthFormField(label: 'Your Email', controller: emailController),
                AuthFormField(
                  label: 'Password',
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  showVisibilityButton: true,
                  onVisibilityToggle: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                AuthFormField(
                  label: 'Confirm Password',
                  controller: cPasswordController,
                  obscureText: _obscureConfirmPassword,
                  showVisibilityButton: true,
                  onVisibilityToggle: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),

                SizedBox(height: 100),
                auth.isLoading
                    ? Center(child: CircularProgressIndicator())
                    : AppButton(
                        label: 'Create an account',
                        onTap: _handleRegister,
                        backgroundColor: AppColors.primary,
                      ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
