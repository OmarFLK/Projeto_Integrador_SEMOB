import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/page_components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _alerts = true;
  bool _weekly = true;
  bool _compact = false;

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageHeader(
        title: 'Configurações',
        subtitle: 'Preferências locais da experiência do portal',
      ),
      const SizedBox(height: 16),
      TwoColumnLayout(
        left: SectionCard(
          title: 'Notificações',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alertas operacionais'),
                subtitle: const Text(
                  'Avisos de viagens não realizadas e anomalias',
                ),
                value: _alerts,
                onChanged: (value) => setState(() => _alerts = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Resumo semanal'),
                subtitle: const Text('Receber um consolidado da operação'),
                value: _weekly,
                onChanged: (value) => setState(() => _weekly = value),
              ),
            ],
          ),
        ),
        right: SectionCard(
          title: 'Aparência',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Modo compacto'),
                subtitle: const Text(
                  'Reduzir o espaçamento de tabelas e painéis',
                ),
                value: _compact,
                onChanged: (value) => setState(() => _compact = value),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.language, color: AppColors.green),
                title: Text('Idioma'),
                subtitle: Text('Português (Brasil)'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preferências salvas localmente.')),
          ),
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Salvar preferências'),
        ),
      ),
    ],
  );
}
