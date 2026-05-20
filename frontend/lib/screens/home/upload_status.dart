import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/provider/status_provider.dart';
import 'package:frontend/widget/status_type_chip_widget.dart';

class UploadStatusScreen extends ConsumerStatefulWidget {
  const UploadStatusScreen({super.key});

  @override
  ConsumerState<UploadStatusScreen> createState() => _UploadStatusScreenState();
}

class _UploadStatusScreenState extends ConsumerState<UploadStatusScreen> {
  final TextEditingController _contentController = TextEditingController();
  String _selectedType = 'text';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitStatus() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something for your status first.')),
      );
      return;
    }

    if (_selectedType != 'text') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text status is ready now. Media picking is next.'),
        ),
      );
      return;
    }

    try {
      await ref
          .read(statusProvider.notifier)
          .uploadStatus(content: content, type: _selectedType);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Status uploaded.')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final statusState = ref.watch(statusProvider);

    return Scaffold(
      backgroundColor: palette.headerBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(52, 52),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Upload Status',
                        textAlign: TextAlign.center,
                        style: AppStyle.circularTextStyle(
                          size: 16,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 52),
                  ],
                ),
              ),
              SizedBox(
                height: MediaQuery.heightOf(context) * 0.9,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  decoration: BoxDecoration(
                    color: palette.messageSheet,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(42),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 74,
                            height: 6,
                            decoration: BoxDecoration(
                              color: palette.handle,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Share what is happening',
                          style: AppStyle.circularTextStyle(
                            size: 24,
                            weight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'This screen follows your home layout and posts directly to the status backend connection we added.',
                          style: AppStyle.circularTextStyle(
                            size: 15,
                            weight: FontWeight.w500,
                            color: palette.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'Status type',
                          style: AppStyle.circularTextStyle(
                            size: 16,
                            weight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            StatusTypeChipWidget(
                              label: 'Text',
                              icon: Icons.edit_rounded,
                              isSelected: _selectedType == 'text',
                              onTap: () =>
                                  setState(() => _selectedType = 'text'),
                            ),
                            StatusTypeChipWidget(
                              label: 'Image',
                              icon: Icons.image_outlined,
                              isSelected: _selectedType == 'image',
                              onTap: () =>
                                  setState(() => _selectedType = 'image'),
                            ),
                            StatusTypeChipWidget(
                              label: 'Video',
                              icon: Icons.videocam_outlined,
                              isSelected: _selectedType == 'video',
                              onTap: () =>
                                  setState(() => _selectedType = 'video'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colorScheme.outline.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Caption',
                                style: AppStyle.circularTextStyle(
                                  size: 16,
                                  weight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _contentController,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  hintText: 'Write your status here...',
                                  hintStyle: AppStyle.circularTextStyle(
                                    color: palette.secondaryText,
                                  ),
                                  border: InputBorder.none,
                                ),
                                style: AppStyle.circularTextStyle(
                                  size: 16,
                                  weight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedType == 'text'
                                      ? 'Text status is ready to post now.'
                                      : 'Image and video backend support is connected, but file picking UI still needs one more step.',
                                  style: AppStyle.circularTextStyle(
                                    size: 14,
                                    weight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: statusState.isLoading
                                ? null
                                : _submitStatus,
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'circular',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: statusState.isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text('Post Status'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
