class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // "admin" | "scorer" | "public"
  final String? createdAt;
  final String? updatedAt;
  final String? createdBy;

  const AppUser({
    required this.uid,
    required this.email,
    this.name = '',
    this.role = 'public',
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  static const String platformAdminEmail = 'ahsanhayat092@gmail.com';

  bool get isPlatformAdmin =>
      email.toLowerCase().trim() == platformAdminEmail.toLowerCase();
  bool get isAdmin => isPlatformAdmin || role.toLowerCase() == 'admin';
  bool get isScorer => role.toLowerCase() == 'scorer';
  bool get canScore => isAdmin || isScorer;

  factory AppUser.fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) {
      return AppUser(uid: uid, email: '', role: 'public');
    }
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: (data['role'] as String?)?.toLowerCase() ?? 'public',
      createdAt: data['createdAt'] as String?,
      updatedAt: data['updatedAt'] as String?,
      createdBy: data['createdBy'] as String?,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      AppUser.fromMap(json['uid'] as String? ?? json['id'] as String? ?? '', json);

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      if (createdAt != null) 'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? createdAt,
    String? updatedAt,
    String? createdBy,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
