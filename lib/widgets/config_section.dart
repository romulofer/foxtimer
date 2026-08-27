import 'package:flutter/material.dart';

class ConfigSection extends StatelessWidget {
  final bool isRunning;

  final TextEditingController workMinutesCtrl;
  final TextEditingController shortBreakMinutesCtrl;
  final TextEditingController longBreakMinutesCtrl;
  final TextEditingController cyclesBeforeLongBreakCtrl;

  final VoidCallback onApply;

  const ConfigSection({
    super.key,
    required this.isRunning,
    required this.workMinutesCtrl,
    required this.shortBreakMinutesCtrl,
    required this.longBreakMinutesCtrl,
    required this.cyclesBeforeLongBreakCtrl,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Configurações do ciclo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (isRunning) ...[
              const SizedBox(height: 6),
              Text(
                'Bloqueado enquanto o timer está em execução.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildConfigInput(
                    context: context,
                    icon: Icons.local_fire_department_outlined,
                    label: 'Foco',
                    controller: workMinutesCtrl,
                    enabled: !isRunning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildConfigInput(
                    context: context,
                    icon: Icons.coffee_outlined,
                    label: 'Pausa curta',
                    controller: shortBreakMinutesCtrl,
                    enabled: !isRunning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildConfigInput(
                    context: context,
                    icon: Icons.weekend_outlined,
                    label: 'Pausa longa',
                    controller: longBreakMinutesCtrl,
                    enabled: !isRunning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildConfigInput(
                    context: context,
                    icon: Icons.repeat,
                    label: 'Ciclos',
                    controller: cyclesBeforeLongBreakCtrl,
                    enabled: !isRunning,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isRunning ? null : onApply,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigInput({
    required BuildContext context,
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: colorScheme.primary),
        isDense: true,
      ),
    );
  }
}
