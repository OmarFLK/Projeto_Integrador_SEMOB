import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/brand_mark.dart';
import 'auth_controller.dart';
import 'password_recovery_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.sessionExpired = false});

  final bool sessionExpired;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authProvider.notifier).showExpiredSession();
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    // The split institutional layout needs enough room for both panels.
    final compact = MediaQuery.sizeOf(context).width < 980;
    return Scaffold(
      backgroundColor: context.palette.surface,
      body: Row(
        children: [
          if (!compact) const Expanded(flex: 5, child: _InstitutionalPanel()),
          Expanded(
            flex: compact ? 1 : 4,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 24 : 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (compact) ...[
                            const BrandMark(),
                            const SizedBox(height: 42),
                          ],
                          Text(
                            'Portal de Operação\nde Transporte',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: context.palette.ink,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Acesso restrito a gestores e funcionários da SEMOB.',
                            style: TextStyle(
                              color: context.palette.muted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (auth.error != null) ...[
                            _LoginAlert(error: auth.error!),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            key: const Key('login_identifier'),
                            controller: _identifierController,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'E-mail ou matrícula',
                              hintText: 'Digite seu acesso institucional',
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('login_password'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: auth.rememberAccess,
                                    onChanged: (value) => ref
                                        .read(authProvider.notifier)
                                        .setRememberAccess(value ?? false),
                                  ),
                                  const Text('Lembrar acesso'),
                                ],
                              ),
                              TextButton(
                                onPressed: _showPasswordRecovery,
                                child: const Text('Esqueci minha senha'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            key: const Key('login_submit'),
                            onPressed: auth.isLoading || auth.initializing
                                ? null
                                : _submit,
                            child: auth.isLoading || auth.initializing
                                ? const SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Text('Entrar'),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Prefeitura Municipal de São Caetano do Sul • 2026',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.palette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final success = await ref
        .read(authProvider.notifier)
        .signIn(_identifierController.text, _passwordController.text);
    if (success && mounted) context.go('/dashboard');
  }

  Future<void> _showPasswordRecovery() async {
    await showPasswordRecoveryDialog(context, ref.read(apiClientProvider));
  }
}

class _InstitutionalPanel extends StatelessWidget {
  const _InstitutionalPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/login_bus.png', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0, 0.58, 1],
              colors: [
                const Color(0xC914211B),
                const Color(0x5214211B),
                context.palette.surface,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 52, 96, 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandMark(onDark: true),
              const Spacer(),
              const Text(
                'SEMOB',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'São Caetano do Sul',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 22),
              Container(width: 58, height: 4, color: AppColors.green),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginAlert extends StatelessWidget {
  const _LoginAlert({required this.error});

  final AuthError error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      AuthError.requiredFields => 'Preencha o acesso e a senha para continuar.',
      AuthError.invalidCredentials =>
        'Credenciais inválidas. Confira os dados e tente novamente.',
      AuthError.serviceUnavailable =>
        'Não foi possível entrar. Verifique a conexão e tente novamente.',
      AuthError.sessionExpired =>
        'Sua sessão expirou. Entre novamente para continuar.',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error == AuthError.sessionExpired
            ? context.palette.amberSoft
            : context.palette.redSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            error == AuthError.sessionExpired
                ? Icons.schedule_rounded
                : Icons.error_outline_rounded,
            color: error == AuthError.sessionExpired
                ? context.palette.amber
                : context.palette.red,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
