import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:projeto/Core/Config/api_config.dart';
import 'package:projeto/Core/Models/GoalsModels.dart';
import 'package:projeto/Core/Models/examModels.dart';
import 'package:projeto/Core/Models/resultsModels.dart';

class ApiService {
  Future<void> submitAnamnesis({
    required String patientName,
    String? patientPhone,
    String? patientEmail,
    required DateTime examDate,
    required DateTime birthDate,
    String? comments,
  }) async {
    final url = ApiConfig.endpoint('anamneses');

    final body = {
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientEmail': patientEmail,
      'examDate': examDate.toIso8601String().split('T').first,
      'birthDate': birthDate.toIso8601String().split('T').first,
      'comments': comments,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 201) {
        throw Exception(
          'Falha ao salvar anamnese. Servidor respondeu: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(
        'Não foi possível conectar ao servidor para salvar a anamnese. Detalhe: $e',
      );
    }
  }

  Future<Map<String, dynamic>> submitGasEvaluation({
    required String patientIdentifier,
    DateTime? planningDate,
    DateTime? revaluationDate,
    String? interventionPlan,
    String? iq,
    required List<Goal> goals,
  }) async {
    final url = ApiConfig.endpoint('gas-evaluations');

    final body = {
      'patientIdentifier': patientIdentifier,
      'planningDate': planningDate?.toIso8601String().split('T').first,
      'revaluationDate': revaluationDate?.toIso8601String().split('T').first,
      'interventionPlan': interventionPlan,
      'iq': iq,
      'goals': goals.map((g) => g.toJson()).toList(),
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception(
          'Falha ao enviar avaliação GAS. Servidor respondeu: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(
        'Não foi possível conectar ao servidor para enviar a avaliação GAS.',
      );
    }
  }

  Future<IscnsciResult> submitExam(Exam exam) async {
    final url = ApiConfig.endpoint('exams');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(exam.toJson()),
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        return IscnsciResult.fromJson(jsonDecode(decodedBody));
      } else {
        throw Exception(
          'Falha ao enviar o exame ASIA. Servidor respondeu: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(
        'Não foi possível conectar ao servidor para enviar o exame ASIA.',
      );
    }
  }
}
