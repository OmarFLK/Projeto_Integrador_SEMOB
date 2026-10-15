import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_components.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});
  @override
  ConsumerState<UsersPage> createState() => _UsersState();
}

class _UsersState extends ConsumerState<UsersPage> {
  String search = '';
  String? level;
  @override
  Widget build(BuildContext context) {
    final users = ref.watch(remoteProvider('users'));
    return PageBody(
      children: [
        PageHeader(
          title: 'Usuários e Acessos',
          subtitle: 'Contas e permissões persistidas',
          action: ElevatedButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.person_add),
            label: const Text('Novo usuário'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar nome, e-mail ou matrícula',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v.toLowerCase()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: level,
          decoration: const InputDecoration(labelText: 'Perfil'),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('Todos')),
            for (final role in AccessLevel.values)
              DropdownMenuItem(value: role.name, child: Text(role.label)),
          ],
          onChanged: (v) => setState(() => level = v),
        ),
        const SizedBox(height: 16),
        users.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => Column(
            children: [
              Text(apiError(e)),
              TextButton(
                onPressed: () => ref.invalidate(remoteProvider('users')),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
          data: (value) {
            final items = (value as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .where(
                  (u) =>
                      (level == null || u['accessLevel'] == level) &&
                      ['name', 'email', 'identifier'].any(
                        (k) => (u[k] ?? '').toString().toLowerCase().contains(
                          search,
                        ),
                      ),
                )
                .toList();
            return Column(
              children: [
                if (items.isEmpty) const Text('Nenhum usuário encontrado.'),
                for (final u in items)
                  Card(
                    child: ListTile(
                      title: Text(u['name'] as String),
                      subtitle: Text(
                        '${u['email']} • ${u['accessLevel']} • ${u['active'] == true ? 'Ativo' : 'Inativo'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Editar usuário',
                        onPressed: () => _edit(u),
                        icon: const Icon(Icons.edit),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _edit([Map<String, dynamic>? user]) async {
    final name = TextEditingController(text: user?['name'] as String?);
    final email = TextEditingController(text: user?['email'] as String?);
    final identifier = TextEditingController(
      text: user?['identifier'] as String?,
    );
    final job = TextEditingController(text: user?['jobTitle'] as String?);
    final department = TextEditingController(
      text: user?['department'] as String?,
    );
    final password = TextEditingController();
    var role = user?['accessLevel'] as String? ?? 'operator';
    var active = user?['active'] == true || user == null;
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(user == null ? 'Novo usuário' : 'Editar usuário'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  if (user == null) ...[
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                    TextField(
                      controller: identifier,
                      decoration: const InputDecoration(
                        labelText: 'Matrícula (opcional)',
                      ),
                    ),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha inicial (mínimo 12 caracteres)',
                      ),
                    ),
                  ],
                  TextField(
                    controller: job,
                    decoration: const InputDecoration(labelText: 'Cargo'),
                  ),
                  TextField(
                    controller: department,
                    decoration: const InputDecoration(labelText: 'Setor'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: AccessLevel.values
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.name,
                            child: Text(r.label),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) => setDialog(() => role = v!),
                  ),
                  if (user != null)
                    SwitchListTile(
                      title: const Text('Conta ativa'),
                      value: active,
                      onChanged: saving
                          ? null
                          : (v) => setDialog(() => active = v),
                    ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialog(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final body = {
                          'name': name.text,
                          'email': email.text,
                          'identifier': identifier.text,
                          'password': password.text,
                          'jobTitle': job.text,
                          'department': department.text,
                          'accessLevel': role,
                          'active': active,
                        };
                        final dio = ref.read(apiClientProvider).dio;
                        if (user == null) {
                          await dio.post<void>('users', data: body);
                        } else {
                          await dio.patch<void>(
                            'users/${user['id']}',
                            data: body,
                          );
                        }
                        ref.invalidate(remoteProvider('users'));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialog(() {
                            saving = false;
                            error = apiError(e);
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    // Dialog closing animation may still reference these controllers.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in [name, email, identifier, job, department, password]) {
      c.dispose();
    }
  }
}
