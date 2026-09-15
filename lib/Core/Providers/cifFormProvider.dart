import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Services/cif_service.dart';

/// Estado da tela CIF.
///
/// As respostas ficam indexadas pela chave única retornada pela API (por
/// exemplo, ``b:E9``), nunca pelo código CIF. O provider também não calcula
/// resultados: prévias e conclusão sempre passam pelo backend.
class CifFormProvider extends ChangeNotifier {
  final CifServiceBase service;

  CifForm? _form;
  CifAssessment? _assessment;
  CifPreview? _preview;
  CifPreviewResult? _validationResult;
  CifSummary? _summary;
  final Map<String, dynamic> _responses = {};
  final Set<String> _removedResponseKeys = {};
  final Set<String> _incompatiblePendingRemoval = {};

  int? _patientId;
  String? _patientName;
  String? _sex;
  int? _assessmentId;
  DateTime? _assessmentDate;
  String? _status;
  String? _errorMessage;
  String? _contextError;
  String? _summaryError;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPreviewing = false;
  bool _isSubmitting = false;
  bool _isSummaryLoading = false;
  bool _hasUnsavedChanges = false;
  bool _sexChanged = false;
  int _previewRequestNumber = 0;
  int _summaryRequestNumber = 0;
  int _contextGeneration = 0;
  Future<int>? _draftCreationFuture;
  Future<void> Function()? _retryAction;
  Future<void> Function()? _summaryRetryAction;
  Future<CifSummary?>? _summaryFuture;
  String? _summaryRequestKey;
  String? _initializationKey;

  CifFormProvider({CifServiceBase? service})
    : service = service ?? CifService();

  CifForm? get form => _form;
  CifAssessment? get assessment => _assessment;
  CifPreview? get preview => _preview;
  CifPreviewResult? get validationResult => _validationResult;
  CifSummary? get summary => _summary;
  CifSummary? get resumo => _summary;
  int? get patientId => _patientId;
  String? get patientName => _patientName;
  String? get sex => _sex;
  int? get assessmentId => _assessmentId;
  DateTime? get assessmentDate => _assessmentDate;
  String? get status => _status;
  String? get errorMessage => _errorMessage ?? _summaryError ?? _contextError;
  String? get contextError => _contextError;
  String? get summaryError => _summaryError;
  String? get erroResumo => _summaryError;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isPreviewing => _isPreviewing;
  bool get isSubmitting => _isSubmitting;
  bool get isSummaryLoading => _isSummaryLoading;
  bool get carregandoResumo => _isSummaryLoading;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get sexChanged => _sexChanged;
  bool get hasForm => _form != null;
  bool get isCompleted => _status == 'concluida';
  bool get canViewSummary => _summary != null;
  bool get podeVerResumo => canViewSummary;

  Map<String, dynamic> get responses => Map.unmodifiable(_responses);
  Map<String, dynamic> get respostas => responses;

  List<CifAreaGroup> get areaGroups => _form?.areaGroups ?? const [];
  List<CifField> get fields => _form?.fields ?? const [];
  int get totalFields => _form?.totalFields ?? 0;

  int get answeredCount {
    final availableKeys = fields.map((field) => field.key).toSet();
    return _responses.keys
        .where((key) => availableKeys.contains(key) && _responses[key] != null)
        .length;
  }

  int get respondidos => answeredCount;
  double get progress => totalFields == 0 ? 0 : answeredCount / totalFields;

  List<String> get incompatibleResponseKeys {
    final availableKeys = fields.map((field) => field.key).toSet();
    return <String>{
      ..._responses.keys.where((key) => !availableKeys.contains(key)),
      ..._incompatiblePendingRemoval,
    }.toList(growable: false);
  }

  List<String> get chavesIncompativeis => incompatibleResponseKeys;
  bool get hasIncompatibleResponses => incompatibleResponseKeys.isNotEmpty;

  List<CifValidationIssue> get pendingIssues {
    if (_validationResult != null) return _validationResult!.pendingIssues;
    if (_preview != null) return _preview!.pendencias;
    return _localPendingIssues;
  }

  List<CifValidationIssue> get pendencias => pendingIssues;
  List<CifValidationIssue> get errors =>
      _validationResult?.errors ?? _preview?.erros ?? const [];
  List<CifValidationIssue> get erros => errors;

