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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Configurações do ciclo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (isRunning) ...[
              const SizedBox(height: 6),
              Text(
                'Configurações bloqueadas enquanto o timer estiver em execução.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),

            _buildConfigInput(
              label: 'Foco (min)',
              controller: workMinutesCtrl,
              enabled: !isRunning,
            ),
            _buildConfigInput(
              label: 'Pausa curta (min)',
              controller: shortBreakMinutesCtrl,
              enabled: !isRunning,
            ),
            _buildConfigInput(
              label: 'Pausa longa (min)',
              controller: longBreakMinutesCtrl,
              enabled: !isRunning,
            ),
            _buildConfigInput(
              label: 'Ciclos antes da pausa longa',
              controller: cyclesBeforeLongBreakCtrl,
              enabled: !isRunning,
            ),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isRunning ? null : onApply,
                icon: const Icon(Icons.check),
                label: const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigInput({
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
