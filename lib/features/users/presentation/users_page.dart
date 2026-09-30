import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../mocks/mock_users.dart';
import '../../../models/user.dart';
import '../../../shared/widgets/page_components.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _search = '';
  AccessLevel? _level;

  @override
  Widget build(BuildContext context) {
    final users = mockUsers.where((user) {
      final query = _search.toLowerCase();
      return (_level == null || user.accessLevel == _level) &&
          (query.isEmpty ||
              user.name.toLowerCase().contains(query) ||
              user.identifier.toLowerCase().contains(query));
    }).toList();
    return PageBody(
      children: [
        PageHeader(
          title: 'Usuários e Acessos',
          subtitle: 'Gestão visual de funcionários e perfis internos',
          action: ElevatedButton.icon(
            onPressed: _newUser,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Novo usuário'),
          ),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Cadastros demonstrativos do frontend. Nenhum usuário real é alterado nesta versão.',
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Acessos internos',
          subtitle: '${users.length} usuários encontrados',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: AppBreakpoints.isMobile(context)
                        ? double.infinity
                        : 310,
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: const InputDecoration(
                        hintText: 'Buscar nome, matrícula ou e-mail',
                        prefixIcon: Icon(Icons.search, size: 19),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: AppBreakpoints.isMobile(context)
                        ? double.infinity
                        : 190,
                    child: DropdownButtonFormField<AccessLevel?>(
                      initialValue: _level,
                      decoration: const InputDecoration(
                        labelText: 'Perfil',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<AccessLevel?>(
                          value: null,
                          child: Text('Todos os perfis'),
                        ),
                        ...AccessLevel.values.map(
                          (item) => DropdownMenuItem<AccessLevel?>(
                            value: item,
                            child: Text(item.label),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _level = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (AppBreakpoints.isMobile(context))
                ...users.map((user) => _UserCard(user: user))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nome')),
                      DataColumn(label: Text('Matrícula / e-mail')),
                      DataColumn(label: Text('Cargo')),
                      DataColumn(label: Text('Setor')),
                      DataColumn(label: Text('Perfil')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Último acesso')),
                    ],
                    rows: users
                        .map(
                          (user) => DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: AppColors.greenLight,
                                      child: Text(
                                        _initials(user.name),
                                        style: const TextStyle(
                                          color: AppColors.greenDark,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(user.identifier)),
                              DataCell(Text(user.role)),
                              DataCell(Text(user.department)),
                              DataCell(Text(user.accessLevel.label)),
                              DataCell(
                                StatusBadge(
                                  label: user.status,
                                  kind: user.status == 'Ativo'
                                      ? StatusKind.good
                                      : StatusKind.neutral,
                                ),
                              ),
                              DataCell(Text(user.lastAccess)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _newUser() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo usuário'),
        content: const SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Nome completo'),
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(labelText: 'Matrícula ou e-mail'),
              ),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'Cargo')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Cadastro visual concluído. A persistência será conectada à API.',
                  ),
                ),
              );
            },
            child: const Text('Criar usuário'),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final AppUser user;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: AppColors.greenLight,
          child: Text(
            _initials(user.name),
            style: const TextStyle(
              color: AppColors.greenDark,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${user.role} • ${user.department}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
              const SizedBox(height: 3),
              Text(
                user.identifier,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        StatusBadge(
          label: user.status,
          kind: user.status == 'Ativo' ? StatusKind.good : StatusKind.neutral,
        ),
      ],
    ),
  );
}

String _initials(String name) =>
    name.split(' ').take(2).map((part) => part[0]).join();
