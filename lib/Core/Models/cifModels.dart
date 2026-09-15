// Modelos do contrato HTTP da avaliação CIF.
//
// Estes modelos mantêm as chaves retornadas pela API. O aplicativo não
// conhece fórmulas, catálogo ou estilos da planilha: ele apenas apresenta os
// campos e envia as respostas por [CifField.chave].

class CifScale {
  final List<int> allowedValues;
  final bool allowsUnansweredInDraft;
  final bool requiredOnConclusion;

  const CifScale({
    required this.allowedValues,
    required this.allowsUnansweredInDraft,
    required this.requiredOnConclusion,
  });

  factory CifScale.fromJson(Map<String, dynamic> json) {
    return CifScale(
      allowedValues: _readIntList(
        json['valores_permitidos'] ?? json['allowed_values'],
      ),
      allowsUnansweredInDraft: _readBool(
        json['permite_sem_resposta_no_rascunho'] ??
            json['allows_unanswered_in_draft'],
      ),
      requiredOnConclusion: _readBool(
        json['obrigatoria_na_conclusao'] ?? json['required_on_conclusion'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'valores_permitidos': List<int>.from(allowedValues),
    'permite_sem_resposta_no_rascunho': allowsUnansweredInDraft,
    'obrigatoria_na_conclusao': requiredOnConclusion,
  };

  List<int> get valoresPermitidos => allowedValues;
  bool get permiteSemRespostaNoRascunho => allowsUnansweredInDraft;
  bool get obrigatoriaNaConclusao => requiredOnConclusion;
}

class CifField {
  final int order;
  final String key;
  final String code;
  final String originalCode;
  final String description;
  final String areaCode;
  final String areaDescription;
  final String chapterCode;
  final String chapterDescription;
  final bool requiredOnConclusion;

  const CifField({
    required this.order,
    required this.key,
    required this.code,
    required this.originalCode,
    required this.description,
    required this.areaCode,
    required this.areaDescription,
    required this.chapterCode,
    required this.chapterDescription,
    required this.requiredOnConclusion,
  });

  factory CifField.fromJson(Map<String, dynamic> json) {
    return CifField(
      order: _readInt(json['ordem'] ?? json['order']) ?? 0,
      key: _readString(json['chave'] ?? json['key']),
      code: _readString(json['codigo'] ?? json['code']),
      originalCode: _readString(
        json['codigo_original'] ?? json['original_code'],
      ),
      description: _readString(json['descricao'] ?? json['description']),
      areaCode: _readString(json['area_codigo'] ?? json['area_code']),
      areaDescription: _readString(
        json['area_descricao'] ?? json['area_description'],
      ),
      chapterCode: _readString(json['capitulo_codigo'] ?? json['chapter_code']),
      chapterDescription: _readString(
        json['capitulo_descricao'] ?? json['chapter_description'],
      ),
      requiredOnConclusion: _readBool(
        json['obrigatorio_na_conclusao'] ?? json['required_on_conclusion'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'ordem': order,
    'chave': key,
    'codigo': code,
    'codigo_original': originalCode,
    'descricao': description,
    'area_codigo': areaCode,
    'area_descricao': areaDescription,
    'capitulo_codigo': chapterCode,
    'capitulo_descricao': chapterDescription,
    'obrigatorio_na_conclusao': requiredOnConclusion,
  };

  int get ordem => order;
  String get chave => key;
  String get codigo => code;
  String get codigoOriginal => originalCode;
  String get descricao => description;
  String get areaCodigo => areaCode;
  String get areaDescricao => areaDescription;
  String get capituloCodigo => chapterCode;
  String get capituloDescricao => chapterDescription;
  bool get obrigatorioNaConclusao => requiredOnConclusion;
}

class CifChapterGroup {
  final String code;
  final String description;
  final List<CifField> fields;

  const CifChapterGroup({
    required this.code,
    required this.description,
    required this.fields,
  });

  String get codigo => code;
  String get descricao => description;
}

class CifAreaGroup {
  final String code;
  final String description;
  final List<CifChapterGroup> chapters;

  const CifAreaGroup({
    required this.code,
    required this.description,
    required this.chapters,
  });

  String get codigo => code;
  String get descricao => description;
}

class CifForm {
  final String catalogVersion;
  final String rulesVersion;
  final String sex;
  final int totalFields;
  final CifScale scale;
  final List<CifField> fields;

  const CifForm({
    required this.catalogVersion,
    required this.rulesVersion,
    required this.sex,
    required this.totalFields,
    required this.scale,
    required this.fields,
  });

  factory CifForm.fromJson(Map<String, dynamic> json) {
    final rawFields = json['campos'] ?? json['fields'];
    final fields = rawFields is List
        ? rawFields
              .whereType<Map>()
              .map(
                (field) => CifField.fromJson(Map<String, dynamic>.from(field)),
              )
              .toList()
        : <CifField>[];
    fields.sort((a, b) => a.order.compareTo(b.order));

    return CifForm(
      catalogVersion: _readString(
        json['catalogo_versao'] ?? json['catalog_version'],
      ),
      rulesVersion: _readString(json['regras_versao'] ?? json['rules_version']),
      sex: _readString(json['sexo'] ?? json['sex']),
      totalFields:
          _readInt(json['total_campos'] ?? json['total_fields']) ??
          fields.length,
      scale: CifScale.fromJson(
        Map<String, dynamic>.from(
          (json['escala'] ?? json['scale'] ?? <String, dynamic>{}) as Map,
        ),
      ),
      fields: List.unmodifiable(fields),
    );
  }

  Map<String, dynamic> toJson() => {
    'catalogo_versao': catalogVersion,
    'regras_versao': rulesVersion,
    'sexo': sex,
    'total_campos': totalFields,
    'escala': scale.toJson(),
    'campos': fields.map((field) => field.toJson()).toList(),
  };

  String get catalogoVersao => catalogVersion;
  String get regrasVersao => rulesVersion;
  String get sexo => sex;
  int get totalCampos => totalFields;
  CifScale get escala => scale;
  List<CifField> get campos => fields;

  List<CifAreaGroup> get areaGroups {
    final areas = <String, _MutableAreaGroup>{};
    for (final field in fields) {
      final area = areas.putIfAbsent(
        field.areaCode,
        () => _MutableAreaGroup(field.areaCode, field.areaDescription),
      );
      final chapter = area.chapters.putIfAbsent(
        field.chapterCode,
        () => _MutableChapterGroup(field.chapterCode, field.chapterDescription),
      );
      chapter.fields.add(field);
    }
    return areas.values
        .map(
          (area) => CifAreaGroup(
            code: area.code,
            description: area.description,
            chapters: area.chapters.values
                .map(
                  (chapter) => CifChapterGroup(
                    code: chapter.code,
                    description: chapter.description,
                    fields: List.unmodifiable(chapter.fields),
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }
}

class _MutableAreaGroup {
  final String code;
  final String description;
  final Map<String, _MutableChapterGroup> chapters = {};

  _MutableAreaGroup(this.code, this.description);
}

class _MutableChapterGroup {
  final String code;
  final String description;
  final List<CifField> fields = [];

  _MutableChapterGroup(this.code, this.description);
}

class CifAssessment {
  final int id;
  final int patientId;
  final DateTime assessmentDate;
  final String status;
  final String catalogVersion;
  final String rulesVersion;
  final Map<String, dynamic> responses;
  final Map<String, dynamic>? results;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const CifAssessment({
    required this.id,
    required this.patientId,
    required this.assessmentDate,
    required this.status,
    required this.catalogVersion,
    required this.rulesVersion,
    required this.responses,
    required this.results,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
  });

  factory CifAssessment.fromJson(Map<String, dynamic> json) {
    return CifAssessment(
      id: _readInt(json['id']) ?? 0,
      patientId: _readInt(json['paciente_id'] ?? json['patient_id']) ?? 0,
      assessmentDate:
          _readDate(json['data_avaliacao'] ?? json['assessment_date']) ??
          DateTime.now(),
      status: _readString(json['status']),
      catalogVersion: _readString(
        json['catalogo_versao'] ?? json['catalog_version'],
      ),
      rulesVersion: _readString(json['regras_versao'] ?? json['rules_version']),
      responses: _readMap(json['respostas'] ?? json['responses']),
      results: _readNullableMap(json['resultados'] ?? json['results']),
      createdAt: _readDateTime(json['criado_em'] ?? json['created_at']),
      updatedAt: _readDateTime(json['atualizado_em'] ?? json['updated_at']),
      completedAt: _readDateTime(json['concluido_em'] ?? json['completed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'paciente_id': patientId,
    'data_avaliacao': _dateOnly(assessmentDate),
    'status': status,
    'catalogo_versao': catalogVersion,
    'regras_versao': rulesVersion,
    'respostas': Map<String, dynamic>.from(responses),
    'resultados': results,
    'criado_em': createdAt?.toIso8601String(),
    'atualizado_em': updatedAt?.toIso8601String(),
    'concluido_em': completedAt?.toIso8601String(),
  };

  int get pacienteId => patientId;
  DateTime get dataAvaliacao => assessmentDate;
  Map<String, dynamic> get respostas => responses;
  Map<String, dynamic>? get resultados => results;
  CifSummary? get summary =>
      results == null ? null : CifSummary.fromAssessment(this);
  CifSummary? get resumo => summary;
  bool get isDraft => status == 'rascunho';
  bool get isCompleted => status == 'concluida';
}

/// Item leve devolvido pela consulta do histórico de avaliações.
///
/// O histórico não depende das respostas nem dos resultados completos. Datas
/// são opcionais para que um registro antigo ou malformado não derrube a
/// listagem. A referência de reavaliação só é derivada quando o backend
/// identifica explicitamente a avaliação como inicial; este cliente não
/// escolhe uma avaliação inicial por posição ou por data.
class CifAssessmentHistoryEntry {
  final int id;
  final int patientId;
  final DateTime? assessmentDate;
  final String status;
  final String catalogVersion;
  final String rulesVersion;
  final bool completed;
  final bool resultsAvailable;
  final bool? isInitial;
  final DateTime? reassessmentReferenceDate;

  const CifAssessmentHistoryEntry({
    required this.id,
    required this.patientId,
    required this.assessmentDate,
    required this.status,
    required this.catalogVersion,
    required this.rulesVersion,
    required this.completed,
    required this.resultsAvailable,
    required this.isInitial,
    required this.reassessmentReferenceDate,
  });

  factory CifAssessmentHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawCompletedAt =
        json['concluido_em'] ?? json['completed_at'] ?? json['completedAt'];
    final completedAt = _readDateTime(rawCompletedAt);
    final status = _readString(json['status']);
    final explicitCompleted = _readNullableBool(
      json['concluida'] ??
          json['completed'] ??
          json['is_completed'] ??
          json['isCompleted'],
    );
    final completed =
        explicitCompleted ??
        (completedAt != null || _isCompletedStatus(status));
    final rawResults =
        json['resultados'] ?? json['results'] ?? json['resultado'];
    final explicitResultsAvailable = _readNullableBool(
      json['resultados_disponiveis'] ??
          json['results_available'] ??
          json['has_results'] ??
          json['hasResults'],
    );
    final resultsAvailable = explicitResultsAvailable ?? rawResults != null;
    final assessmentDate = _readDate(
      json['data_avaliacao'] ?? json['assessment_date'] ?? json['date'],
    );
    final isInitial = _readNullableBool(
      json['avaliacao_inicial'] ??
          json['is_initial'] ??
          json['initial'] ??
          json['isInitial'],
    );
    final explicitReference = _readDate(
      json['data_reavaliacao_referencia'] ??
          json['data_reavaliacao'] ??
          json['reassessment_reference_date'] ??
          json['reassessment_date'] ??
          json['reassessment_reference'] ??
          json['reassessmentReferenceDate'],
    );

    return CifAssessmentHistoryEntry(
      id:
          _readInt(
            json['id'] ?? json['avaliacao_id'] ?? json['assessment_id'],
          ) ??
          0,
      patientId:
          _readInt(
            json['paciente_id'] ??
                json['patient_id'] ??
                (json['patient'] is Map
                    ? (json['patient'] as Map)['id']
                    : json['patient']),
          ) ??
          0,
      assessmentDate: assessmentDate,
      status: status,
      catalogVersion: _readString(
        json['catalogo_versao'] ?? json['catalog_version'],
      ),
      rulesVersion: _readString(json['regras_versao'] ?? json['rules_version']),
      completed: completed,
      resultsAvailable: resultsAvailable,
      isInitial: isInitial,
      reassessmentReferenceDate:
          explicitReference ??
          (isInitial == true && assessmentDate != null
              ? _addCalendarMonths(assessmentDate, 3)
              : null),
    );
  }

  factory CifAssessmentHistoryEntry.fromAssessment(CifAssessment assessment) {
    return CifAssessmentHistoryEntry(
      id: assessment.id,
      patientId: assessment.patientId,
      assessmentDate: assessment.assessmentDate,
      status: assessment.status,
      catalogVersion: assessment.catalogVersion,
      rulesVersion: assessment.rulesVersion,
      completed: assessment.isCompleted,
      resultsAvailable: assessment.results != null,
      isInitial: null,
      reassessmentReferenceDate: null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'paciente_id': patientId,
    'data_avaliacao': assessmentDate == null
        ? null
        : _dateOnly(assessmentDate!),
    'status': status,
    'catalogo_versao': catalogVersion,
    'regras_versao': rulesVersion,
    'concluida': completed,
    'resultados_disponiveis': resultsAvailable,
    if (isInitial != null) 'avaliacao_inicial': isInitial,
    if (reassessmentReferenceDate != null)
      'data_reavaliacao_referencia': _dateOnly(reassessmentReferenceDate!),
  };

  bool get isDraft => !completed;
  bool get isCompleted => completed;
  int get avaliacaoId => id;
  int get pacienteId => patientId;
  DateTime? get dataAvaliacao => assessmentDate;
  String get catalogoVersao => catalogVersion;
  String get regrasVersao => rulesVersion;
  bool get resultadosDisponiveis => resultsAvailable;
  DateTime? get dataReferenciaReavaliacao => reassessmentReferenceDate;
}

typedef CifHistoryEntry = CifAssessmentHistoryEntry;
typedef CifEvaluationHistoryEntry = CifAssessmentHistoryEntry;
typedef CIFEntradaHistorico = CifAssessmentHistoryEntry;

class CifValidationIssue {
  final String code;
  final String message;
  final String? field;
  final dynamic value;

  const CifValidationIssue({
    required this.code,
    required this.message,
    this.field,
    this.value,
  });

  factory CifValidationIssue.fromJson(Map<String, dynamic> json) {
    return CifValidationIssue(
      code: _readString(json['codigo'] ?? json['code']),
      message: _readString(json['mensagem'] ?? json['message']),
      field: _readNullableString(json['campo'] ?? json['field']),
      value: json.containsKey('valor') ? json['valor'] : json['value'],
    );
  }

  Map<String, dynamic> toJson() => {
    'codigo': code,
    'mensagem': message,
    if (field != null) 'campo': field,
    if (value != null) 'valor': value,
  };

  String get codigo => code;
  String get mensagem => message;
  String? get campo => field;
}

class CifPartialResult {
  final String code;
  final String area;
  final String field;
  final double? value;
  final double? exactValue;
  final bool pending;
  final String? name;

  const CifPartialResult({
    required this.code,
    required this.area,
    required this.field,
    required this.value,
    required this.exactValue,
    required this.pending,
    this.name,
  });

  factory CifPartialResult.fromJson(Map<String, dynamic> json) {
    return CifPartialResult(
      code: _readString(json['codigo'] ?? json['code']),
      area: _readString(json['area']),
      field: _readString(json['campo'] ?? json['field']),
      value: _readDouble(json['valor'] ?? json['value']),
      exactValue: _readDouble(json['valor_interno'] ?? json['exact_value']),
      pending: _readBool(json['pendente'] ?? json['pending']),
      name: _readNullableString(json['nome'] ?? json['name']),
    );
  }

  Map<String, dynamic> toJson() => {
    'codigo': code,
    'area': area,
    'campo': field,
    'valor': value,
    'valor_interno': exactValue,
    'pendente': pending,
    if (name != null) 'nome': name,
  };

  String get codigo => code;
  String get campo => field;
  double? get valor => value;
  bool get pendente => pending;
}

class CifPreviewResult {
  final String status;
  final bool definitive;
  final String? sex;
  final Map<String, CifPartialResult> chapters;
  final Map<String, CifPartialResult> areas;
  final Map<String, CifPartialResult> intermediates;
  final List<CifValidationIssue> pendingIssues;
  final List<CifValidationIssue> errors;
  final Map<String, dynamic> audit;

  const CifPreviewResult({
    required this.status,
    required this.definitive,
    required this.sex,
    required this.chapters,
    required this.areas,
    required this.intermediates,
    required this.pendingIssues,
    required this.errors,
    required this.audit,
  });

  factory CifPreviewResult.fromJson(Map<String, dynamic> json) {
    return CifPreviewResult(
      status: _readString(json['status']),
      definitive: _readBool(json['definitivo'] ?? json['definitive']),
      sex: _readNullableString(json['sexo'] ?? json['sex']),
      chapters: _readPartialResults(json['capitulos'] ?? json['chapters']),
      areas: _readPartialResults(json['areas'] ?? json['area_results']),
      intermediates: _readPartialResults(
        json['intermediarios'] ?? json['intermediates'],
      ),
      pendingIssues: _readIssues(json['pendencias'] ?? json['pending']),
      errors: _readIssues(json['erros'] ?? json['errors']),
      audit: _readMap(json['auditoria'] ?? json['audit']),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'definitivo': definitive,
    'sexo': sex,
    'capitulos': chapters.map((key, value) => MapEntry(key, value.toJson())),
    'areas': areas.map((key, value) => MapEntry(key, value.toJson())),
    'intermediarios': intermediates.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'pendencias': pendingIssues.map((issue) => issue.toJson()).toList(),
    'erros': errors.map((issue) => issue.toJson()).toList(),
    'auditoria': audit,
  };

  bool get definitivo => definitive;
  String? get sexo => sex;
  Map<String, CifPartialResult> get capitulos => chapters;
  Map<String, CifPartialResult> get areasPorResultado => areas;
  List<CifValidationIssue> get pendencias => pendingIssues;
  List<CifValidationIssue> get erros => errors;
}

class CifPreview {
  final int assessmentId;
  final int patientId;
  final String catalogVersion;
  final String rulesVersion;
  final String status;
  final bool definitive;
  final CifPreviewResult result;

  const CifPreview({
    required this.assessmentId,
    required this.patientId,
    required this.catalogVersion,
    required this.rulesVersion,
    required this.status,
    required this.definitive,
    required this.result,
  });

  factory CifPreview.fromJson(Map<String, dynamic> json) {
    return CifPreview(
      assessmentId:
          _readInt(json['avaliacao_id'] ?? json['assessment_id']) ?? 0,
      patientId: _readInt(json['paciente_id'] ?? json['patient_id']) ?? 0,
      catalogVersion: _readString(
        json['catalogo_versao'] ?? json['catalog_version'],
      ),
      rulesVersion: _readString(json['regras_versao'] ?? json['rules_version']),
      status: _readString(json['status']),
      definitive: _readBool(json['definitivo'] ?? json['definitive']),
      result: CifPreviewResult.fromJson(
        _readMap(json['resultado'] ?? json['result']),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'avaliacao_id': assessmentId,
    'paciente_id': patientId,
    'catalogo_versao': catalogVersion,
    'regras_versao': rulesVersion,
    'status': status,
    'definitivo': definitive,
    'resultado': result.toJson(),
  };

  bool get definitivo => definitive;
  List<CifValidationIssue> get pendencias => result.pendingIssues;
  List<CifValidationIssue> get erros => result.errors;
}

/// Resultado de um capítulo devolvido pelo backend.
///
/// [sourceField] é a célula/campo que originou o resultado (por exemplo,
/// ``b:E8``). O cliente não interpreta esse campo nem recalcula [value].
class CifChapterResult {
  final String code;
  final double? value;
  final bool pending;
  final String sourceField;

  const CifChapterResult({
    required this.code,
    required this.value,
    required this.pending,
    required this.sourceField,
  });

  factory CifChapterResult.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCode,
  }) {
    return CifChapterResult(
      code: _readString(json['codigo'] ?? json['code'] ?? fallbackCode),
      value: _readDouble(json['valor'] ?? json['value']),
      pending: _readBool(json['pendente'] ?? json['pending']),
      sourceField: _readString(
        json['campo'] ??
            json['origem'] ??
            json['source_field'] ??
            json['sourceField'] ??
            json['field'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'codigo': code,
    'valor': value,
    'pendente': pending,
    'campo': sourceField,
  };

  String get codigo => code;
  double? get valor => value;
  bool get pendente => pending;
  String get campoOrigem => sourceField;
  String get origem => sourceField;
  String get campo => sourceField;
  String get field => sourceField;
}

/// Resultado de uma área devolvido pelo backend.
class CifAreaResult {
  final String code;
  final String name;
  final double? value;
  final bool pending;
  final String sourceField;

  const CifAreaResult({
    required this.code,
    required this.name,
    required this.value,
    required this.pending,
    required this.sourceField,
  });

  factory CifAreaResult.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCode,
  }) {
    return CifAreaResult(
      code: _readString(json['codigo'] ?? json['code'] ?? fallbackCode),
      name: _readString(json['nome'] ?? json['name']),
      value: _readDouble(json['valor'] ?? json['value']),
      pending: _readBool(json['pendente'] ?? json['pending']),
      sourceField: _readString(
        json['campo'] ??
            json['origem'] ??
            json['source_field'] ??
            json['sourceField'] ??
            json['field'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'codigo': code,
    'nome': name,
    'valor': value,
    'pendente': pending,
    'campo': sourceField,
  };

  String get codigo => code;
  String get nome => name;
  double? get valor => value;
  bool get pendente => pending;
  String get campoOrigem => sourceField;
  String get campo => sourceField;
}

/// Quadro resumo da avaliação CIF produzido pelo backend.
///
/// As coleções mantêm a ordem do JSON recebido. Nenhum item é criado,
/// removido, arredondado ou calculado no Dart.
class CifSummary {
  final int assessmentId;
  final int patientId;
  final DateTime assessmentDate;
  final String status;
  final String catalogVersion;
  final String rulesVersion;
  final bool definitive;
  final String? resultStatus;
  final Map<String, dynamic> responses;
  final Map<String, CifChapterResult> chapters;
  final Map<String, CifAreaResult> areas;
  final double? generalResult;

  const CifSummary({
    required this.assessmentId,
    required this.patientId,
    required this.assessmentDate,
    required this.status,
    required this.catalogVersion,
    required this.rulesVersion,
    required this.definitive,
    required this.resultStatus,
    required this.responses,
    required this.chapters,
    required this.areas,
    required this.generalResult,
  });

  /// Aceita a resposta completa de ``GET /cif-avaliacoes/{id}``.
  factory CifSummary.fromJson(Map<String, dynamic> json) {
    final rawResult =
        json['resultados'] ?? json['results'] ?? json['resultado'];
    final result = rawResult is Map
        ? Map<String, dynamic>.from(rawResult)
        : json;
    final rawChapters =
        result['capitulos'] ?? result['chapters'] ?? result['chapter_results'];
    final rawAreas = result['areas'] ?? result['area_results'];

    return CifSummary(
      assessmentId:
          _readInt(
            json['avaliacao_id'] ?? json['assessment_id'] ?? json['id'],
          ) ??
          0,
      patientId: _readInt(json['paciente_id'] ?? json['patient_id']) ?? 0,
      assessmentDate:
          _readDate(json['data_avaliacao'] ?? json['assessment_date']) ??
          DateTime.now(),
      status: _readString(json['status']),
      catalogVersion: _readString(
        json['catalogo_versao'] ?? json['catalog_version'],
      ),
      rulesVersion: _readString(json['regras_versao'] ?? json['rules_version']),
      definitive: _readBool(
        result['definitivo'] ?? result['definitive'] ?? json['definitivo'],
      ),
      resultStatus: _readNullableString(
        result['status'] ?? result['result_status'],
      ),
      responses: _readMap(json['respostas'] ?? json['responses']),
      chapters: _readChapterResults(rawChapters),
      areas: _readAreaResults(rawAreas),
      generalResult: _readDouble(
        result.containsKey('resultado_geral')
            ? result['resultado_geral']
            : result.containsKey('general_result')
            ? result['general_result']
            : result.containsKey('resultadoGeral')
            ? result['resultadoGeral']
            : null,
      ),
    );
  }

  factory CifSummary.fromAssessment(CifAssessment assessment) {
    return CifSummary.fromJson({
      'id': assessment.id,
      'paciente_id': assessment.patientId,
      'data_avaliacao': _dateOnly(assessment.assessmentDate),
      'status': assessment.status,
      'catalogo_versao': assessment.catalogVersion,
      'regras_versao': assessment.rulesVersion,
      'respostas': assessment.responses,
      'resultados': assessment.results,
    });
  }

  Map<String, dynamic> toJson() => {
    'avaliacao_id': assessmentId,
    'paciente_id': patientId,
    'data_avaliacao': _dateOnly(assessmentDate),
    'status': status,
    'catalogo_versao': catalogVersion,
    'regras_versao': rulesVersion,
    'definitivo': definitive,
    'resultado_status': resultStatus,
    'respostas': Map<String, dynamic>.from(responses),
    'capitulos': chapters.map((key, value) => MapEntry(key, value.toJson())),
    'areas': areas.map((key, value) => MapEntry(key, value.toJson())),
    'resultado_geral': generalResult,
  };

  int get avaliacaoId => assessmentId;
  int get pacienteId => patientId;
  DateTime get dataAvaliacao => assessmentDate;
  String get catalogoVersao => catalogVersion;
  String get regrasVersao => rulesVersion;
  bool get definitivo => definitive;
  Map<String, dynamic> get respostasOriginais => responses;
  Map<String, CifChapterResult> get capitulos => chapters;
  Map<String, CifAreaResult> get areasPorResultado => areas;
  Map<String, CifChapterResult> get chapterResults => chapters;
  Map<String, CifAreaResult> get areaResults => areas;
  double? get resultadoGeral => generalResult;
}

/// Comparação de um capítulo sem transformar valores em interpretação clínica.
///
/// [difference] é sempre ``segunda avaliação - primeira avaliação``. Quando
/// um valor está ausente, nulo ou marcado como pendente, a diferença também é
/// nula; zero continua sendo um valor válido.
class CifComparisonChapter {
  final String code;
  final double? firstValue;
  final double? secondValue;
  final double? difference;
  final bool firstPending;
  final bool secondPending;
  final bool firstMissing;
  final bool secondMissing;

  const CifComparisonChapter({
    required this.code,
    required this.firstValue,
    required this.secondValue,
    required this.difference,
    required this.firstPending,
    required this.secondPending,
    required this.firstMissing,
    required this.secondMissing,
  });

  bool get hasPendingOrMissing =>
      firstPending || secondPending || firstMissing || secondMissing;
  String get codigo => code;
  double? get valorPrimeira => firstValue;
  double? get valorSegunda => secondValue;
  double? get diferenca => difference;
}

/// Comparação de uma área correspondente entre duas avaliações.
class CifComparisonArea {
  final String code;
  final String name;
  final double? firstValue;
  final double? secondValue;
  final double? difference;
  final bool firstPending;
  final bool secondPending;
  final bool firstMissing;
  final bool secondMissing;

  const CifComparisonArea({
    required this.code,
    required this.name,
    required this.firstValue,
    required this.secondValue,
    required this.difference,
    required this.firstPending,
    required this.secondPending,
    required this.firstMissing,
    required this.secondMissing,
  });

  bool get hasPendingOrMissing =>
      firstPending || secondPending || firstMissing || secondMissing;
  String get codigo => code;
  String get nome => name;
  double? get valorPrimeira => firstValue;
  double? get valorSegunda => secondValue;
  double? get diferenca => difference;
}

/// Resultado tipado da comparação entre dois resumos fornecidos pelo backend.
///
/// A união dos códigos apenas alinha itens já retornados nos dois resumos; o
/// cliente não recalcula capítulos, áreas ou qualificadores.
class CifComparisonResult {
  final int patientId;
  final int firstAssessmentId;
  final int secondAssessmentId;
  final DateTime? firstAssessmentDate;
  final DateTime? secondAssessmentDate;
  final String firstCatalogVersion;
  final String secondCatalogVersion;
  final String firstRulesVersion;
  final String secondRulesVersion;
  final bool patientCompatible;
  final bool versionsCompatible;
  final Map<String, CifComparisonChapter> chapters;
  final Map<String, CifComparisonArea> areas;

  const CifComparisonResult({
    required this.patientId,
    required this.firstAssessmentId,
    required this.secondAssessmentId,
    required this.firstAssessmentDate,
    required this.secondAssessmentDate,
    required this.firstCatalogVersion,
    required this.secondCatalogVersion,
    required this.firstRulesVersion,
    required this.secondRulesVersion,
    required this.patientCompatible,
    required this.versionsCompatible,
    required this.chapters,
    required this.areas,
  });

  factory CifComparisonResult.fromSummaries(
    CifSummary first,
    CifSummary second,
  ) {
    final patientCompatible = first.patientId == second.patientId;
    final versionsCompatible =
        first.catalogVersion.isNotEmpty &&
        second.catalogVersion.isNotEmpty &&
        first.rulesVersion.isNotEmpty &&
        second.rulesVersion.isNotEmpty &&
        first.catalogVersion == second.catalogVersion &&
        first.rulesVersion == second.rulesVersion;

    final chapterCodes = <String>{
      ...first.chapters.keys,
      ...second.chapters.keys,
    };
    final chapters = <String, CifComparisonChapter>{};
    for (final code in chapterCodes) {
      final firstItem = first.chapters[code];
      final secondItem = second.chapters[code];
      chapters[code] = _buildChapterComparison(
        code,
        firstItem,
        secondItem,
        allowDifference: patientCompatible && versionsCompatible,
      );
    }

    final areaCodes = <String>{...first.areas.keys, ...second.areas.keys};
    final areas = <String, CifComparisonArea>{};
    for (final code in areaCodes) {
      final firstItem = first.areas[code];
      final secondItem = second.areas[code];
      final name = firstItem?.name.isNotEmpty == true
          ? firstItem!.name
          : secondItem?.name ?? '';
      areas[code] = _buildAreaComparison(
        code,
        name,
        firstItem,
        secondItem,
        allowDifference: patientCompatible && versionsCompatible,
      );
    }

    return CifComparisonResult(
      patientId: first.patientId,
      firstAssessmentId: first.assessmentId,
      secondAssessmentId: second.assessmentId,
      firstAssessmentDate: first.assessmentDate,
      secondAssessmentDate: second.assessmentDate,
      firstCatalogVersion: first.catalogVersion,
      secondCatalogVersion: second.catalogVersion,
      firstRulesVersion: first.rulesVersion,
      secondRulesVersion: second.rulesVersion,
      patientCompatible: patientCompatible,
      versionsCompatible: versionsCompatible,
      chapters: Map.unmodifiable(chapters),
      areas: Map.unmodifiable(areas),
    );
  }

  bool get canCompare => patientCompatible && versionsCompatible;
  bool get pacientesCompativeis => patientCompatible;
  bool get versoesCompativeis => versionsCompatible;
  Map<String, CifComparisonChapter> get capitulos => chapters;
  Map<String, CifComparisonArea> get areasPorResultado => areas;
  String get versionMismatchMessage {
    final differences = <String>[];
    if (firstCatalogVersion != secondCatalogVersion) {
      differences.add('catálogo: $firstCatalogVersion × $secondCatalogVersion');
    } else if (firstCatalogVersion.isEmpty) {
      differences.add('catálogo não informado');
    }
    if (firstRulesVersion != secondRulesVersion) {
      differences.add('regras: $firstRulesVersion × $secondRulesVersion');
    } else if (firstRulesVersion.isEmpty) {
      differences.add('regras não informadas');
    }
    return differences.join('; ');
  }
}

typedef CifComparison = CifComparisonResult;
typedef CifChapterComparison = CifComparisonChapter;
typedef CifAreaComparison = CifComparisonArea;
typedef CIFComparacao = CifComparisonResult;

CifComparisonChapter _buildChapterComparison(
  String code,
  CifChapterResult? first,
  CifChapterResult? second, {
  required bool allowDifference,
}) {
  final firstMissing = first == null || first.value == null;
  final secondMissing = second == null || second.value == null;
  double? difference;
  if (allowDifference &&
      first != null &&
      second != null &&
      first.value != null &&
      second.value != null &&
      !first.pending &&
      !second.pending) {
    difference = second.value! - first.value!;
  }
  return CifComparisonChapter(
    code: code,
    firstValue: first?.value,
    secondValue: second?.value,
    difference: difference,
    firstPending: first?.pending ?? false,
    secondPending: second?.pending ?? false,
    firstMissing: firstMissing,
    secondMissing: secondMissing,
  );
}

CifComparisonArea _buildAreaComparison(
  String code,
  String name,
  CifAreaResult? first,
  CifAreaResult? second, {
  required bool allowDifference,
}) {
  final firstMissing = first == null || first.value == null;
  final secondMissing = second == null || second.value == null;
  double? difference;
  if (allowDifference &&
      first != null &&
      second != null &&
      first.value != null &&
      second.value != null &&
      !first.pending &&
      !second.pending) {
    difference = second.value! - first.value!;
  }
  return CifComparisonArea(
    code: code,
    name: name,
    firstValue: first?.value,
    secondValue: second?.value,
    difference: difference,
    firstPending: first?.pending ?? false,
    secondPending: second?.pending ?? false,
    firstMissing: firstMissing,
    secondMissing: secondMissing,
  );
}

class CifApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? payload;
  final CifPreviewResult? result;

  const CifApiException({
    required this.message,
    this.statusCode,
    this.payload,
    this.result,
  });

  List<CifValidationIssue> get pendingIssues =>
      result?.pendingIssues ?? const [];
  List<CifValidationIssue> get errors => result?.errors ?? const [];

  @override
  String toString() => message;
}

class CifNetworkException implements Exception {
  final String message;
  final Object? cause;

  const CifNetworkException(this.message, {this.cause});

  @override
  String toString() => message;
}

typedef CIFFormulario = CifForm;
typedef CIFCampo = CifField;
typedef CIFEscala = CifScale;
typedef CIFAvaliacao = CifAssessment;
typedef CifDraft = CifAssessment;
typedef CIFRascunho = CifAssessment;
typedef CIFPrevia = CifPreview;
typedef CIFResumo = CifSummary;
typedef CifResumo = CifSummary;
typedef CIFResultadoCapitulo = CifChapterResult;
typedef CifCapituloResultado = CifChapterResult;
typedef CifChapterSummary = CifChapterResult;
typedef CIFResultadoArea = CifAreaResult;
typedef CifAreaResultado = CifAreaResult;
typedef CifAreaSummary = CifAreaResult;
typedef CIFProblemaValidacao = CifValidationIssue;
typedef CifPending = CifValidationIssue;
typedef CifError = CifValidationIssue;

String _readString(dynamic value) => value?.toString() ?? '';

String? _readNullableString(dynamic value) => value?.toString();

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _readDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}

bool? _readNullableBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'sim') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'nao') {
    return false;
  }
  return null;
}

List<int> _readIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map(_readInt).whereType<int>().toList(growable: false);
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic>? _readNullableMap(dynamic value) {
  if (value == null) return null;
  return _readMap(value);
}

DateTime? _readDate(dynamic value) {
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value == null || value.toString().isEmpty) return null;
  return DateTime.tryParse(value.toString());
}

DateTime? _readDateTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return null;
  return DateTime.tryParse(value.toString());
}

bool _isCompletedStatus(String status) {
  final normalized = status
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i');
  return normalized == 'concluida' ||
      normalized == 'completa' ||
      normalized == 'completed';
}

DateTime _addCalendarMonths(DateTime value, int months) {
  final monthIndex = value.year * 12 + (value.month - 1) + months;
  final year = monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = value.day > lastDay ? lastDay : value.day;
  return DateTime(year, month, day);
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

List<CifValidationIssue> _readIssues(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (issue) =>
            CifValidationIssue.fromJson(Map<String, dynamic>.from(issue)),
      )
      .toList(growable: false);
}

Map<String, CifPartialResult> _readPartialResults(dynamic value) {
  if (value is! Map) return const {};
  return value.map(
    (key, item) => MapEntry(
      key.toString(),
      CifPartialResult.fromJson(
        item is Map ? Map<String, dynamic>.from(item) : const {},
      ),
    ),
  );
}

Map<String, CifChapterResult> _readChapterResults(dynamic value) {
  if (value is! Map) return const {};
  return Map.unmodifiable(
    value.map(
      (key, item) => MapEntry(
        key.toString(),
        CifChapterResult.fromJson(
          item is Map ? Map<String, dynamic>.from(item) : const {},
          fallbackCode: key.toString(),
        ),
      ),
    ),
  );
}

Map<String, CifAreaResult> _readAreaResults(dynamic value) {
  if (value is! Map) return const {};
  return Map.unmodifiable(
    value.map(
      (key, item) => MapEntry(
        key.toString(),
        CifAreaResult.fromJson(
          item is Map ? Map<String, dynamic>.from(item) : const {},
          fallbackCode: key.toString(),
        ),
      ),
    ),
  );
}
