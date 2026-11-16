import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/forest_widgets.dart';
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
        if (mounted) ref.read(authProvider.notifier).showExpiredSession();
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
    final compact = MediaQuery.sizeOf(context).width < 980;
    final form = FrostedPanel(
      child: Padding(
        padding: EdgeInsets.all(compact ? 24 : 32),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: context.palette.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ACESSO INSTITUCIONAL',
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Portal de Operação\nde Transporte',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: compact ? 26 : 29,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bem-vindo de volta. Entre para acompanhar o que move São Caetano do Sul.',
                style: TextStyle(
                  color: context.palette.muted,
                  height: 1.6,
                  fontSize: 12,
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
                  hintText: 'Seu acesso institucional',
                  prefixIcon: Icon(Icons.badge_outlined, size: 19),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('login_password'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar senha'
                        : 'Ocultar senha',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
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
                        onChanged: (v) => ref
                            .read(authProvider.notifier)
                            .setRememberAccess(v ?? false),
                      ),
                      const Text(
                        'Lembrar acesso',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => showPasswordRecoveryDialog(
                      context,
                      ref.read(apiClientProvider),
                    ),
                    child: const Text(
                      'Esqueci minha senha',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                key: const Key('login_submit'),
                onPressed: auth.isLoading || auth.initializing ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: auth.isLoading || auth.initializing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Entrar'),
                            Icon(Icons.north_east_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: context.palette.line),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: context.palette.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Acesso restrito a gestores e funcionários da SEMOB. Seus dados são tratados com segurança.',
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 10,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.forest, AppColors.forestBlack],
              ),
            ),
          ),
          if (!compact)
            Positioned.fill(
              child: Opacity(
                opacity: .55,
                child: Image.asset(
                  'assets/images/login_bus.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.forestBlack.withValues(alpha: .25),
                    AppColors.forestBlack.withValues(alpha: .85),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 24 : 48,
                    vertical: 24,
                  ),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandMark(onDark: true),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (!compact)
                        const Expanded(flex: 6, child: _InstitutionalPanel()),
                      Expanded(
                        flex: compact ? 1 : 5,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 20 : 32,
                              12,
                              compact ? 20 : 48,
                              28,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: SemobPageTransition(child: form),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Text(
                    'Prefeitura Municipal de São Caetano do Sul • 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.softSage.withValues(alpha: .8),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
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
}

class _InstitutionalPanel extends StatelessWidget {
  const _InstitutionalPanel();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(56, 24, 48, 60),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.forest.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.sage.withValues(alpha: .4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco_outlined, color: AppColors.lime, size: 16),
              SizedBox(width: 8),
              Text(
                'MOBILIDADE COM INTELIGÊNCIA',
                style: TextStyle(
                  color: AppColors.ivory,
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Conectando\npessoas.\nMovendo a cidade.',
          style: TextStyle(
            color: AppColors.ivory,
            fontSize: 52,
            fontWeight: FontWeight.w700,
            height: 1.08,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Dados que orientam. Decisões que transformam.\nUma visão integrada do transporte municipal.',
          style: TextStyle(
            color: AppColors.softSage,
            fontSize: 13,
            height: 1.8,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: 64,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    ),
  );
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
