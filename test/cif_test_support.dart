import 'dart:async';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Services/cif_service.dart';

CifForm fakeForm(String sex) {
  final prefix = sex == 'Feminino' ? 'f' : 'm';
  return CifForm(
    catalogVersion: 'test-catalog',
    rulesVersion: 'test-rules',
    sex: sex,
    totalFields: 2,
    scale: const CifScale(
      allowedValues: [0, 1, 2, 3, 4],
      allowsUnansweredInDraft: true,
      requiredOnConclusion: true,
    ),
    fields: [
      CifField(
        order: 2,
        key: '$prefix:E2',
        code: 'b1100',
        originalCode: 'b1100',
        description: 'Descrição do segundo campo',
        areaCode: 'b',
        areaDescription: 'FUNÇÕES DO CORPO',
        chapterCode: 'b1',
        chapterDescription: 'FUNÇÕES MENTAIS',
        requiredOnConclusion: true,
      ),
      CifField(
        order: 1,
        key: '$prefix:E1',
        code: 'b1100',
        originalCode: 'b1100',
        description: 'Descrição do primeiro campo',
        areaCode: 'b',
        areaDescription: 'FUNÇÕES DO CORPO',
        chapterCode: 'b1',
        chapterDescription: 'FUNÇÕES MENTAIS',
        requiredOnConclusion: true,
      ),
    ],
  );
}

CifAssessment fakeAssessment({
  int id = 7,
  int patientId = 1,
  String status = 'rascunho',
  Map<String, dynamic> responses = const {},
  DateTime? date,
}) {
  return CifAssessment(
    id: id,
    patientId: patientId,
    assessmentDate: date ?? DateTime(2026, 9, 15),
    status: status,
    catalogVersion: 'test-catalog',
    rulesVersion: 'test-rules',
    responses: Map<String, dynamic>.from(responses),
    results: null,
    createdAt: null,
    updatedAt: null,
    completedAt: status == 'concluida' ? DateTime(2026, 9, 15) : null,
  );
}

class FakeCifService implements CifServiceBase {
  int formCalls = 0;
  int createCalls = 0;
  int consultCalls = 0;
  int updateCalls = 0;
  int previewCalls = 0;
  int concludeCalls = 0;
  bool failForm = false;
  bool failSave = false;
  bool failPreview = false;
  bool failConclusion = false;
  Duration previewDelay = Duration.zero;
  final List<Map<String, dynamic>> updatePatches = [];
  CifAssessment assessmentToConsult = fakeAssessment(
    id: 7,
    responses: {'f:E1': 0},
  );
  int _nextId = 7;

  @override
  Future<CifForm> carregarFormulario(String sexo) async {
    formCalls++;
    if (failForm) throw const CifNetworkException('falha de formulário');
    return fakeForm(sexo);
  }

  @override
  Future<CifAssessment> criarRascunho({
    required int patientId,
    required DateTime assessmentDate,
    required Map<String, dynamic> responses,
  }) async {
    createCalls++;
    if (failSave) throw const CifNetworkException('falha ao salvar');
    _nextId++;
    return fakeAssessment(
      id: _nextId,
      patientId: patientId,
      responses: _withoutNulls(responses),
      date: assessmentDate,
    );
  }

  @override
  Future<CifAssessment> consultarRascunho({
    required int patientId,
    required int assessmentId,
  }) async {
    consultCalls++;
    return assessmentToConsult;
  }

  @override
  Future<CifAssessment> atualizarRascunho({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
    DateTime? assessmentDate,
  }) async {
    updateCalls++;
    updatePatches.add(Map<String, dynamic>.from(responses));
    if (failSave) throw const CifNetworkException('falha ao atualizar');
    final merged = Map<String, dynamic>.from(assessmentToConsult.responses);
    for (final entry in responses.entries) {
      if (entry.value == null) {
        merged.remove(entry.key);
      } else {
        merged[entry.key] = entry.value;
      }
    }
    return fakeAssessment(
      id: assessmentId,
      patientId: patientId,
      responses: merged,
      date: assessmentDate,
    );
  }

  @override
  Future<CifPreview> solicitarPrevia({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
  }) async {
    previewCalls++;
    if (previewDelay != Duration.zero) await Future<void>.delayed(previewDelay);
    if (failPreview) throw const CifNetworkException('falha na prévia');
    final result = CifPreviewResult(
      status: 'pendente',
      definitive: false,
      sex: 'Feminino',
      chapters: const {},
      areas: const {},
      intermediates: const {},
      pendingIssues: const [],
      errors: const [],
      audit: const {},
    );
    return CifPreview(
      assessmentId: assessmentId,
      patientId: patientId,
      catalogVersion: 'test-catalog',
      rulesVersion: 'test-rules',
      status: 'pendente',
      definitive: false,
      result: result,
    );
  }

  @override
  Future<CifAssessment> concluirAvaliacao({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
  }) async {
    concludeCalls++;
    if (failConclusion) throw const CifNetworkException('falha na conclusão');
    return fakeAssessment(
      id: assessmentId,
      patientId: patientId,
      status: 'concluida',
      responses: _withoutNulls(responses),
    );
  }

  Map<String, dynamic> _withoutNulls(Map<String, dynamic> value) {
    return Map<String, dynamic>.from(value)
      ..removeWhere((key, item) => item == null);
  }
}
