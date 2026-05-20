import 'dart:convert';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String bio;
  final String profilePicUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.bio,
    required this.profilePicUrl,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? bio,
    String? profilePicUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'bio': bio,
      'profilePicUrl': profilePicUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'ChatBox User',
      email: map['email']?.toString() ?? '',
      bio: map['bio']?.toString() ?? 'Hey, I am using ChatBox',
      profilePicUrl: map['profilePicUrl']?.toString() ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));
}
