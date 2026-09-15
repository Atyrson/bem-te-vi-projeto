import 'package:flutter/material.dart';

import 'package:projeto/Core/Models/cifModels.dart';

/// Campo visual da CIF. A lista de campos é fornecida pelo backend; este
/// widget só conhece a escala permitida e preserva a diferença entre null e 0.
class CifFieldInput extends StatelessWidget {
  final CifField field;
  final int? value;
  final List<int> allowedValues;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  const CifFieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.allowedValues,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final unanswered = value == null;
    final theme = Theme.of(context);
    final borderColor = unanswered
        ? Colors.orange.shade300
        : theme.colorScheme.primary.withValues(alpha: 0.45);

    return Card(
      key: ValueKey('cif-field-card-${field.key}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: unanswered ? Colors.orange.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.code,
              key: ValueKey('cif-field-code-${field.key}'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              field.description,
              key: ValueKey('cif-field-description-${field.key}'),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    unanswered ? 'Sem resposta' : 'Nota selecionada: $value',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: unanswered
                          ? Colors.orange.shade900
                          : Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!unanswered && enabled)
                  TextButton(
                    onPressed: () => onChanged(null),
                    child: const Text('Limpar'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: allowedValues
                  .map((option) {
                    return ChoiceChip(
                      label: Text(option.toString()),
                      selected: value == option,
                      onSelected: enabled ? (_) => onChanged(option) : null,
                      tooltip: 'Selecionar nota $option',
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
