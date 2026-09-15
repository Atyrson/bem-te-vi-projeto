import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:projeto/Core/Services/cif_service.dart';

import 'cif_test_support.dart';

class RecordingClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final path = request.url.path;
    dynamic body;
    if (request is http.Request && request.body.isNotEmpty) {
      body = jsonDecode(request.body);
    }
    if (request.method == 'GET' && path.endsWith('/cif/formulario')) {
      return _response(fakeForm('Feminino').toJson());
    }
    if (request.method == 'GET') {
      return _response(fakeAssessment(id: 9).toJson());
    }
    if (path.endsWith('/previa')) {
      return _response({
        'avaliacao_id': 9,
        'paciente_id': 1,
        'catalogo_versao': 'test-catalog',
        'regras_versao': 'test-rules',
        'status': 'pendente',
        'definitivo': false,
        'resultado': {
          'status': 'pendente',
          'definitivo': false,
          'pendencias': [],
          'erros': [],
        },
      });
    }
    final response = fakeAssessment(
      id: 9,
      patientId: 1,
      status: path.endsWith('/concluir') ? 'concluida' : 'rascunho',
      responses: body is Map && body['respostas'] is Map
          ? Map<String, dynamic>.from(body['respostas'] as Map)
          : const {},
    );
    return _response(
      response.toJson(),
      status: request.method == 'POST' && path.endsWith('/cif-avaliacoes')
          ? 201
          : 200,
    );
  }

  http.StreamedResponse _response(
    Map<String, dynamic> body, {
    int status = 200,
  }) {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  test(
    'usa as seis rotas CIF, query por sexo e preserva null no PATCH',
    () async {
      final client = RecordingClient();
      final service = CifService(client: client);

      await service.carregarFormulario('Feminino');
      await service.criarRascunho(
        patientId: 1,
        assessmentDate: DateTime(2026, 9, 15),
        responses: const {},
      );
      await service.consultarRascunho(patientId: 1, assessmentId: 9);
      await service.atualizarRascunho(
        patientId: 1,
        assessmentId: 9,
        responses: {'b:E1': null, 'b:E2': 0},
      );
      await service.solicitarPrevia(
        patientId: 1,
        assessmentId: 9,
        responses: const {},
      );
      await service.concluirAvaliacao(
        patientId: 1,
        assessmentId: 9,
        responses: const {},
      );

      expect(client.requests, hasLength(6));
      expect(client.requests[0].url.queryParameters['sexo'], 'Feminino');
      expect(
        client.requests[1].url.path,
        endsWith('/patients/1/cif-avaliacoes'),
      );
      expect(client.requests[3].method, 'PATCH');
      final patchBody = jsonDecode((client.requests[3] as http.Request).body);
      expect(patchBody['respostas']['b:E1'], isNull);
      expect(patchBody['respostas']['b:E2'], 0);
      expect(client.requests[4].url.path, endsWith('/previa'));
      expect(client.requests[5].url.path, endsWith('/concluir'));
    },
  );
}
