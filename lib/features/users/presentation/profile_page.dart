import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/account_layout.dart';
import '../../../shared/widgets/page_components.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfilePage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      job = TextEditingController(),
      department = TextEditingController(),
      confirmation = TextEditingController();
  bool saving = false, photoBusy = false;
  String? loadedId;
  @override
  void dispose() {
    for (final f in [name, email, job, department, confirmation]) {
      f.dispose();
    }
    super.dispose();
  }

  void load(AppUser user) {
    name.text = user.name;
    email.text = user.email;
    job.text = user.role;
    department.text = user.department;
    loadedId = user.id;
  }

  void notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final result = await ref
          .read(apiClientProvider)
          .dio
          .patch<Map<String, dynamic>>(
            'auth/profile',
            data: {
              'name': name.text.trim(),
              'email': email.text.trim(),
              'jobTitle': job.text.trim(),
              'department': department.text.trim(),
              if (confirmation.text.isNotEmpty)
                'currentPassword': confirmation.text,
            },
          );
      await ref.read(authProvider.notifier).applyUser(result.data!);
      if (!mounted) return;
      load(ref.read(authProvider).user!);
      confirmation.clear();
      notice('Seus dados foram atualizados.');
    } catch (e) {
      if (mounted) notice(apiError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> photo({bool remove = false}) async {
    if (photoBusy) return;
    try {
      XFile? file;
      if (!remove) {
        file = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Fotos PNG ou JPG',
              extensions: ['png', 'jpg', 'jpeg'],
              mimeTypes: ['image/png', 'image/jpeg'],
              uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
            ),
          ],
        );
        if (file == null || !mounted) return;
        if (await file.length() > 1536 * 1024) {
          if (mounted) notice('Escolha uma foto de até 1,5 MB.');
          return;
        }
      }
      if (!mounted) return;
      setState(() => photoBusy = true);
      final dio = ref.read(apiClientProvider).dio;
      final result = remove
          ? await dio.delete<Map<String, dynamic>>('auth/avatar')
          : await dio.put<Map<String, dynamic>>(
              'auth/avatar',
              data: {'content': base64Encode(await file!.readAsBytes())},
            );
      await ref.read(authProvider.notifier).applyUser(result.data!);
      if (mounted) {
        notice(remove ? 'Foto removida.' : 'Sua foto foi atualizada.');
      }
    } catch (e) {
      if (mounted) notice(apiError(e));
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    if (loadedId != user.id) load(user);
    String date(String? value) {
      final d = DateTime.tryParse(value ?? '');
      return d == null
          ? 'Não informado'
          : DateFormat('dd/MM/yyyy · HH:mm').format(d.toLocal());
    }

    Widget field(
      TextEditingController controller,
      String label,
      IconData icon, {
      String? Function(String?)? validator,
    }) => TextFormField(
      controller: controller,
      maxLength: 250,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        counterText: '',
      ),
    );
    final identity = SectionCard(
      title: 'Acesso institucional',
      subtitle: 'Dados definidos pela administração.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Info(
            label: 'Perfil de acesso',
            value: user.accessLevel.label,
            icon: Icons.verified_user_outlined,
          ),
          _Info(
            label: 'Matrícula / identificação',
            value: user.identifier,
            icon: Icons.badge_outlined,
          ),
          _Info(
            label: 'Situação',
            value: user.status,
            icon: Icons.check_circle_outline,
          ),
          _Info(
            label: 'Conta criada em',
            value: date(user.createdAt),
            icon: Icons.calendar_month_outlined,
          ),
          _Info(
            label: 'Último acesso',
            value: date(user.lastAccess),
            icon: Icons.schedule,
          ),
          const SizedBox(height: 12),
          Text(
            'Para alterar matrícula ou permissões, procure um administrador.',
            style: TextStyle(
              color: context.palette.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
    final details = Form(
      key: form,
      child: SectionCard(
        title: 'Informações do perfil',
        subtitle: 'Mantenha seus dados pessoais e profissionais atualizados.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(
              name,
              'Nome completo',
              Icons.person_outline,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe seu nome.' : null,
            ),
            const SizedBox(height: 16),
            field(
              email,
              'E-mail',
              Icons.mail_outline,
              validator: (v) =>
                  v == null ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                  ? 'Informe um e-mail válido.'
                  : null,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final fields = [
                  field(job, 'Cargo / função', Icons.work_outline),
                  field(department, 'Setor', Icons.apartment_outlined),
                ];
                return c.maxWidth < 520
                    ? Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 16),
                          fields[1],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: fields[0]),
                          const SizedBox(width: 16),
                          Expanded(child: fields[1]),
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            SecretField(
              controller: confirmation,
              label: 'Senha atual para alterar o e-mail',
              validator: (v) =>
                  email.text.trim().toLowerCase() != user.email &&
                      (v == null || v.isEmpty)
                  ? 'Confirme sua senha atual.'
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              'A senha é solicitada apenas quando o e-mail de acesso muda.',
              style: TextStyle(color: context.palette.muted, fontSize: 11),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => setState(() {
                          load(user);
                          confirmation.clear();
                        }),
                  child: const Text('Descartar alterações'),
                ),
                FilledButton.icon(
                  key: const Key('profile_save'),
                  onPressed: saving ? null : save,
                  icon: Icon(
                    saving ? Icons.hourglass_top : Icons.check,
                    size: 18,
                  ),
                  label: Text(saving ? 'Salvando...' : 'Salvar alterações'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return AccountLayout(
      selected: 'profile',
      title: 'Meu perfil',
      subtitle: 'Sua identidade, segurança e preferências em um só lugar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountBanner(
            title: user.name,
            subtitle:
                '${user.accessLevel.label} · ${user.department.isEmpty ? 'Portal SEMOB' : user.department}',
            icon: Icons.person_outline,
            leading: UserAvatar(user: user, radius: 34),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Foto de perfil',
            subtitle: 'Uma foto para identificar você no portal.',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(user: user, radius: 38),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            key: const Key('profile_photo'),
                            onPressed: photoBusy ? null : () => photo(),
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: Text(
                              photoBusy
                                  ? 'Atualizando...'
                                  : 'Escolher do computador',
                            ),
                          ),
                          if (user.avatarVersion != null)
                            TextButton(
                              onPressed: photoBusy
                                  ? null
                                  : () => photo(remove: true),
                              child: const Text('Remover foto'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'PNG ou JPG, até 1,5 MB. A foto é ajustada ao formato quadrado e salva na sua conta.',
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < 900
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [details, const SizedBox(height: 20), identity],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: details),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: identity),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          const _SecurityCard(),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.palette.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: context.palette.muted, fontSize: 11),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: hidden,
    maxLength: 256,
    validator: widget.validator,
    enableSuggestions: false,
    autocorrect: false,
    decoration: InputDecoration(
      labelText: widget.label,
      counterText: '',
      prefixIcon: const Icon(Icons.lock_outline, size: 19),
      suffixIcon: IconButton(
        tooltip: hidden ? 'Mostrar senha' : 'Ocultar senha',
        onPressed: () => setState(() => hidden = !hidden),
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class _SecurityCard extends ConsumerStatefulWidget {
  const _SecurityCard();
  @override
  ConsumerState<_SecurityCard> createState() => _SecurityState();
}

class _SecurityState extends ConsumerState<_SecurityCard> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    current.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action, String success) async {
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      ref.invalidate(remoteProvider('auth/sessions'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(remoteProvider('auth/sessions'));
    return SectionCard(
      title: 'Segurança da conta',
      subtitle: 'Altere sua senha e controle seus acessos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 20),
            leading: Icon(
              Icons.password_outlined,
              color: context.palette.green,
            ),
            title: const Text(
              'Alterar senha',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'As outras sessões serão encerradas.',
              style: TextStyle(fontSize: 12),
            ),
            children: [
              Form(
                key: form,
                child: Column(
                  children: [
                    SecretField(
                      controller: current,
                      label: 'Senha atual',
                      validator: (v) => v == null || v.isEmpty
                          ? 'Informe a senha atual.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    SecretField(
                      controller: password,
                      label: 'Nova senha',
                      validator: (v) => v == null || v.length < 12
                          ? 'Use pelo menos 12 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    SecretField(
                      controller: confirmation,
                      label: 'Confirme a nova senha',
                      validator: (v) => v != password.text
                          ? 'As senhas não coincidem.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () {
                                if (!form.currentState!.validate()) return;
                                run(
                                  () async {
                                    await ref
                                        .read(apiClientProvider)
                                        .dio
                                        .post<void>(
                                          'auth/password',
                                          data: {
                                            'currentPassword': current.text,
                                            'password': password.text,
                                            'passwordConfirmation':
                                                confirmation.text,
                                          },
                                        );
                                    current.clear();
                                    password.clear();
                                    confirmation.clear();
                                  },
                                  'Senha atualizada. As outras sessões foram encerradas.',
                                );
                              },
                        child: Text(
                          busy ? 'Atualizando...' : 'Atualizar senha',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          PreferenceRow(
            title: 'Sessões da conta',
            subtitle: sessions.when(
              data: (v) =>
                  '${v['active'] ?? 1} sessão(ões) ativa(s). Esta sessão será mantida.',
              loading: () => 'Consultando acessos...',
              error: (_, _) => 'Confira os acessos da sua conta.',
            ),
            control: OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await ref
                          .read(apiClientProvider)
                          .dio
                          .post<void>('auth/sessions/revoke-others');
                    }, 'Outras sessões encerradas.'),
              icon: const Icon(Icons.devices_outlined, size: 18),
              label: const Text('Encerrar outras sessões'),
            ),
          ),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final success = await ref
                          .read(authProvider.notifier)
                          .signOut();
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não foi possível sair. Tente novamente.',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair da conta'),
            ),
          ),
        ],
      ),
    );
  }
}
