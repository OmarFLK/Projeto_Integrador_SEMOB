enum AccessLevel { manager, analyst, operator, administrator }

extension AccessLevelLabel on AccessLevel {
  String get label => switch (this) {
    AccessLevel.manager => 'Gestor',
    AccessLevel.analyst => 'Analista',
    AccessLevel.operator => 'Operador',
    AccessLevel.administrator => 'Administrador',
  };
}

class AppUser {
  const AppUser({
    required this.name,
    required this.identifier,
    required this.role,
    required this.department,
    required this.accessLevel,
    required this.status,
    required this.lastAccess,
    this.avatarUrl,
    this.id = '',
    this.email = '',
    this.permissions = const [],
  });

  final String name;
  final String identifier;
  final String role;
  final String department;
  final AccessLevel accessLevel;
  final String status;
  final String lastAccess;
  final String? avatarUrl;
  final String id;
  final String email;
  final List<String> permissions;
  bool can(String permission) => permissions.contains(permission);
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    identifier: json['identifier'] as String? ?? json['email'] as String,
    role: json['jobTitle'] as String? ?? '',
    department: json['department'] as String? ?? '',
    accessLevel: AccessLevel.values.firstWhere(
      (r) => r.name == json['accessLevel'],
    ),
    status: json['active'] == true ? 'Ativo' : 'Inativo',
    lastAccess: json['lastAccess'] as String? ?? 'Primeiro acesso',
    permissions: (json['permissions'] as List? ?? []).cast<String>(),
  );
}
