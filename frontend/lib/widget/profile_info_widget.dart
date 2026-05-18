import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/constant/app_colors.dart';

class ProfileInfoTileWidget extends StatelessWidget {
  final String title;
  final String value;

  final VoidCallback? onTap;

  const ProfileInfoTileWidget({
    super.key,
    required this.title,
    required this.value,

    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Container(
              height: 20,
              width: 20,
              decoration: BoxDecoration(),
              // child: Center(
              //   child: SvgPicture.asset( height: 22, width: 22),
              // ),
            ),

            const SizedBox(width: 0),

            /// Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Title (small)
                  Text(
                    title,
                    style: AppStyle.circularMediumStyle.copyWith(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    value,
                    style: AppStyle.carosBoldStyle(
                      context,
                    ).copyWith(fontSize: 18, color: AppColors.black),
                  ),
                ],
              ),
            ),

            // /// Optional arrow (like your UI)
            // Icon(
            //   Icons.arrow_forward_ios,
            //   size: 16,
            //   color: Colors.grey,
            // ),
          ],
        ),
      ),
    );
  }
}
