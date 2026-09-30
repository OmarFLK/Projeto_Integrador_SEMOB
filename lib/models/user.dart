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
  });

  final String name;
  final String identifier;
  final String role;
  final String department;
  final AccessLevel accessLevel;
  final String status;
  final String lastAccess;
  final String? avatarUrl;
}
