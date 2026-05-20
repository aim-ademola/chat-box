import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/widget/app_button.dart';
import 'package:frontend/widget/image_widget.dart';
import 'package:frontend/widget/or_divide_widget.dart';
import 'package:frontend/widget/social_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isShortScreen = screenSize.height < 700;
    final heroFontSize = isShortScreen ? 34.0 : 46.0;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ImageWidget(fit: BoxFit.cover, AppImages.onboardBg),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      screenSize.height -
                      MediaQuery.paddingOf(context).top -
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  spacing: isShortScreen ? 8 : 10,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isShortScreen ? 18 : 42),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [
                        ImageWidget(
                          AppImages.logo,
                          width: 25,
                          color: AppColors.white,
                        ),
                        Text(
                          'ChatBox',
                          style: AppStyle.circularMediumStyle.copyWith(
                            color: AppColors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isShortScreen ? 18 : 30),
                    Text(
                      'Connect friends',
                      style: AppStyle.carosLargeStyle.copyWith(
                        fontSize: heroFontSize,
                        height: 1.12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'easily & quickly',
                      style: AppStyle.carosLargeStyle.copyWith(
                        fontSize: heroFontSize,
                        height: 1.12,
                      ),
                    ),

                    Text(
                      'Our chat app is the perfect way to stay connected with friends and family.',
                      textAlign: TextAlign.start,
                      style: AppStyle.circularSmallStyle.copyWith(
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),

                    SizedBox(height: isShortScreen ? 8 : 18),
                    Row(
                      spacing: 12,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SocialBotton(iconPath: AppImages.facebook),
                        SocialBotton(iconPath: AppImages.google),
                        SocialBotton(iconPath: AppImages.apple),
                      ],
                    ),
                    SizedBox(height: isShortScreen ? 8 : 16),
                    OrDivideWidget(),
                    SizedBox(height: isShortScreen ? 4 : 8),
                    AppButton(
                      textColor: AppColors.black,
                      label: 'Sign up with mail',
                      backgroundColor: AppColors.white,
                      onTap: () {
                        Navigator.pushNamed(context, 'register');
                      },
                    ),
                    SizedBox(height: isShortScreen ? 6 : 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Existing account? ',
                          style: AppStyle.circularSmallStyle,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, 'login');
                          },
                          child: Text(
                            ' Log in',
                            style: AppStyle.circularSmallStyle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
