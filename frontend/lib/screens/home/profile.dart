import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_colors.dart';

import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/widget/profile_avatar_widget.dart';
import 'package:frontend/widget/profile_info_widget.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Padding(padding: EdgeInsets.all(12)),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  ProfileAvatarWidget(
                    initials: 'NI',
                    backgroundColor: Color(0xFFFFC746),
                    radius: 45,
                    profilePicUrl: "",
                  ),

                  SizedBox(height: 10),

                  Text(
                    'Nazrul Islam',
                    style: AppStyle.carosLargeStyle.copyWith(
                      fontSize: 25,
                      color: AppColors.white,
                    ),
                  ),

                  SizedBox(height: 3),

                  Text(
                    "@nazrulislam",
                    style: AppStyle.circularSmallStyle.copyWith(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(children: []),

                  SizedBox(height: 20),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.68,
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(35),
                      ),
                    ),

                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 20),

                          ProfileInfoTileWidget(
                            title: "Display Name",
                            value: "Nazrul Islam",
                          ),

                          SizedBox(height: 15),

                          ProfileInfoTileWidget(
                            title: "Email Address",
                            value: "NazrulIslam@gmail.com",
                          ),

                          SizedBox(height: 15),

                          ProfileInfoTileWidget(
                            title: "Address",
                            value: "33 street west subidbazar,sylhet",
                          ),

                          SizedBox(height: 15),

                          ProfileInfoTileWidget(
                            title: "Phone Number",
                            value: "(320) 555-0104",
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
