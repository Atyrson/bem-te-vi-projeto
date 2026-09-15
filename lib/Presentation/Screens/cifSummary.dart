import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifFormProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';

/// Quadro resumo da CIF. Todos os valores apresentados vêm do backend.
class CifSummaryScreen extends StatefulWidget {
  final int? assessmentId;

  const CifSummaryScreen({super.key, this.assessmentId});

  @override
  State<CifSummaryScreen> createState() => _CifSummaryScreenState();
}

class _CifSummaryScreenState extends State<CifSummaryScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  String? _contextKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final patient = context.read<PatientProvider>();
    final provider = context.read<CifFormProvider>();
    final requestedAssessmentId = widget.assessmentId ?? provider.assessmentId;
    final key = '${patient.id}|${patient.sexo}|${requestedAssessmentId ?? ''}';
    if (_contextKey == key) return;
    _contextKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSummary();
    });
  }

  Future<void> _loadSummary() async {
    final patient = context.read<PatientProvider>();
    final provider = context.read<CifFormProvider>();
    final requestedAssessmentId = widget.assessmentId ?? provider.assessmentId;
    try {
      await provider.loadSummary(
        patientId: patient.id,
        assessmentId: requestedAssessmentId,
        sex: patient.sexo,
      );
    } catch (_) {
      // O provider mantém a mensagem e permite nova tentativa pela tela.
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final provider = context.watch<CifFormProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quadro resumo CIF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            key: const ValueKey('cif-summary-history-action'),
            tooltip: 'Histórico CIF',
            onPressed: patient.id == null
                ? null
                : () => Navigator.of(context).pushNamed('/cif_history'),
            icon: const Icon(Icons.history_outlined),
          ),
        ],
      ),
      body: _buildBody(patient, provider),
    );
  }

  Widget _buildBody(PatientProvider patient, CifFormProvider provider) {
    if (patient.id == null) {
      return _blockedMessage(
        'Selecione um paciente antes de abrir o quadro resumo CIF.',
      );
    }
    if (provider.isSummaryLoading && provider.summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = provider.summary;
    if (summary == null) return _errorState(provider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        _buildMetadata(patient, summary),
        const SizedBox(height: 8),
        _buildReadOnlyAction(summary),
        const SizedBox(height: 8),
        _buildAreas(summary),
        const SizedBox(height: 8),
        _buildChapters(summary),
        if (summary.definitive && summary.generalResult != null) ...[
          const SizedBox(height: 8),
          _buildGeneralResult(summary.generalResult!),
        ],
      ],
    );
  }

  Widget _buildMetadata(PatientProvider patient, CifSummary summary) {
    final identifier = patient.cpf?.trim().isNotEmpty == true
        ? 'CPF: ${patient.cpf}'
        : 'ID do paciente: ${patient.id}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient.nome ?? 'Paciente sem nome',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(identifier),
            const Divider(height: 22),
            _metadataLine(
              'Data da avaliação',
              _dateFormat.format(summary.assessmentDate),
            ),
            _metadataLine('ID da avaliação', summary.assessmentId.toString()),
            _metadataLine('Status', summary.status),
            if (summary.resultStatus != null)
              _metadataLine('Status do resultado', summary.resultStatus!),
            _metadataLine('Catálogo', summary.catalogVersion),
            _metadataLine('Regras', summary.rulesVersion),
            _metadataLine(
              'Resultado validado',
              summary.definitive ? 'Sim' : 'Não',
            ),
          ],
        ),
      ),
    );
  }

  Widget _metadataLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 142,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildAreas(CifSummary summary) {
    return _buildResultSection(
      title: 'Áreas (${summary.areas.length})',
      children: summary.areas.values
          .map((area) {
            return _resultRow(
              key: ValueKey('cif-summary-area-${area.code}'),
              title: area.name.isEmpty ? area.code : area.name,
              code: area.code,
              value: _displayValue(area.value, area.pending),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildChapters(CifSummary summary) {
    return _buildResultSection(
      title: 'Capítulos (${summary.chapters.length})',
      children: summary.chapters.values
          .map((chapter) {
            final origin = chapter.sourceField.isEmpty
                ? null
                : 'Origem: ${chapter.sourceField}';
            return _resultRow(
              key: ValueKey('cif-summary-chapter-${chapter.code}'),
              title: chapter.code,
              code: origin,
              value: _displayValue(chapter.value, chapter.pending),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildResultSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (children.isEmpty)
              const Text('Nenhum resultado retornado pelo backend.')
            else
              ...children,
          ],
        ),
      ),
    );
  }

  Widget _resultRow({
    required Key key,
    required String title,
    required String? code,
    required String value,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (code != null) ...[
                  const SizedBox(height: 2),
                  Text(code, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            key: ValueKey('${key.toString()}-value'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralResult(Object generalResult) {
    return Card(
      child: ListTile(
        title: const Text('Resultado geral'),
        trailing: Text(
          generalResult.toString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildReadOnlyAction(CifSummary summary) {
    return OutlinedButton.icon(
      key: const ValueKey('cif-original-responses-button'),
      onPressed: () => _showOriginalResponses(summary),
      icon: const Icon(Icons.fact_check_outlined),
      label: const Text('Consultar respostas originais'),
    );
  }

  Future<void> _showOriginalResponses(CifSummary summary) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final entries = summary.responses.entries.toList(growable: false);
        return AlertDialog(
          title: const Text('Respostas originais (somente leitura)'),
          content: SizedBox(
            width: 460,
            height: 420,
            child: entries.isEmpty
                ? const Center(
                    child: Text('Nenhuma resposta retornada pelo backend.'),
                  )
                : ListView.separated(
                    key: const ValueKey('cif-read-only-responses'),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        dense: true,
                        title: Text(entry.key),
                        trailing: Text(entry.value?.toString() ?? 'null'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  String _displayValue(num? value, bool pending) {
    if (pending || value == null) return 'Pendente';
    return value.toString();
  }

  Widget _errorState(CifFormProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              provider.summaryError ??
                  'Não foi possível carregar o quadro resumo CIF.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: provider.isSummaryLoading ? null : _loadSummary,
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
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

typedef CIFSummaryScreen = CifSummaryScreen;
