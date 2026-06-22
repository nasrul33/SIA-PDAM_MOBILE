class AppUser {
  AppUser({required this.id, required this.name, required this.role});

  final int id;
  final String name;
  final String role;

  bool get isReader => role == 'petugas_meter' || role == 'super_admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}
