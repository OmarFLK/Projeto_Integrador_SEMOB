import 'package:flutter/material.dart';
import '../../../services/api_client.dart';

Future<void> showPasswordRecoveryDialog(
  BuildContext context,
  ApiClient apiClient,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _Recovery(client: apiClient),
);

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
