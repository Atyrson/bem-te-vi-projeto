import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifFormProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/Widgets/cifFieldInput.dart';

class CifFormScreen extends StatefulWidget {
  final int? assessmentId;

  const CifFormScreen({super.key, this.assessmentId});

  @override
  State<CifFormScreen> createState() => _CifFormScreenState();
}

class _CifFormScreenState extends State<CifFormScreen> {
  // Formato numérico não depende de inicialização de dados de localização.
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  String? _contextKey;
  String? _formKey;
  final Set<String> _expandedAreas = {};
  final Set<String> _expandedChapters = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final patient = Provider.of<PatientProvider>(context);
    final key = '${patient.id}|${patient.sexo}|${widget.assessmentId ?? ''}';
    if (_contextKey == key) return;
    _contextKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeForPatient();
    });
  }

  Future<void> _initializeForPatient() async {
    final patient = context.read<PatientProvider>();
    final provider = context.read<CifFormProvider>();
    if (patient.id == null) {
      provider.clear();
      return;
    }
    try {
      await provider.initialize(
        patientId: patient.id,
        patientName: patient.nome,
        sex: patient.sexo,
        assessmentId: widget.assessmentId,
      );
    } catch (_) {
      // O provider mantém o erro e os dados locais para a nova tentativa.
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientProvider>();
    final provider = context.watch<CifFormProvider>();

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Avaliação CIF'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar',
            onPressed: () async {
              if (await _confirmExit() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: _buildBody(patient, provider),
        bottomNavigationBar: _shouldShowForm(patient, provider)
            ? _buildActions(provider)
            : null,
      ),
    );
  }

  Widget _buildBody(PatientProvider patient, CifFormProvider provider) {
    if (patient.id == null) {
      return _blockedMessage(
        'Selecione um paciente antes de abrir o formulário CIF.',
      );
    }
    if (patient.sexo != 'Feminino' && patient.sexo != 'Masculino') {
      return _blockedMessage(
        patient.sexo == null || patient.sexo!.isEmpty
            ? 'O sexo do paciente é obrigatório para carregar o formulário CIF.'
            : "O sexo '${patient.sexo}' não é aceito. Use exatamente Feminino ou Masculino.",
      );
    }
    if (provider.isLoading && provider.form == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.form == null) {
      return _errorState(provider);
    }

    _syncExpansion(provider.form!);
    final items = _visibleItems(provider.form!);
    return Column(
      children: [
        _buildPatientHeader(patient, provider),
        if (provider.errorMessage != null) _buildErrorBanner(provider),
        if (provider.hasIncompatibleResponses)
          _buildIncompatibleBanner(provider),
        _buildProgress(provider),
        if (provider.preview != null || provider.validationResult != null)
          _buildPreviewBanner(provider),
        Expanded(
          child: ListView.builder(
            key: ValueKey('cif-visible-list-${provider.form!.sex}'),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildItem(items[index], provider),
          ),
        ),
      ],
    );
  }

  bool _shouldShowForm(PatientProvider patient, CifFormProvider provider) =>
      patient.id != null &&
      (patient.sexo == 'Feminino' || patient.sexo == 'Masculino') &&
      provider.form != null;

  Widget _buildPatientHeader(
    PatientProvider patient,
    CifFormProvider provider,
  ) {
    final date = provider.assessmentDate ?? DateTime.now();
    final identifier = patient.cpf?.trim().isNotEmpty == true
        ? 'CPF: ${patient.cpf}'
        : 'ID do paciente: ${patient.id}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient.nome ?? 'Paciente sem nome',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 3),
            Text(identifier),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 19),
                const SizedBox(width: 7),
                Expanded(
                  child: Text('Data da avaliação: ${_dateFormat.format(date)}'),
                ),
                TextButton(
                  onPressed: provider.isCompleted ? null : _selectDate,
                  child: const Text('Alterar'),
                ),
              ],
            ),
            if (provider.assessmentId != null)
              Text(
                'Rascunho #${provider.assessmentId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(CifFormProvider provider) {
    final progress = provider.progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, size: 19),
              const SizedBox(width: 7),
              Text(
                '${provider.answeredCount} / ${provider.totalFields} respondidos',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (provider.pendingIssues.isNotEmpty)
                Text('${provider.pendingIssues.length} pendência(s)'),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(CifFormProvider provider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(provider.errorMessage!)),
          TextButton(
            onPressed:
                provider.isLoading || provider.isSaving || provider.isSubmitting
                ? null
                : () => _run(provider.retryLastOperation),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildIncompatibleBanner(CifFormProvider provider) {
    final keys = provider.incompatibleResponseKeys;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      color: Colors.amber.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Há respostas incompatíveis com o formulário deste sexo.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Chaves preservadas: ${keys.take(5).join(', ')}${keys.length > 5 ? '…' : ''}',
          ),
          TextButton.icon(
            onPressed: provider.isSaving
                ? null
                : () => _run(provider.removeIncompatibleResponses),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remover e salvar essas respostas'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBanner(CifFormProvider provider) {
    final preview = provider.preview;
    final issues = provider.pendingIssues;
    final grouped = <String, int>{};
    for (final issue in issues) {
      final field = issue.field == null
          ? null
          : provider.fields
                .where((item) => item.key == issue.field)
                .firstOrNull;
      final label = field == null
          ? 'Outras pendências'
          : '${field.chapterCode} — ${field.chapterDescription}';
      grouped[label] = (grouped[label] ?? 0) + 1;
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: preview?.definitive == true
            ? Colors.green.shade50
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview?.definitive == true
                ? 'Prévia completa pelo backend.'
                : 'Prévia parcial pelo backend; não é resultado definitivo.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (grouped.isNotEmpty) ...[
            const SizedBox(height: 5),
            const Text('Pendências por capítulo:'),
            ...grouped.entries.map(
              (entry) => Text('• ${entry.key}: ${entry.value}'),
            ),
          ],
          if (provider.errors.isNotEmpty)
            Text(
              'Erros: ${provider.errors.map((issue) => issue.message).join(' ')}',
            ),
        ],
      ),
    );
  }

  Widget _buildActions(CifFormProvider provider) {
    if (provider.isCompleted) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: ElevatedButton.icon(
            onPressed: provider.assessmentId == null
                ? null
                : () => Navigator.of(context).pushNamed(
                    '/cif_summary',
                    arguments: {'assessmentId': provider.assessmentId},
                  ),
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Ver quadro resumo'),
          ),
        ),
      );
    }
    final busy =
        provider.isSaving || provider.isPreviewing || provider.isSubmitting;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _run(_requestPreview),
                icon: provider.isPreviewing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined),
                label: const Text('Prévia'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || provider.isCompleted
                    ? null
                    : () => _run(_saveDraft),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    busy ||
                        provider.isCompleted ||
                        provider.hasIncompatibleResponses
                    ? null
                    : () => _run(_conclude),
                icon: provider.isSubmitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text('Concluir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(_CifListItem item, CifFormProvider provider) {
    if (item.area != null) {
      final area = item.area!;
      final expanded = _expandedAreas.contains(area.code);
      return Card(
        margin: const EdgeInsets.only(top: 8, bottom: 2),
        child: ListTile(
          leading: Icon(expanded ? Icons.folder_open : Icons.folder_outlined),
          title: Text(area.code.toUpperCase()),
          subtitle: Text(area.description),
          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() {
            if (expanded) {
              _expandedAreas.remove(area.code);
            } else {
              _expandedAreas.add(area.code);
            }
          }),
        ),
      );
    }
    if (item.chapter != null) {
      final chapter = item.chapter!;
      final chapterKey = '${item.areaCode}|${chapter.code}';
      final expanded = _expandedChapters.contains(chapterKey);
      return Card(
        margin: const EdgeInsets.only(left: 10, top: 5, bottom: 2),
        child: ListTile(
          leading: Icon(expanded ? Icons.menu_book : Icons.book_outlined),
          title: Text(chapter.code),
          subtitle: Text(chapter.description),
          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() {
            if (expanded) {
              _expandedChapters.remove(chapterKey);
            } else {
              _expandedChapters.add(chapterKey);
            }
          }),
        ),
      );
    }
    final field = item.field!;
    final rawValue = provider.answerFor(field.key);
    final fieldValue = rawValue is num ? rawValue.toInt() : null;
    final scale =
        provider.form?.scale.allowedValues
            .where((value) => value >= 0 && value <= 4)
            .toList(growable: false) ??
        const [0, 1, 2, 3, 4];
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 5),
      child: CifFieldInput(
        field: field,
        value: fieldValue,
        allowedValues: scale.isEmpty ? const [0, 1, 2, 3, 4] : scale,
        enabled: !provider.isCompleted,
        onChanged: (value) => provider.setAnswer(field.key, value),
      ),
    );
  }

  List<_CifListItem> _visibleItems(CifForm form) {
    final items = <_CifListItem>[];
    for (final area in form.areaGroups) {
      items.add(_CifListItem.area(area));
      if (!_expandedAreas.contains(area.code)) continue;
      for (final chapter in area.chapters) {
        items.add(_CifListItem.chapter(area.code, chapter));
        if (_expandedChapters.contains('${area.code}|${chapter.code}')) {
          items.addAll(
            chapter.fields.map((field) => _CifListItem.field(area.code, field)),
          );
        }
      }
    }
    return items;
  }

  void _syncExpansion(CifForm form) {
    final identity =
        '${form.sex}|${form.catalogVersion}|${form.fields.length}|${form.fields.isEmpty ? '' : form.fields.first.key}';
    if (_formKey == identity) return;
    _formKey = identity;
    _expandedAreas.clear();
    _expandedChapters.clear();
    if (form.areaGroups.isNotEmpty) {
      final firstArea = form.areaGroups.first;
      _expandedAreas.add(firstArea.code);
      if (firstArea.chapters.isNotEmpty) {
        _expandedChapters.add(
          '${firstArea.code}|${firstArea.chapters.first.code}',
        );
      }
    }
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
              provider.errorMessage ??
                  'Não foi possível carregar o formulário CIF.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : _initializeForPatient,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final provider = context.read<CifFormProvider>();
    final current = provider.assessmentDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (date != null) provider.setAssessmentDate(date);
  }

  Future<void> _saveDraft() async {
    try {
      await context.read<CifFormProvider>().saveDraft();
      if (mounted) _showMessage('Rascunho salvo com sucesso.');
    } catch (_) {}
  }

  Future<void> _requestPreview() async {
    try {
      await context.read<CifFormProvider>().requestPreview();
    } catch (_) {}
  }

  Future<void> _conclude() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concluir avaliação?'),
        content: const Text(
          'O backend validará e recalculará as respostas. Depois da conclusão, o rascunho não poderá ser editado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await context.read<CifFormProvider>().concludeAssessment();
      if (result != null && mounted) {
        _showMessage('Avaliação concluída pelo backend.');
      }
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
  }

  Future<bool> _confirmExit() async {
    final provider = context.read<CifFormProvider>();
    if (!provider.hasUnsavedChanges) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterações não salvas'),
        content: const Text('Deseja sair e perder as alterações locais?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar preenchendo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CifListItem {
  final String areaCode;
  final CifAreaGroup? area;
  final CifChapterGroup? chapter;
  final CifField? field;

  const _CifListItem._({
    required this.areaCode,
    this.area,
    this.chapter,
    this.field,
  });

  factory _CifListItem.area(CifAreaGroup area) =>
      _CifListItem._(areaCode: area.code, area: area);

  factory _CifListItem.chapter(String areaCode, CifChapterGroup chapter) =>
      _CifListItem._(areaCode: areaCode, chapter: chapter);

  factory _CifListItem.field(String areaCode, CifField field) =>
      _CifListItem._(areaCode: areaCode, field: field);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

typedef CIFFormScreen = CifFormScreen;
