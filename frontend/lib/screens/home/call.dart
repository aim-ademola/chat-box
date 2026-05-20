import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/extention/build_context_ext.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/provider/call_provider.dart';
import 'package:frontend/widget/call_tile_widget.dart';
import 'package:frontend/widget/circle_icon_button_widget.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final calls = ref.watch(recentCallsProvider);

    return Scaffold(
      backgroundColor: palette.headerBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  CircleIconButtonWidget(
                    icon: AppImages.search,
                    borderColor: palette.searchBorder,
                  ),

                  Expanded(
                    child: Center(
                      child: Text(
                        "Calls",
                        style: AppStyle.circularSmallStyle.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.searchBorder,
                        width: 1.5,
                      ),
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
                decoration: BoxDecoration(
                  color: palette.messageSheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(38),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isDarkMode ? 0.18 : 0.08,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 14, bottom: 8),
                      width: 76,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.handle,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

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
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: calls.when(
                        data: (items) {
                          if (items.isEmpty) {
                            return Center(
                              child: Text(
                                'No recent calls',
                                style: AppStyle.circularMediumStyle.copyWith(
                                  color: palette.secondaryText,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(recentCallsProvider);
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  Divider(color: palette.handle, indent: 70),
                              itemBuilder: (context, index) {
                                final call = items[index];

                                return CallTileWidget(
                                  contact: call,
                                  callTime: call.callTime,
                                  isMissed: call.isMissed,
                                  isVideoCall: call.isVideoCall,
                                );
                              },
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Center(
                          child: TextButton(
                            onPressed: () {
                              ref.invalidate(recentCallsProvider);
                            },
                            child: const Text('Retry loading calls'),
                          ),
                        ),
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
