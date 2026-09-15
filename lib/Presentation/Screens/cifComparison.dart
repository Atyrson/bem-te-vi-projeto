import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifComparisonProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';

class CifComparisonScreen extends StatefulWidget {
  final int? firstAssessmentId;
  final int? secondAssessmentId;

  const CifComparisonScreen({
    super.key,
    this.firstAssessmentId,
    this.secondAssessmentId,
  });

  @override
  State<CifComparisonScreen> createState() => _CifComparisonScreenState();
}

class _CifComparisonScreenState extends State<CifComparisonScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  String? _contextKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final patient = context.read<PatientProvider>();
    final key =
        '${patient.id}|${widget.firstAssessmentId}|${widget.secondAssessmentId}';
    if (_contextKey == key) return;
    _contextKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadComparison();
    });
  }

  Future<void> _loadComparison() async {
    final patient = context.read<PatientProvider>();
    try {
      await context.read<CifComparisonProvider>().compare(
        patientId: patient.id,
        firstAssessmentId: widget.firstAssessmentId,
        secondAssessmentId: widget.secondAssessmentId,
      );
    } catch (_) {
      // O provider mantém a mensagem e disponibiliza retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final provider = context.watch<CifComparisonProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparação de avaliações CIF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar ao histórico',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(patient, provider),
    );
  }

  Widget _buildBody(PatientProvider patient, CifComparisonProvider provider) {
    if (patient.id == null) {
      return _message(
        'Selecione um paciente antes de comparar avaliações CIF.',
      );
    }
    if (provider.isLoading && provider.comparison == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final comparison = provider.comparison;
    if (comparison == null) return _errorState(provider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        _metadata(patient, comparison),
        const SizedBox(height: 8),
        _resultSection(
          title: 'Áreas (${comparison.areas.length})',
          children: comparison.areas.values
              .map(_areaRow)
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        _resultSection(
          title: 'Capítulos (${comparison.chapters.length})',
          children: comparison.chapters.values
              .map(_chapterRow)
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _metadata(PatientProvider patient, CifComparisonResult comparison) {
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
            const SizedBox(height: 8),
            _line(
              '1ª avaliação',
              '#${comparison.firstAssessmentId} — ${_formatDate(comparison.firstAssessmentDate)}',
            ),
            _line(
              '2ª avaliação',
              '#${comparison.secondAssessmentId} — ${_formatDate(comparison.secondAssessmentDate)}',
            ),
            _line('Catálogo', comparison.firstCatalogVersion),
            _line('Regras', comparison.firstRulesVersion),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
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

  Widget _areaRow(CifComparisonArea area) {
    return _comparisonRow(
      key: ValueKey('cif-comparison-area-${area.code}'),
      title: area.name.isEmpty ? area.code : area.name,
      code: area.code,
      firstValue: area.firstValue,
      secondValue: area.secondValue,
      difference: area.difference,
      firstPending: area.firstPending || area.firstMissing,
      secondPending: area.secondPending || area.secondMissing,
    );
  }

  Widget _chapterRow(CifComparisonChapter chapter) {
    return _comparisonRow(
      key: ValueKey('cif-comparison-chapter-${chapter.code}'),
      title: chapter.code,
      code: null,
      firstValue: chapter.firstValue,
      secondValue: chapter.secondValue,
      difference: chapter.difference,
      firstPending: chapter.firstPending || chapter.firstMissing,
      secondPending: chapter.secondPending || chapter.secondMissing,
    );
  }

  Widget _comparisonRow({
    required Key key,
    required String title,
    required String? code,
    required double? firstValue,
    required double? secondValue,
    required double? difference,
    required bool firstPending,
    required bool secondPending,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (code != null) Text(code),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              _valueLabel('1ª', firstValue, firstPending),
              _valueLabel('2ª', secondValue, secondPending),
              _valueLabel(
                'Diferença (2ª − 1ª)',
                difference,
                difference == null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueLabel(String label, double? value, bool pending) {
    return Text('$label: ${pending || value == null ? 'Pendente' : value}');
  }

  Widget _resultSection({
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

  String _formatDate(DateTime? value) =>
      value == null ? 'Data não informada' : _dateFormat.format(value);

  Widget _errorState(CifComparisonProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare_arrows_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ??
                  'Não foi possível comparar as avaliações CIF.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : _loadComparison,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String value) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(value, textAlign: TextAlign.center),
      ),
    );
  }
}

typedef CIFComparisonScreen = CifComparisonScreen;
