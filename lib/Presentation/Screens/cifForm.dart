import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifFormProvider.dart';
import 'package:projeto/Core/Providers/cifHistoryProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/Widgets/cifFieldInput.dart';

enum _CifExitAction { continueEditing, discard, saveDraft }

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
  bool _savingOnExit = false;
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
      _loadAssessmentNumbers();
    });
  }

  Future<void> _loadAssessmentNumbers() async {
    final history = context.read<CifHistoryProvider?>();
    final patientId = context.read<PatientProvider>().id;
    if (history == null || patientId == null) return;
    try {
      await history.ensureLoaded(patientId: patientId);
    } catch (_) {
      // A numeração não impede o preenchimento se o histórico falhar.
    }
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
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          ),
          actions: [
            IconButton(
              key: const ValueKey('cif-form-history-action'),
              tooltip: 'Histórico CIF',
              onPressed: patient.id == null
                  ? null
                  : () => Navigator.of(context).pushNamed('/cif_history'),
              icon: const Icon(Icons.history_outlined),
            ),
          ],
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
    if (provider.patientId != patient.id) {
      return const Center(child: CircularProgressIndicator());
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
    if (provider.isCompleted) {
      return _completedState(provider);
    }

    _syncExpansion(provider.form!);
    final items = _visibleItems(provider.form!);
    final hasPreview =
        provider.preview != null || provider.validationResult != null;
    return Column(
      children: [
        _buildPatientHeader(patient, provider),
        if (provider.errorMessage != null) _buildErrorBanner(provider),
        if (provider.hasIncompatibleResponses)
          _buildIncompatibleBanner(provider),
        _buildProgress(provider),
        Expanded(
          child: ListView.builder(
            key: ValueKey('cif-visible-list-${provider.form!.sex}'),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: items.length + (hasPreview ? 1 : 0),
            itemBuilder: (context, index) {
              if (hasPreview && index == 0) {
                return _buildPreviewBanner(provider);
              }
              final itemIndex = hasPreview ? index - 1 : index;
              return _buildItem(items[itemIndex], provider);
            },
          ),
        ),
      ],
    );
  }

  bool _shouldShowForm(PatientProvider patient, CifFormProvider provider) =>
      patient.id != null &&
      provider.patientId == patient.id &&
      (patient.sexo == 'Feminino' || patient.sexo == 'Masculino') &&
      provider.form != null;

  Widget _buildPatientHeader(
    PatientProvider patient,
    CifFormProvider provider,
  ) {
    final history = context.watch<CifHistoryProvider?>();
    final assessmentNumber = patient.id == null || provider.assessmentId == null
        ? null
        : history?.assessmentNumberFor(
            patientId: patient.id!,
            assessmentId: provider.assessmentId!,
          );
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
                assessmentNumber == null
                    ? 'Rascunho'
                    : 'Rascunho #$assessmentNumber',
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
    final result = preview?.result ?? provider.validationResult;
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
    final areas = result?.areas.values.toList(growable: false) ?? const [];
    final definitive = preview?.definitive ?? result?.definitive ?? false;

    return Card(
      key: const ValueKey('cif-preview-results'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: definitive ? Colors.green.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              definitive
                  ? 'Prévia completa pelo backend.'
                  : 'Prévia parcial pelo backend; não é resultado definitivo.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Valores calculados a partir das respostas preenchidas. '
              'Códigos pendentes ainda dependem de respostas.',
            ),
            if (areas.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Resultados calculados',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...areas.map(
                (area) => _buildPreviewArea(area, result!, provider),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Nenhum resultado calculado retornado pelo backend.',
                ),
              ),
            if (grouped.isNotEmpty)
              ExpansionTile(
                key: const ValueKey('cif-preview-pending-issues'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 12, bottom: 8),
                title: Text('Pendências (${issues.length})'),
                children: grouped.entries
                    .map(
                      (entry) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${entry.key}: ${entry.value}'),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (provider.errors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Erros: ${provider.errors.map((issue) => issue.message).join(' ')}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(
    CifPartialResult area,
    CifPreviewResult result,
    CifFormProvider provider,
  ) {
    final areaCode = area.area.isNotEmpty ? area.area : area.code;
    final chapterResults = result.chapters.values
        .where((chapter) => chapter.area == areaCode)
        .toList(growable: false);
    final calculatedItems = result.intermediates.values
        .where((item) => item.area == areaCode)
        .toList(growable: false);
    final chapterCodes = chapterResults.map((chapter) => chapter.code).toSet();
    final standalone = calculatedItems
        .where(
          (item) =>
              item.code != areaCode &&
              !chapterCodes.contains(item.code) &&
              !chapterResults.any(
                (chapter) => item.code.startsWith(chapter.code),
              ),
        )
        .toList(growable: false);
    final sortedStandalone = standalone.toList(growable: false)
      ..sort(_compareCalculatedItems);

    return Card(
      key: ValueKey('cif-preview-area-$areaCode'),
      margin: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: ValueKey('cif-preview-area-heading-$areaCode'),
            title: Text(
              '${areaCode.toUpperCase()} — ${area.name?.isNotEmpty == true ? area.name : areaCode}',
            ),
            trailing: _previewValue(area.value, area.pending),
          ),
          ...chapterResults.map((chapter) {
            final nested =
                calculatedItems
                    .where(
                      (item) =>
                          item.code != chapter.code &&
                          item.code.startsWith(chapter.code),
                    )
                    .toList(growable: false)
                  ..sort(_compareCalculatedItems);
            final description = provider.fields
                .where((field) => field.chapterCode == chapter.code)
                .firstOrNull
                ?.chapterDescription;
            final chapterTitle = description?.isNotEmpty == true
                ? '${chapter.code} — $description'
                : chapter.code;

            if (nested.isEmpty) {
              return ListTile(
                key: ValueKey('cif-preview-chapter-$areaCode-${chapter.code}'),
                dense: true,
                contentPadding: const EdgeInsets.only(left: 16, right: 16),
                title: Text(chapterTitle),
                trailing: _previewValue(chapter.value, chapter.pending),
              );
            }
            return ExpansionTile(
              key: ValueKey('cif-preview-chapter-$areaCode-${chapter.code}'),
              tilePadding: const EdgeInsets.only(left: 16, right: 16),
              childrenPadding: const EdgeInsets.only(left: 12),
              title: Text(chapterTitle),
              trailing: _previewExpansionTrailing(
                chapter.value,
                chapter.pending,
              ),
              children: nested.map(_buildPreviewCalculatedItem).toList(),
            );
          }),
          if (sortedStandalone.isNotEmpty) ...[
            const Divider(height: 1),
            const ListTile(
              dense: true,
              title: Text('Outros códigos calculados'),
            ),
            ...sortedStandalone.map(_buildPreviewCalculatedItem),
          ],
        ],
      ),
    );
  }

  Widget _previewExpansionTrailing(double? value, bool pending) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _previewValue(value, pending),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more),
      ],
    );
  }

  Widget _buildPreviewCalculatedItem(CifPartialResult item) {
    return ListTile(
      key: ValueKey('cif-preview-result-${item.field}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item.code),
      subtitle: item.field.isEmpty ? null : Text('Origem: ${item.field}'),
      trailing: _previewValue(item.value, item.pending),
    );
  }

  Widget _previewValue(double? value, bool pending) {
    return Text(
      pending || value == null ? 'Pendente' : value.toStringAsFixed(2),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: pending || value == null ? Colors.orange.shade900 : null,
      ),
    );
  }

  int _compareCalculatedItems(CifPartialResult first, CifPartialResult second) {
    final codeOrder = first.code.compareTo(second.code);
    return codeOrder != 0 ? codeOrder : first.field.compareTo(second.field);
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

  Widget _completedState(CifFormProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fact_check_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Esta avaliação está concluída e não pode ser editada. Abra o resumo para consultar os valores e as respostas originais.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: provider.assessmentId == null
                  ? null
                  : () => Navigator.of(context).pushNamed(
                      '/cif_summary',
                      arguments: {'assessmentId': provider.assessmentId},
                    ),
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Ver quadro resumo'),
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
    if (_savingOnExit) return false;
    final provider = context.read<CifFormProvider>();
    if (!provider.hasUnsavedChanges) return true;
    final action = await showDialog<_CifExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterações não salvas'),
        content: const Text(
          'Você pode salvar o rascunho antes de sair ou descartar as alterações locais.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _CifExitAction.continueEditing),
            child: const Text('Continuar preenchendo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _CifExitAction.discard),
            child: const Text('Sair'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _CifExitAction.saveDraft),
            child: const Text('Salvar rascunho e sair'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (action == _CifExitAction.discard) return true;
    if (action != _CifExitAction.saveDraft) return false;

    _savingOnExit = true;
    try {
      final saved = await provider.saveDraft();
      if (!mounted) return false;
      if (saved != null && !provider.hasUnsavedChanges) return true;
    } catch (_) {
      // O provider mantém as respostas locais e expõe a mensagem de erro.
    } finally {
      _savingOnExit = false;
    }
    if (mounted) {
      _showMessage(
        provider.errorMessage ??
            'Não foi possível salvar o rascunho. Tente novamente.',
      );
    }
    return false;
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
