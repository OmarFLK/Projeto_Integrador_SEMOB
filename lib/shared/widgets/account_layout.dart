import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'page_components.dart';

const accountSections = [
  (key: 'profile', label: 'Meu perfil', icon: Icons.person_outline),
  (key: 'appearance', label: 'Aparência', icon: Icons.palette_outlined),
  (key: 'chat', label: 'Chat', icon: Icons.chat_bubble_outline),
  (
    key: 'ai',
    label: 'Inteligência artificial',
    icon: Icons.auto_awesome_outlined,
  ),
  (key: 'memory', label: 'Contexto e memória', icon: Icons.psychology_outlined),
  (key: 'privacy', label: 'Privacidade', icon: Icons.shield_outlined),
];

class AccountLayout extends StatelessWidget {
  const AccountLayout({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onSelect,
    this.action,
  });
  final String selected, title, subtitle;
  final Widget child;
  final ValueChanged<String>? onSelect;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return PageBody(
      maxWidth: 1440,
      children: [
        PageHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 24),
        if (action != null) ...[
          Align(alignment: Alignment.centerRight, child: action!),
          const SizedBox(height: 12),
        ],
        child,
      ],
    );
  }
}

class PreferenceRow extends StatelessWidget {
  const PreferenceRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.control,
  });
  final String title, subtitle;
  final Widget control;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: context.palette.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: control),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 24),
            control,
          ],
        );
      },
    ),
  );
}

class AccountBanner extends StatelessWidget {
  const AccountBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.leading,
  });
  final String title, subtitle;
  final IconData icon;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.forest, AppColors.moss, AppColors.forestBlack],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        leading ??
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFFCCF5DD), size: 28),
            ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFD3E9DE),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
