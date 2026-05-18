import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/model/call_item_model.dart';
import 'package:frontend/widget/call_tile_widget.dart';
import 'package:frontend/widget/circle_icon_button_widget.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final List<CallItemModel> calls = [
    CallItemModel(
      name: "Team Align",
      callTime: "Today, 09:30 AM",
      initials: "TA",
      avatarColor: Colors.blue,
      isIncoming: true,
      isVideoCall: true,
      imagePath: '',
    ),
    CallItemModel(
      name: "Jhon Abraham",
      callTime: "Today, 07:30 AM",
      initials: "JA",
      avatarColor: Colors.orange,
      isIncoming: false,
      imagePath: '',
    ),
    CallItemModel(
      name: "Sabila Sayma",
      callTime: "Yesterday, 07:35 PM",
      initials: "SS",
      avatarColor: Colors.pink,
      isMissed: true,
      isIncoming: true,
      imagePath: '',
    ),
    CallItemModel(
      name: "Alex Linderson",
      callTime: "Monday, 09:30 AM",
      initials: "AL",
      avatarColor: Colors.grey,
      isIncoming: true,
      imagePath: '',
    ),
    CallItemModel(
      name: "John Borino",
      callTime: "Monday, 09:30 AM",
      initials: "JB",
      avatarColor: Colors.brown,
      isIncoming: false,
      imagePath: '',
    ),
    CallItemModel(
      name: "Jhon Abraham",
      callTime: "03/07/22, 7:30AM",
      initials: "JA",
      avatarColor: Colors.orange,
      isMissed: true,
      isIncoming: false,
      imagePath: '',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  CircleIconButtonWidget(
                    icon: AppImages.search,
                    borderColor: AppColors.white,
                  ),

                  Expanded(
                    child: Center(
                      child: Text(
                        "Calls",
                        style: AppStyle.circularSmallStyle.copyWith(
                          fontSize: 20,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),

                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.add_call,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Recent",
                          style: AppStyle.circularMediumStyle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: calls.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey.shade200, indent: 70),
                        itemBuilder: (context, index) {
                          final call = calls[index];

                          return CallTileWidget(
                            contact: call,
                            callTime: call.callTime,
                            isMissed: call.isMissed,
                            isVideoCall: call.isVideoCall,
                          );
                        },
                      ),
                    ),
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
