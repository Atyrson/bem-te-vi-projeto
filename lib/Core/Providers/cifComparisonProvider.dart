import 'package:flutter/foundation.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Services/cif_service.dart';

/// Carrega dois resumos concluídos e alinha apenas os resultados recebidos.
class CifComparisonProvider extends ChangeNotifier {
  final CifServiceBase service;

  CifComparisonResult? _comparison;
  String? _errorMessage;
  bool _isLoading = false;
  int _requestNumber = 0;
  String? _requestKey;
  Future<CifComparisonResult?>? _comparisonFuture;
  Future<void> Function()? _retryAction;

  CifComparisonProvider({CifServiceBase? service})
    : service = service ?? CifService();

  CifComparisonResult? get comparison => _comparison;
  CifComparisonResult? get resultado => _comparison;
  String? get errorMessage => _errorMessage;
  String? get erro => _errorMessage;
  bool get isLoading => _isLoading;
  bool get carregando => _isLoading;

  Future<CifComparisonResult?> compare({
    required int? patientId,
    required int? firstAssessmentId,
    required int? secondAssessmentId,
  }) {
    final key = '$patientId|$firstAssessmentId|$secondAssessmentId';
    if (_requestKey == key && _isLoading && _comparisonFuture != null) {
      return _comparisonFuture!;
    }

    _requestKey = key;
    final requestNumber = ++_requestNumber;
    _comparison = null;
    _errorMessage = null;
    _isLoading = true;
    _retryAction = () async {
      await compare(
        patientId: patientId,
        firstAssessmentId: firstAssessmentId,
        secondAssessmentId: secondAssessmentId,
      );
    };
    notifyListeners();

    final future = _compare(
      patientId: patientId,
      firstAssessmentId: firstAssessmentId,
      secondAssessmentId: secondAssessmentId,
      requestNumber: requestNumber,
    );
    _comparisonFuture = future;
    return future;
  }

  Future<CifComparisonResult?> comparar({
    required int? patientId,
    required int? firstAssessmentId,
    required int? secondAssessmentId,
  }) => compare(
    patientId: patientId,
    firstAssessmentId: firstAssessmentId,
    secondAssessmentId: secondAssessmentId,
  );

  Future<void> retry() async {
    final action = _retryAction;
    if (action != null) await action();
  }

  Future<void> tentarNovamente() => retry();

  Future<CifComparisonResult?> _compare({
    required int? patientId,
    required int? firstAssessmentId,
    required int? secondAssessmentId,
    required int requestNumber,
  }) async {
    try {
      if (patientId == null) {
        throw const CifApiException(
          message: 'Selecione um paciente antes de comparar avaliações CIF.',
        );
      }
      if (firstAssessmentId == null || secondAssessmentId == null) {
        throw const CifApiException(
          message: 'Selecione duas avaliações concluídas para comparar.',
        );
      }
      if (firstAssessmentId == secondAssessmentId) {
        throw const CifApiException(
          message: 'Selecione duas avaliações diferentes para comparar.',
        );
      }

      final assessments = await Future.wait([
        service.consultarResumo(
          patientId: patientId,
          assessmentId: firstAssessmentId,
        ),
        service.consultarResumo(
          patientId: patientId,
          assessmentId: secondAssessmentId,
        ),
      ]);
      final firstAssessment = assessments[0];
      final secondAssessment = assessments[1];
      _validateAssessment(
        firstAssessment,
        patientId: patientId,
        assessmentId: firstAssessmentId,
      );
      _validateAssessment(
        secondAssessment,
        patientId: patientId,
        assessmentId: secondAssessmentId,
      );

      final comparison = CifComparisonResult.fromSummaries(
        CifSummary.fromAssessment(firstAssessment),
        CifSummary.fromAssessment(secondAssessment),
      );
      if (!comparison.patientCompatible) {
        throw const CifApiException(
          message:
              'Não é permitido comparar avaliações de pacientes diferentes.',
        );
      }
      if (!comparison.versionsCompatible) {
        throw CifApiException(
          message:
              'A comparação numérica está bloqueada porque as versões divergem: '
              '${comparison.versionMismatchMessage}.',
        );
      }
      if (requestNumber == _requestNumber) {
        _comparison = comparison;
        _errorMessage = null;
        notifyListeners();
      }
      return comparison;
    } catch (error) {
      if (requestNumber == _requestNumber) {
        _errorMessage = _messageFor(error);
        notifyListeners();
      }
      rethrow;
    } finally {
      if (requestNumber == _requestNumber) {
        _isLoading = false;
        _comparisonFuture = null;
        notifyListeners();
      }
    }
  }

  void _validateAssessment(
    CifAssessment assessment, {
    required int patientId,
    required int assessmentId,
  }) {
    if (assessment.id != assessmentId || assessment.patientId != patientId) {
      throw const CifApiException(
        message:
            'O paciente ou a avaliação retornados não correspondem à seleção.',
      );
    }
    if (!assessment.isCompleted) {
      throw const CifApiException(
        message: 'A comparação exige duas avaliações concluídas.',
      );
    }
    if (assessment.results == null) {
      throw const CifApiException(
        message: 'Uma das avaliações não possui resultados disponíveis.',
      );
    }
  }

  String _messageFor(Object error) {
    if (error is CifApiException) return error.message;
    if (error is CifNetworkException) return error.message;
    return 'Não foi possível comparar as avaliações CIF.';
  }
}

typedef CIFComparisonProvider = CifComparisonProvider;
