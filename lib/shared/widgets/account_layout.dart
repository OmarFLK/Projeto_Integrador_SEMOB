import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    void select(String key) {
      if (key == 'profile') {
        context.go('/profile');
      } else if (onSelect != null) {
        onSelect!(key);
      } else {
        context.go('/settings?tab=$key');
      }
    }

    return PageBody(
      maxWidth: 1440,
      children: [
        PageHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final menu = Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                      child: Text(
                        'MINHA CONTA',
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    for (final entry in accountSections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: selected == entry.key
                              ? context.palette.greenLight
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            leading: Icon(
                              entry.icon,
                              size: 20,
                              color: selected == entry.key
                                  ? context.palette.green
                                  : context.palette.muted,
                            ),
                            title: Text(
                              entry.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected == entry.key
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            onTap: () => select(entry.key),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (action != null) ...[
                  Align(alignment: Alignment.centerRight, child: action!),
                  const SizedBox(height: 12),
                ],
                child,
              ],
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 220, child: menu),
                  const SizedBox(width: 24),
                  Expanded(child: content),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in accountSections)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: selected == entry.key,
                            onSelected: (_) => select(entry.key),
                            avatar: Icon(entry.icon, size: 16),
                            label: Text(entry.label),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                content,
              ],
            );
          },
        ),
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
        colors: [Color(0xFF124A32), Color(0xFF087848), Color(0xFF127B73)],
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
