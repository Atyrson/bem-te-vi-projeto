import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:projeto/Core/Config/api_config.dart';
import 'package:projeto/Core/Models/cifModels.dart';

/// Interface usada pelo provider para manter o fluxo testável sem HTTP real.
abstract class CifServiceBase {
  Future<CifForm> carregarFormulario(String sexo);

  Future<CifAssessment> criarRascunho({
    required int patientId,
    required DateTime assessmentDate,
    required Map<String, dynamic> responses,
  });

  Future<CifAssessment> consultarRascunho({
    required int patientId,
    required int assessmentId,
  });

  Future<CifAssessment> atualizarRascunho({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
    DateTime? assessmentDate,
  });

  Future<CifPreview> solicitarPrevia({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
  });

  Future<CifAssessment> concluirAvaliacao({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
  });
}

/// Cliente HTTP exclusivamente das rotas de avaliação CIF.
class CifService implements CifServiceBase {
  final http.Client _client;

  CifService({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<CifForm> carregarFormulario(String sexo) async {
    final url = ApiConfig.endpoint(
      'cif/formulario',
    ).replace(queryParameters: {'sexo': sexo});
    final response = await _get(url);
    return CifForm.fromJson(response);
  }

  @override
  Future<CifAssessment> criarRascunho({
    required int patientId,
    required DateTime assessmentDate,
    required Map<String, dynamic> responses,
  }) async {
    final response = await _sendJson(
      method: 'POST',
      url: ApiConfig.endpoint('patients/$patientId/cif-avaliacoes'),
      body: {
        'data_avaliacao': _dateOnly(assessmentDate),
        'respostas': responses,
      },
      expectedStatusCodes: {201},
    );
    return CifAssessment.fromJson(response);
  }

  @override
  Future<CifAssessment> consultarRascunho({
    required int patientId,
    required int assessmentId,
  }) async {
    final response = await _get(
      ApiConfig.endpoint('patients/$patientId/cif-avaliacoes/$assessmentId'),
    );
    return CifAssessment.fromJson(response);
  }

  @override
  Future<CifAssessment> atualizarRascunho({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
    DateTime? assessmentDate,
  }) async {
    final body = <String, dynamic>{'respostas': responses};
    if (assessmentDate != null) {
      body['data_avaliacao'] = _dateOnly(assessmentDate);
    }
    final response = await _sendJson(
      method: 'PATCH',
      url: ApiConfig.endpoint(
        'patients/$patientId/cif-avaliacoes/$assessmentId',
      ),
      body: body,
      expectedStatusCodes: {200},
    );
    return CifAssessment.fromJson(response);
  }

  @override
  Future<CifPreview> solicitarPrevia({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
  }) async {
    final response = await _sendJson(
      method: 'POST',
      url: ApiConfig.endpoint(
        'patients/$patientId/cif-avaliacoes/$assessmentId/previa',
      ),
      body: {'respostas': responses},
      expectedStatusCodes: {200},
    );
    return CifPreview.fromJson(response);
  }

  @override
  Future<CifAssessment> concluirAvaliacao({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
  }) async {
    final response = await _sendJson(
      method: 'POST',
      url: ApiConfig.endpoint(
        'patients/$patientId/cif-avaliacoes/$assessmentId/concluir',
      ),
      body: {'respostas': responses},
      expectedStatusCodes: {200},
    );
    return CifAssessment.fromJson(response);
  }

  // Aliases com nomes em inglês facilitam o uso do serviço em integrações
  // futuras sem criar um segundo cliente HTTP.
  Future<CifForm> loadForm(String sex) => carregarFormulario(sex);

  Future<CifAssessment> createDraft({
    required int patientId,
    required DateTime assessmentDate,
    required Map<String, dynamic> responses,
  }) => criarRascunho(
    patientId: patientId,
    assessmentDate: assessmentDate,
    responses: responses,
  );

  Future<CifAssessment> getAssessment({
    required int patientId,
    required int assessmentId,
  }) => consultarRascunho(patientId: patientId, assessmentId: assessmentId);

  Future<CifAssessment> updateDraft({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
    DateTime? assessmentDate,
  }) => atualizarRascunho(
    patientId: patientId,
    assessmentId: assessmentId,
    responses: responses,
    assessmentDate: assessmentDate,
  );

  Future<CifPreview> requestPreview({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
  }) => solicitarPrevia(
    patientId: patientId,
    assessmentId: assessmentId,
    responses: responses,
  );

  Future<CifAssessment> completeAssessment({
    required int patientId,
    required int assessmentId,
    required Map<String, dynamic> responses,
  }) => concluirAvaliacao(
    patientId: patientId,
    assessmentId: assessmentId,
    responses: responses,
  );

  Future<Map<String, dynamic>> _get(Uri url) async {
    try {
      final response = await _client.get(url, headers: _headers);
      return _decodeResponse(response, expectedStatusCodes: {200});
    } on CifApiException {
      rethrow;
    } catch (error) {
      throw CifNetworkException(
        'Não foi possível conectar ao servidor da CIF.',
        cause: error,
      );
    }
  }

  Future<Map<String, dynamic>> _sendJson({
    required String method,
    required Uri url,
    required Map<String, dynamic> body,
    required Set<int> expectedStatusCodes,
  }) async {
    try {
      final encodedBody = jsonEncode(body);
      final response = method == 'PATCH'
          ? await _client.patch(url, headers: _headers, body: encodedBody)
          : await _client.post(url, headers: _headers, body: encodedBody);
      return _decodeResponse(
        response,
        expectedStatusCodes: expectedStatusCodes,
      );
    } on CifApiException {
      rethrow;
    } catch (error) {
      throw CifNetworkException(
        'Não foi possível conectar ao servidor da CIF.',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required Set<int> expectedStatusCodes,
  }) {
    final decoded = _tryDecode(response.bodyBytes);
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw _apiException(response.statusCode, decoded);
    }
    if (decoded is! Map) {
      throw const CifApiException(
        message: 'A resposta do servidor da CIF está em formato inválido.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  CifApiException _apiException(int statusCode, dynamic decoded) {
    final payload = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final detail = payload['detail'];
    String message = 'O servidor recusou a operação da avaliação CIF.';
    Map<String, dynamic>? resultJson;
    if (detail is String && detail.trim().isNotEmpty) {
      message = detail;
    } else if (detail is Map) {
      final detailMap = Map<String, dynamic>.from(detail);
      final detailMessage = detailMap['message'];
      if (detailMessage is String && detailMessage.trim().isNotEmpty) {
        message = detailMessage;
      }
      if (detailMap['resultado'] is Map) {
        resultJson = Map<String, dynamic>.from(detailMap['resultado'] as Map);
      }
    }
    return CifApiException(
      statusCode: statusCode,
      message: message,
      payload: payload,
      result: resultJson == null ? null : CifPreviewResult.fromJson(resultJson),
    );
  }

  dynamic _tryDecode(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  static const _headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

typedef CIFService = CifService;
typedef CIFServiceBase = CifServiceBase;
