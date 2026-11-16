import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/api_client.dart';

Future<void> showPasswordRecoveryDialog(
  BuildContext context,
  ApiClient apiClient,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _RecoveryGateway(client: apiClient),
);

class _RecoveryGateway extends StatefulWidget {
  const _RecoveryGateway({required this.client});
  final ApiClient client;
  @override
  State<_RecoveryGateway> createState() => _RecoveryGatewayState();
}

class _RecoveryGatewayState extends State<_RecoveryGateway> {
  late Future<Map<String, dynamic>> modes = load();
  Future<Map<String, dynamic>> load() async =>
      (await widget.client.dio.get<Map<String, dynamic>>(
        'auth/password-recovery/modes',
      )).data!;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: modes,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final value = snapshot.data!;
        if (value['manual'] == true) {
          return _ManualRecovery(
            client: widget.client,
            adminEmail: value['adminEmail'] as String? ?? '',
            automatic: value['automatic'] == true,
          );
        }
        if (value['automatic'] == true) return _Recovery(client: widget.client);
      }
      return AlertDialog(
        title: const Text('Recuperar acesso'),
        content: SizedBox(
          width: 420,
          child: snapshot.connectionState != ConnectionState.done
              ? const LinearProgressIndicator()
              : Text(
                  snapshot.hasError
                      ? 'Não foi possível consultar as opções de recuperação. Tente novamente.'
                      : 'Recuperação indisponível. Procure a administração do portal.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          if (snapshot.hasError)
            TextButton(
              onPressed: () => setState(() => modes = load()),
              child: const Text('Tentar novamente'),
            ),
        ],
      );
    },
  );
}

class _ManualRecovery extends StatefulWidget {
  const _ManualRecovery({
    required this.client,
    required this.adminEmail,
    required this.automatic,
  });
  final ApiClient client;
  final String adminEmail;
  final bool automatic;
  @override
  State<_ManualRecovery> createState() => _ManualRecoveryState();
}