  List<CifValidationIssue> get _localPendingIssues {
    return fields
        .where(
          (field) =>
              field.requiredOnConclusion &&
              (!_responses.containsKey(field.key) ||
                  _responses[field.key] == null),
        )
        .map(
          (field) => CifValidationIssue(
            code: 'campo_obrigatorio_ausente',
            message:
                'Campo de entrada obrigatório sem nota; 0 deve ser informado explicitamente.',
            field: field.key,
          ),
        )
        .toList(growable: false);
  }

  dynamic answerFor(String key) => _responses[key];
  dynamic respostaPara(String key) => answerFor(key);

  /// Inicializa o formulário para o paciente selecionado.
  ///
  /// A criação do rascunho não ocorre aqui. O registro só é criado quando o
  /// usuário salva, solicita prévia ou tenta concluir.
  Future<void> initialize({
    required int? patientId,
    required String? patientName,
    required String? sex,
    int? assessmentId,
  }) async {
    final key = '$patientId|$sex|${assessmentId ?? _assessmentId ?? ''}';
    if (_initializationKey == key &&
        (_isLoading || (_form != null && _errorMessage == null))) {
      return;
    }
    _initializationKey = key;
    _retryAction = () => initialize(
      patientId: patientId,
      patientName: patientName,
      sex: sex,
      assessmentId: assessmentId,
    );

    final samePatient = _patientId != null && _patientId == patientId;
    final requestedAssessmentId =
        assessmentId ?? (samePatient ? _assessmentId : null);
    final changedPatient = !samePatient;
    final changedAssessment =
        requestedAssessmentId != null && requestedAssessmentId != _assessmentId;
    final changedSex = samePatient && _sex != null && _sex != sex;

    if (changedPatient || changedAssessment) {
      _clearData(keepContext: true);
    }
    _sexChanged = changedSex;
    if (changedSex) {
      _contextGeneration++;
      _previewRequestNumber++;
      _preview = null;
      _validationResult = null;
      _isPreviewing = false;
    }
    _patientId = patientId;
    _patientName = patientName;
    _sex = sex;
    _assessmentId = requestedAssessmentId;
    _contextError = _validateContext(patientId, sex);

    if (_contextError != null) {
      _form = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loadedForm = await service.carregarFormulario(sex!);
      if (_initializationKey != key) return;
      _form = loadedForm;

      if (requestedAssessmentId != null) {
        final loadedAssessment = await service.consultarRascunho(
          patientId: patientId!,
          assessmentId: requestedAssessmentId,
        );
        if (_initializationKey != key) return;

        final localBeforeLoad = Map<String, dynamic>.from(_responses);
        final preserveLocal = changedSex && _hasUnsavedChanges;
        _applyAssessment(
          loadedAssessment,
          preserveLocalResponses: preserveLocal,
          localResponses: localBeforeLoad,
        );
      }
      _contextError = null;
      _errorMessage = null;
    } catch (error) {
      _setOperationError(error);
      rethrow;
    } finally {
      if (_initializationKey == key) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Sincroniza apenas o contexto, útil quando o PatientProvider muda durante
  /// a vida da tela. Um paciente diferente nunca herda respostas anteriores.
  Future<void> setPatientContext({
    required int? patientId,
    required String? patientName,
    required String? sex,
  }) => initialize(patientId: patientId, patientName: patientName, sex: sex);

  /// Carrega o quadro resumo usando a mesma consulta da avaliação.
  ///
  /// A leitura é deliberadamente independente das respostas locais: uma
  /// falha de rede, versão ou contexto nunca limpa [_responses].
  Future<CifSummary?> loadSummary({
    required int? patientId,
    required int? assessmentId,
    String? sex,
  }) {
    final key = '$patientId|$assessmentId|${sex ?? _sex ?? ''}';
    if (_summaryRequestKey == key &&
        _isSummaryLoading &&
        _summaryFuture != null) {
      return _summaryFuture!;
    }

    _summaryRetryAction = () async {
      await loadSummary(
        patientId: patientId,
        assessmentId: assessmentId,
        sex: sex,
      );
    };
    final future = _loadSummary(
      key: key,
      patientId: patientId,
      assessmentId: assessmentId,
      sex: sex,
    );
    _summaryFuture = future;
    return future;
  }

  Future<CifSummary?> carregarResumo({
    required int? patientId,
    required int? assessmentId,
    String? sex,
  }) => loadSummary(patientId: patientId, assessmentId: assessmentId, sex: sex);

  Future<void> retrySummary() async {
    final retry = _summaryRetryAction;
    if (retry != null) await retry();
  }

  Future<CifSummary?> _loadSummary({
    required String key,
    required int? patientId,
    required int? assessmentId,
    required String? sex,
  }) async {
    final requestNumber = ++_summaryRequestNumber;
    _summaryRequestKey = key;
    _isSummaryLoading = true;
    _summary = null;
    _summaryError = null;
    notifyListeners();

    try {
      if (patientId == null) {
        throw const CifApiException(
          message: 'Selecione um paciente antes de abrir o quadro resumo CIF.',
        );
      }
      if (assessmentId == null) {
        throw const CifApiException(
          message: 'A avaliação CIF não foi informada para o quadro resumo.',
        );
      }
      if (_patientId != null && _patientId != patientId) {
        throw const CifApiException(
          message: 'O paciente selecionado não corresponde à avaliação CIF.',
        );
      }

      final assessment = await service.consultarResumo(
        patientId: patientId,
        assessmentId: assessmentId,
      );
      if (requestNumber != _summaryRequestNumber) return null;

      if (assessment.id != assessmentId || assessment.patientId != patientId) {
        throw const CifApiException(
          message:
              'O paciente ou a avaliação retornados não correspondem ao contexto solicitado.',
        );
      }
      if (!assessment.isCompleted) {
        throw const CifApiException(
          message:
              'O quadro resumo só está disponível após a conclusão aceita pelo backend.',
        );
      }
      if (assessment.results == null) {
        throw const CifApiException(
          message:
              'A avaliação foi concluída, mas o backend não retornou resultados para o resumo.',
        );
      }

      // Quando a tela ainda não carregou o formulário, consulta-se somente
      // sua versão atual para detectar um catálogo incompatível. Esse
      // formulário nunca é usado para calcular ou preencher o resumo.
      final effectiveSex = sex ?? _sex;
      CifForm? currentForm = _form;
      if (currentForm == null &&
          (effectiveSex == 'Feminino' || effectiveSex == 'Masculino')) {
        currentForm = await service.carregarFormulario(effectiveSex!);
        if (requestNumber != _summaryRequestNumber) return null;
      }
      if (currentForm != null &&
          (currentForm.catalogVersion != assessment.catalogVersion ||
              currentForm.rulesVersion != assessment.rulesVersion)) {
        throw const CifApiException(
          message:
              'A versão do catálogo ou das regras desta avaliação não é compatível com a versão atual.',
        );
      }

      final loadedSummary = CifSummary.fromAssessment(assessment);
      if (!loadedSummary.definitive) {
        throw const CifApiException(
          message:
              'A avaliação não possui resultado definitivo validado pelo backend.',
        );
      }
      if (requestNumber == _summaryRequestNumber) {
        _summary = loadedSummary;
        _summaryError = null;
        notifyListeners();
      }
      return loadedSummary;
    } catch (error) {
      if (requestNumber == _summaryRequestNumber) {
        _summaryError = _summaryErrorMessage(error);
        notifyListeners();
      }
      rethrow;
    } finally {
      if (requestNumber == _summaryRequestNumber) {
        _isSummaryLoading = false;
        _summaryFuture = null;
        notifyListeners();
      }
    }
  }

  String _summaryErrorMessage(Object error) {
    if (error is CifApiException) return error.message;
    if (error is CifNetworkException) return error.message;
    return 'Não foi possível carregar o quadro resumo da avaliação CIF.';
  }

  void setAssessmentDate(DateTime date) {
    _assessmentDate = DateTime(date.year, date.month, date.day);
    _previewRequestNumber++;
    _isPreviewing = false;
    _hasUnsavedChanges = true;
    _errorMessage = null;
    notifyListeners();
  }

  void setAnswer(String key, int? value) {
    if (value != null && (value < 0 || value > 4)) {
      throw ArgumentError.value(
        value,
        'value',
        'A escala CIF aceita somente 0 a 4.',
      );
    }
    if (value == null) {
      _responses.remove(key);
      _removedResponseKeys.add(key);
    } else {
      _responses[key] = value;
      _removedResponseKeys.remove(key);
    }
    _previewRequestNumber++;
    _isPreviewing = false;
    _preview = null;
    _validationResult = null;
    _errorMessage = null;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void atualizarResposta(String key, int? value) => setAnswer(key, value);

  /// Remove respostas que pertencem ao formulário anterior. A operação só é
  /// considerada concluída depois que o PATCH com ``null`` for aceito.
  Future<void> removeIncompatibleResponses() async {
    final keys = incompatibleResponseKeys;
    if (keys.isEmpty) return;
    for (final key in keys) {
      _responses.remove(key);
      _removedResponseKeys.add(key);
    }
    _incompatiblePendingRemoval.addAll(keys);
    _previewRequestNumber++;
    _isPreviewing = false;
    _hasUnsavedChanges = true;
    _preview = null;
    notifyListeners();
    if (_assessmentId != null) {
      await saveDraft();
    } else {
      // Sem registro persistido, a remoção já é local e não há PATCH a
      // enviar. O próximo rascunho será criado sem as chaves antigas.
      _incompatiblePendingRemoval.clear();
      _sexChanged = false;
      notifyListeners();
    }
  }

  Future<CifAssessment?> saveDraft() async {
    if (_isSaving || _isSubmitting) return null;
    if (_patientId == null || _sex == null) {
      _contextError = _validateContext(_patientId, _sex);
      notifyListeners();
      return null;
    }
    if (isCompleted) {
      _errorMessage = 'Avaliações CIF concluídas não podem ser editadas.';
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _retryAction = () async {
      await saveDraft();
    };
    _errorMessage = null;
    notifyListeners();
    try {
      final existingId = _assessmentId;
      CifAssessment saved;
      if (existingId == null) {
        await _ensureDraft();
        saved = _assessment!;
      } else {
        saved = await service.atualizarRascunho(
          patientId: _patientId!,
          assessmentId: existingId,
          responses: _responsePatch,
          assessmentDate: _assessmentDate,
        );
        _applyAssessment(saved);
      }
      _hasUnsavedChanges = false;
      _errorMessage = null;
      notifyListeners();
      return saved;
    } catch (error) {
      _setOperationError(error);
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<CifPreview?> requestPreview() async {
    if (_isSubmitting) return null;
    if (_patientId == null || _sex == null) {
      _contextError = _validateContext(_patientId, _sex);
      notifyListeners();
      return null;
    }

    final requestNumber = ++_previewRequestNumber;
    _isPreviewing = true;
    _retryAction = () async {
      await requestPreview();
    };
    _errorMessage = null;
    notifyListeners();
    try {
      await _ensureDraft();
      final currentId = _assessmentId;
      if (currentId == null) return null;
      final response = await service.solicitarPrevia(
        patientId: _patientId!,
        assessmentId: currentId,
        responses: _responsePatch,
      );
      if (requestNumber == _previewRequestNumber) {
        _preview = response;
        _validationResult = null;
        _errorMessage = null;
        notifyListeners();
      }
      return response;
    } catch (error) {
      if (requestNumber == _previewRequestNumber) {
        _setOperationError(error);
      }
      rethrow;
    } finally {
      if (requestNumber == _previewRequestNumber) {
        _isPreviewing = false;
        notifyListeners();
      }
    }
  }

  Future<CifAssessment?> concludeAssessment() async {
    if (_isSubmitting) return null;
    if (_patientId == null || _sex == null) {
      _contextError = _validateContext(_patientId, _sex);
      notifyListeners();
      return null;
    }
    if (hasIncompatibleResponses) {
      _errorMessage =
          'Remova as respostas incompatíveis antes de concluir a avaliação.';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _retryAction = () async {
      await concludeAssessment();
    };
    _errorMessage = null;
    notifyListeners();
    try {
      await _ensureDraft();
      final currentId = _assessmentId;
      if (currentId == null) return null;
      final completed = await service.concluirAvaliacao(
        patientId: _patientId!,
        assessmentId: currentId,
        responses: _responsePatch,
      );
      if (completed.status != 'concluida') {
        throw const CifApiException(
          message: 'O backend não confirmou a conclusão da avaliação CIF.',
        );
      }
      _applyAssessment(completed);
      _hasUnsavedChanges = false;
      _errorMessage = null;
      notifyListeners();
      return completed;
    } catch (error) {
      _setOperationError(error);
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> retryLastOperation() async {
    final retry = _retryAction;
    if (retry != null) await retry();
  }

  /// Descarta todo o estado CIF local. Usado ao deixar de haver paciente
  /// selecionado ou ao trocar para outro paciente.
  void clear() {
    _clearData(keepContext: false);
    _patientId = null;
    _patientName = null;
    _sex = null;
    _contextError = null;
    _initializationKey = null;
    notifyListeners();
  }

  Map<String, dynamic> get _responsePatch {
    final patch = Map<String, dynamic>.from(_responses);
    for (final key in _removedResponseKeys) {
      patch[key] = null;
    }
    return patch;
  }

  Future<int> _ensureDraft() {
    final existingId = _assessmentId;
    if (existingId != null) return Future.value(existingId);
    final pending = _draftCreationFuture;
    if (pending != null) return pending;

    final future = _createDraft();
    _draftCreationFuture = future;
    future.then<void>(
      (_) {
        if (identical(_draftCreationFuture, future)) {
          _draftCreationFuture = null;
        }
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_draftCreationFuture, future)) {
          _draftCreationFuture = null;
        }
      },
    );
    return future;
  }

  Future<int> _createDraft() async {
    final generation = _contextGeneration;
    final patientId = _patientId!;
    try {
      final created = await service.criarRascunho(
        patientId: patientId,
        assessmentDate: _assessmentDate ?? _today(),
        responses: _responsePatch,
      );
      if (generation != _contextGeneration || patientId != _patientId) {
        // A requisição pertence a um paciente/contexto que já foi trocado.
        // Não injeta o ID retornado no estado atual.
        return created.id;
      }
      _assessmentId = created.id;
      _assessment = created;
      _status = created.status;
      _assessmentDate = created.assessmentDate;
      _removedResponseKeys.clear();
      _incompatiblePendingRemoval.clear();
      _hasUnsavedChanges = false;
      notifyListeners();
      return created.id;
    } catch (error) {
      _setOperationError(error);
      rethrow;
    }
  }

  void _applyAssessment(
    CifAssessment value, {
    bool preserveLocalResponses = false,
    Map<String, dynamic>? localResponses,
  }) {
    _assessment = value;
    _assessmentId = value.id;
    _status = value.status;
    _assessmentDate = value.assessmentDate;
    if (!preserveLocalResponses) {
      final loadedResponses = Map<String, dynamic>.from(value.responses)
        ..removeWhere((key, response) => response == null);
      _responses
        ..clear()
        ..addAll(loadedResponses);
      _removedResponseKeys.clear();
      _incompatiblePendingRemoval.clear();
      _hasUnsavedChanges = false;
    } else if (localResponses != null) {
      final loadedResponses = Map<String, dynamic>.from(value.responses)
        ..removeWhere((key, response) => response == null);
      _responses
        ..clear()
        ..addAll(loadedResponses)
        ..addAll(localResponses);
    }
  }

  String? _validateContext(int? patientId, String? sex) {
    if (patientId == null) {
      return 'Selecione um paciente antes de abrir o formulário CIF.';
    }
    if (sex == null || sex.isEmpty) {
      return 'O sexo do paciente é obrigatório para carregar o formulário CIF.';
    }
    if (sex != 'Feminino' && sex != 'Masculino') {
      return "O sexo deve ser exatamente 'Feminino' ou 'Masculino' para a CIF.";
    }
    return null;
  }

  void _setOperationError(Object error) {
    if (error is CifApiException) {
      _errorMessage = error.message;
      _validationResult = error.result;
    } else if (error is CifNetworkException) {
      _errorMessage = error.message;
    } else {
      _errorMessage = 'Não foi possível concluir a operação da avaliação CIF.';
    }
    notifyListeners();
  }

  void _clearData({required bool keepContext}) {
    _contextGeneration++;
    _previewRequestNumber++;
    _form = null;
    _assessment = null;
    _preview = null;
    _validationResult = null;
    _summaryRequestNumber++;
    _summary = null;
    _summaryError = null;
    _isSummaryLoading = false;
    _summaryFuture = null;
    _summaryRequestKey = null;
    _summaryRetryAction = null;
    _responses.clear();
    _removedResponseKeys.clear();
    _incompatiblePendingRemoval.clear();
    _assessmentId = null;
    _assessmentDate = _today();
    _status = null;
    _errorMessage = null;
    _isLoading = false;
    _isSaving = false;
    _isPreviewing = false;
    _isSubmitting = false;
    _draftCreationFuture = null;
    _hasUnsavedChanges = false;
    _sexChanged = false;
    if (!keepContext) _initializationKey = null;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    // O cliente HTTP pode ser compartilhado por um fake ou por outra tela;
    // portanto o provider não assume a propriedade dele.
    super.dispose();
  }
}

typedef CIFFormProvider = CifFormProvider;
