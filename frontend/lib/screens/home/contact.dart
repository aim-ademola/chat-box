import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/contact_item_model.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/model/user_model.dart';
import 'package:frontend/provider/contacts_provider.dart';
import 'package:frontend/screens/home/chat_detail.dart';
import 'package:frontend/screens/home/create_group_screen.dart';
import 'package:frontend/screens/home/user_profile_screen.dart';
import 'package:frontend/widget/circle_icon_button_widget.dart';
import 'package:frontend/widget/contact_tile_widget.dart';

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  static const _avatarPalette = [
    Color(0xFFF3A4B1),
    Color(0xFFFFC94D),
    Color(0xFFF8F4ED),
    Color(0xFFE0D9D3),
    Color(0xFFD7E0F4),
    Color(0xFFDCE7F8),
  ];

  Map<String, List<ContactItemModel>> _groupContacts(List<UserModel> users) {
    final contacts = <ContactItemModel>[];

    for (var i = 0; i < users.length; i++) {
      final user = users[i];
      final initials = user.name
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();

      contacts.add(
        ContactItemModel(
          name: user.name,
          tagline: user.bio,
          initials: initials.isEmpty ? 'U' : initials,
          avatarColor: _avatarPalette[i % _avatarPalette.length],
          profilePicUrl: user.profilePicUrl,
          userId: user.id,
        ),
      );
    }

    contacts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    final grouped = <String, List<ContactItemModel>>{};
    for (final contact in contacts) {
      final letter = contact.name[0].toUpperCase();
      grouped.putIfAbsent(letter, () => []).add(contact);
    }

    return grouped;
  }

  Future<void> _openChat(ContactItemModel contact) async {
    final message = MessageItemModel(
      name: contact.name,
      message: contact.tagline,
      time: 'Active now',
      initials: contact.initials,
      avatarColor: contact.avatarColor,
      statusColor: const Color(0xFF1EDB76),
      profilePicUrl: contact.profilePicUrl,
      userId: contact.userId,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailScreen(contact: message)),
    );
  }

  Future<void> _openUserProfile(UserModel user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
    );
  }

  Future<void> _openCreateGroup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final contactsState = ref.watch(contactsProvider);

    return DecoratedBox(
      decoration: BoxDecoration(color: palette.headerBackground),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(
                children: [
                  CircleIconButtonWidget(
                    icon: AppImages.search,
                    borderColor: palette.searchBorder,
                  ),
                  Expanded(
                    child: Text(
                      'Contacts',
                      textAlign: TextAlign.center,
                      style: AppStyle.circularTextStyle(
                        size: 16,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Create group',
                    child: InkWell(
                      onTap: _openCreateGroup,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.searchBorder,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.groups_2_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 34),
                decoration: BoxDecoration(
                  color: palette.messageSheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(42),
                  ),
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
                    Expanded(
                      child: contactsState.when(
                        data: (users) {
                          final groupedContacts = _groupContacts(users);
                          final usersById = {
                            for (final user in users) user.id: user,
                          };
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
                            children: [
                              Text(
                                'My Contact',
                                style: AppStyle.circularTextStyle(
                                  size: 24,
                                  weight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 26),
                              for (final entry in groupedContacts.entries) ...[
                                Text(
                                  entry.key,
                                  style: AppStyle.circularTextStyle(
                                    size: 22,
                                    weight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                for (
                                  var i = 0;
                                  i < entry.value.length;
                                  i++
                                ) ...[
                                  ContactTileWidget(
                                    contact: entry.value[i],
                                    onTap: () {
                                      final contact = entry.value[i];
                                      final user = usersById[contact.userId];
                                      if (user == null) {
                                        _openChat(contact);
                                        return;
                                      }

                                      _openUserProfile(user);
                                    },
                                  ),
                                  if (i != entry.value.length - 1)
                                    const SizedBox(height: 30),
                                ],
                                const SizedBox(height: 34),
                              ],
                            ],
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: AppStyle.circularTextStyle(
                                size: 15,
                                weight: FontWeight.w500,
                                color: palette.secondaryText,
                              ),
                            ),
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
