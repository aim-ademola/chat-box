import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/provider/status_provider.dart';
import 'package:frontend/widget/status_type_chip_widget.dart';
import 'package:image_picker/image_picker.dart';

class UploadStatusScreen extends ConsumerStatefulWidget {
  const UploadStatusScreen({super.key});

  @override
  ConsumerState<UploadStatusScreen> createState() => _UploadStatusScreenState();
}

class _UploadStatusScreenState extends ConsumerState<UploadStatusScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _selectedType = 'text';
  File? _selectedFile;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _selectType(String type) async {
    setState(() {
      _selectedType = type;
      if (type == 'text') {
        _selectedFile = null;
      }
    });

    if (type == 'image') {
      await _pickImage();
    } else if (type == 'video') {
      await _pickVideo();
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedFile = File(picked.path);
      _selectedType = 'image';
    });
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedFile = File(picked.path);
      _selectedType = 'video';
    });
  }

  Future<void> _submitStatus() async {
    final content = _contentController.text.trim();
    if (_selectedType == 'text' && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something for your status first.')),
      );
      return;
    }

    if (_selectedType != 'text' && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Choose a $_selectedType file first.')),
      );
      return;
    }

    try {
      await ref
          .read(statusProvider.notifier)
          .uploadStatus(
            content: content,
            type: _selectedType,
            file: _selectedFile,
          );

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
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.heightOf(context) * 0.82,
                ),
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
                              onTap: () => _selectType('text'),
                            ),
                            StatusTypeChipWidget(
                              label: 'Image',
                              icon: Icons.image_outlined,
                              isSelected: _selectedType == 'image',
                              onTap: () => _selectType('image'),
                            ),
                            StatusTypeChipWidget(
                              label: 'Video',
                              icon: Icons.videocam_outlined,
                              isSelected: _selectedType == 'video',
                              onTap: () => _selectType('video'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        if (_selectedType != 'text') ...[
                          _MediaPickerCard(
                            selectedType: _selectedType,
                            selectedFile: _selectedFile,
                            onPick: _selectedType == 'image'
                                ? _pickImage
                                : _pickVideo,
                          ),
                          const SizedBox(height: 18),
                        ],
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
                                      : _selectedFile == null
                                      ? 'Pick a $_selectedType from your gallery before posting.'
                                      : 'Your $_selectedType is ready to upload.',
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
                        const SizedBox(height: 24),
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

class _MediaPickerCard extends StatelessWidget {
  const _MediaPickerCard({
    required this.selectedType,
    required this.selectedFile,
    required this.onPick,
  });

  final String selectedType;
  final File? selectedFile;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final isImage = selectedType == 'image';

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        height: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        child: selectedFile != null && isImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(selectedFile!, fit: BoxFit.cover),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _ChangeMediaButton(label: 'Change image'),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isImage
                        ? Icons.add_photo_alternate_outlined
                        : Icons.video_library_outlined,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedFile == null
                        ? 'Choose $selectedType'
                        : 'Video selected',
                    style: AppStyle.circularTextStyle(
                      size: 17,
                      weight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      selectedFile == null
                          ? 'Open your gallery and pick a file.'
                          : selectedFile!.path
                                .split(Platform.pathSeparator)
                                .last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppStyle.circularTextStyle(
                        size: 13,
                        weight: FontWeight.w500,
                        color: palette.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChangeMediaButton extends StatelessWidget {
  const _ChangeMediaButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: AppStyle.circularTextStyle(
            size: 13,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
