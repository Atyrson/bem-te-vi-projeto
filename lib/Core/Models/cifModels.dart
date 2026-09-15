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
  bool get isDraft => status == 'rascunho';
  bool get isCompleted => status == 'concluida';
}

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
