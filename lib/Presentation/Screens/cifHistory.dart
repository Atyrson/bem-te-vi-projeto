import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifHistoryProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';

class CifHistoryScreen extends StatefulWidget {
  const CifHistoryScreen({super.key});

  @override
  State<CifHistoryScreen> createState() => _CifHistoryScreenState();
}

class _CifHistoryScreenState extends State<CifHistoryScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final Set<int> _selectedAssessmentIds = {};
  String? _contextKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final patient = context.read<PatientProvider>();
    final key = '${patient.id}|${patient.sexo}';
    if (_contextKey == key) return;
    _contextKey = key;
    _selectedAssessmentIds.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final patient = context.read<PatientProvider>();
    try {
      await context.read<CifHistoryProvider>().load(patientId: patient.id);
    } catch (_) {
      // A tela exibe o erro mantido pelo provider e oferece retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final history = context.watch<CifHistoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de avaliações CIF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            key: const ValueKey('cif-history-new-action'),
            tooltip: 'Nova avaliação',
            onPressed: patient.id == null || history.isCreating
                ? null
                : _createNewAssessment,
            icon: history.isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
          ),
        ],
      ),
      body: _buildBody(patient, history),
    );
  }

  Widget _buildBody(PatientProvider patient, CifHistoryProvider history) {
    if (patient.id == null) {
      return _blockedMessage(
        'Selecione um paciente antes de abrir o histórico CIF.',
      );
    }
    if (history.isLoading && history.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.errorMessage != null && history.entries.isEmpty) {
      return _errorState(history);
    }

    final entries = history.entries;
    return Column(
      children: [
        _buildPatientHeader(patient, entries.length),
        if (_selectedAssessmentIds.length == 2) _buildCompareAction(),
        Expanded(
          child: entries.isEmpty
              ? _emptyState(history)
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    key: const ValueKey('cif-history-list'),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _buildEntry(entries[index], patient.id!),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPatientHeader(PatientProvider patient, int count) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(patient.nome ?? 'Paciente sem nome'),
        subtitle: Text('$count avaliação(ões) encontradas'),
      ),
    );
  }

  Widget _buildEntry(CifAssessmentHistoryEntry entry, int selectedPatientId) {
    final selected = _selectedAssessmentIds.contains(entry.id);
    final canSelect = entry.isCompleted && entry.resultsAvailable;
    final isSafeEntry = entry.patientId == selectedPatientId;
    final date = entry.assessmentDate == null
        ? 'Data não informada'
        : _dateFormat.format(entry.assessmentDate!);
    final reference = entry.reassessmentReferenceDate;

    return Card(
      key: ValueKey('cif-history-entry-${entry.id}'),
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: canSelect
                  ? Checkbox(
                      key: ValueKey('cif-history-select-${entry.id}'),
                      value: selected,
                      onChanged: isSafeEntry
                          ? (_) => _toggleSelection(entry.id)
                          : null,
                    )
                  : Icon(
                      entry.isCompleted
                          ? Icons.fact_check_outlined
                          : Icons.edit_note_outlined,
                    ),
              title: Text('Avaliação #${entry.id}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _statusChip(entry),
                      if (entry.catalogVersion.isNotEmpty)
                        Chip(
                          label: Text('Catálogo ${entry.catalogVersion}'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (reference != null)
                    Text(
                      'Referência de reavaliação: ${_dateFormat.format(reference)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (entry.isCompleted && !entry.resultsAvailable)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 6),
                  child: Text('Resultados indisponíveis para esta avaliação.'),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: entry.isCompleted
                  ? TextButton.icon(
                      key: ValueKey('cif-history-open-summary-${entry.id}'),
                      onPressed: isSafeEntry && entry.resultsAvailable
                          ? () => _openSummary(entry.id)
                          : null,
                      icon: const Icon(Icons.table_view_outlined),
                      label: const Text('Abrir resumo'),
                    )
                  : TextButton.icon(
                      key: ValueKey('cif-history-open-draft-${entry.id}'),
                      onPressed: isSafeEntry
                          ? () => _openDraft(entry.id)
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Abrir rascunho'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(CifAssessmentHistoryEntry entry) {
    return Chip(
      label: Text(entry.isCompleted ? 'Concluída' : 'Rascunho'),
      avatar: Icon(
        entry.isCompleted ? Icons.check_circle_outline : Icons.edit_outlined,
        size: 16,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCompareAction() {
    final ids = _selectedAssessmentIds.toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const ValueKey('cif-history-compare-action'),
          onPressed: () => Navigator.of(context).pushNamed(
            '/cif_comparison',
            arguments: {
              'firstAssessmentId': ids[0],
              'secondAssessmentId': ids[1],
            },
          ),
          icon: const Icon(Icons.compare_arrows_outlined),
          label: const Text('Comparar avaliações selecionadas'),
        ),
      ),
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedAssessmentIds.contains(id)) {
        _selectedAssessmentIds.remove(id);
      } else if (_selectedAssessmentIds.length < 2) {
        _selectedAssessmentIds.add(id);
      }
    });
  }

  Future<void> _createNewAssessment() async {
    final patient = context.read<PatientProvider>();
    try {
      final created = await context
          .read<CifHistoryProvider>()
          .createNewAssessment(patientId: patient.id);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushNamed('/cif_form', arguments: {'assessmentId': created.id});
      if (mounted) await _loadHistory();
    } catch (_) {
      // O provider conserva a mensagem e a tela pode ser atualizada pelo
      // rebuild; erros de criação continuam visíveis no topo quando possível.
      if (mounted) setState(() {});
    }
  }

  void _openDraft(int id) {
    Navigator.of(
      context,
    ).pushNamed('/cif_form', arguments: {'assessmentId': id});
  }

  void _openSummary(int id) {
    Navigator.of(
      context,
    ).pushNamed('/cif_summary', arguments: {'assessmentId': id});
  }

  Widget _emptyState(CifHistoryProvider history) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Nenhuma avaliação CIF encontrada.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: history.isCreating ? null : _createNewAssessment,
              icon: const Icon(Icons.add),
              label: const Text('Nova avaliação'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(CifHistoryProvider history) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              history.errorMessage ??
                  'Não foi possível carregar o histórico CIF.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: history.isLoading ? null : _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockedMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

typedef CIFHistoryScreen = CifHistoryScreen;