class _ManualRecoveryState extends State<_ManualRecovery> {
  final name = TextEditingController(),
      identifier = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, obscure = true;
  String? error, protocol;
  @override
  void dispose() {
    for (final c in [name, identifier, password, confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty ||
        identifier.text.trim().isEmpty ||
        password.text.length < 12 ||
        password.text.length > 256 ||
        password.text != confirmation.text) {
      setState(
        () => error =
            'Preencha seu nome e acesso. Use de 12 a 256 caracteres na senha e confirme o mesmo valor.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.client.dio.post<Map<String, dynamic>>(
        'auth/password-recovery/manual',
        data: {
          'name': name.text.trim(),
          'identifier': identifier.text.trim(),
          'password': password.text,
          'passwordConfirmation': confirmation.text,
        },
      );
      if (mounted) {
        setState(() => protocol = result.data!['requestId'] as String);
      }
      password.clear();
      confirmation.clear();
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      protocol == null ? 'Recuperar seu acesso' : 'Solicitação registrada',
    ),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              protocol == null
                  ? Icons.admin_panel_settings_outlined
                  : Icons.mark_email_read_outlined,
              color: context.palette.green,
              size: 36,
            ),
            const SizedBox(height: 16),
            if (protocol == null) ...[
              const Text(
                'Solicite uma revisão à administração. Sua senha só será alterada depois da confirmação da sua identidade e da aprovação.',
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('recovery_name'),
                controller: name,
                maxLength: 250,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Seu nome'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('recovery_identifier'),
                controller: identifier,
                maxLength: 250,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'E-mail ou matrícula',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('recovery_password'),
                controller: password,
                obscureText: obscure,
                maxLength: 256,
                decoration: InputDecoration(
                  labelText: 'Nova senha desejada',
                  helperText: 'Pelo menos 12 caracteres',
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('recovery_confirmation'),
                controller: confirmation,
                obscureText: obscure,
                maxLength: 256,
                decoration: const InputDecoration(
                  labelText: 'Confirme a nova senha',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    error!,
                    style: TextStyle(color: context.palette.red),
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
            ] else ...[
              const Text(
                'Se os dados corresponderem a uma conta, a administração analisará o pedido. Aguarde a confirmação antes de usar a nova senha.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Protocolo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SelectableText(protocol!),
              const SizedBox(height: 14),
              if (widget.adminEmail.isNotEmpty)
                Text(
                  'Para acompanhar o pedido, procure a administração: ${widget.adminEmail}. Informe o protocolo, sem enviar sua senha.',
                ),
              const SizedBox(height: 10),
              const Text(
                'O registro do pedido não confirma envio de e-mail.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(protocol == null ? 'Cancelar' : 'Voltar ao login'),
      ),
      if (protocol == null && widget.automatic)
        TextButton(
          onPressed: busy
              ? null
              : () {
                  final client = widget.client;
                  final parent = Navigator.of(context);
                  parent.pop();
                  showDialog<void>(
                    context: parent.context,
                    builder: (_) => _Recovery(client: client),
                  );
                },
          child: const Text('Usar código por e-mail'),
        ),
      if (protocol == null)
        FilledButton(
          key: const Key('recovery_submit'),
          onPressed: busy ? null : submit,
          child: const Text('Solicitar revisão'),
        )
      else
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: protocol!)),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copiar protocolo'),
        ),
    ],
  );
}

class _Recovery extends StatefulWidget {
  const _Recovery({required this.client});
  final ApiClient client;
  @override
  State<_Recovery> createState() => _RecoveryState();
}

class _RecoveryState extends State<_Recovery> {
  final email = TextEditingController(),
      confirmation = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      passwordConfirmation = TextEditingController();
  int step = 0;
  bool busy = false;
  String? error, challenge, resetToken, developmentCode;
  @override
  void dispose() {
    for (final c in [
      email,
      confirmation,
      code,
      password,
      passwordConfirmation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(step == 3 ? 'Senha redefinida' : 'Recuperar acesso'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (step == 0) ...[
              const Text('Informe e confirme o e-mail da sua conta.'),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail institucional',
                ),
              ),
              TextField(
                controller: confirmation,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Confirme o e-mail',
                ),
              ),
            ],
            if (step == 1) ...[
              const Text(
                'Se o e-mail estiver cadastrado, você receberá um código válido por 10 minutos.',
              ),
              if (developmentCode != null)
                Text('Código de desenvolvimento: $developmentCode'),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Código de verificação',
                ),
              ),
            ],
            if (step == 2) ...[
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nova senha (mínimo 12 caracteres)',
                ),
              ),
              TextField(
                controller: passwordConfirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirme a nova senha',
                ),
              ),
            ],
            if (step == 3)
              const Text(
                'Sua senha foi alterada e as sessões anteriores foram encerradas. Entre com a nova senha.',
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(step == 3 ? 'Voltar ao login' : 'Cancelar'),
      ),
      if (step < 3)
        ElevatedButton(
          onPressed: busy ? null : _continue,
          child: Text(
            step == 0
                ? 'Enviar código'
                : step == 1
                ? 'Validar código'
                : 'Redefinir senha',
          ),
        ),
    ],
  );
  Future<void> _continue() async {
    if (step == 0 &&
        (email.text.trim().isEmpty ||
            email.text.trim().toLowerCase() !=
                confirmation.text.trim().toLowerCase())) {
      setState(() => error = 'Os e-mails precisam ser iguais.');
      return;
    }
    if (step == 2 &&
        (password.text.length < 12 ||
            password.text != passwordConfirmation.text)) {
      setState(
        () => error = 'Use pelo menos 12 caracteres e confirme a senha.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final dio = widget.client.dio;
      if (step == 0) {
        final r = await dio.post<Map<String, dynamic>>(
          'auth/password-recovery/request',
          data: {
            'email': email.text.trim(),
            'emailConfirmation': confirmation.text.trim(),
          },
        );
        challenge = r.data!['challengeId'] as String;
        developmentCode = r.data!['developmentCode'] as String?;
      } else if (step == 1) {
        final r = await dio.post<Map<String, dynamic>>(
          'auth/password-recovery/verify',
          data: {'challengeId': challenge, 'code': code.text.trim()},
        );
        resetToken = r.data!['resetToken'] as String;
      } else {
        await dio.post<void>(
          'auth/password-recovery/reset',
          data: {
            'challengeId': challenge,
            'resetToken': resetToken,
            'password': password.text,
          },
        );
      }
      if (mounted) setState(() => step++);
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
