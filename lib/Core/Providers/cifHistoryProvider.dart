import 'package:flutter/foundation.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Services/cif_service.dart';

/// Estado do histórico CIF do paciente selecionado.
class CifHistoryProvider extends ChangeNotifier {
  final CifServiceBase service;

  List<CifAssessmentHistoryEntry> _entries = const [];
  int? _patientId;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isCreating = false;
  int _requestNumber = 0;
  Future<List<CifAssessmentHistoryEntry>>? _loadingFuture;
  Future<void> Function()? _retryAction;

  CifHistoryProvider({CifServiceBase? service})
    : service = service ?? CifService();

  List<CifAssessmentHistoryEntry> get entries => _entries;
  List<CifAssessmentHistoryEntry> get avaliacoes => _entries;
  int? get patientId => _patientId;
  String? get errorMessage => _errorMessage;
  String? get erro => _errorMessage;
  bool get isLoading => _isLoading;
  bool get carregando => _isLoading;
  bool get isCreating => _isCreating;
  bool get criando => _isCreating;
  bool get hasError => _errorMessage != null;

  Future<List<CifAssessmentHistoryEntry>> load({required int? patientId}) {
    if (_patientId == patientId && _isLoading && _loadingFuture != null) {
      return _loadingFuture!;
    }

    _patientId = patientId;
    final requestNumber = ++_requestNumber;
    _entries = const [];
    _errorMessage = null;
    _isLoading = true;
    _retryAction = () async {
      await load(patientId: patientId);
    };
    notifyListeners();

    final future = _load(patientId: patientId, requestNumber: requestNumber);
    _loadingFuture = future;
    return future;
  }

  Future<List<CifAssessmentHistoryEntry>> carregar({required int? patientId}) =>
      load(patientId: patientId);

  Future<void> retry() async {
    final action = _retryAction;
    if (action != null) await action();
  }

  Future<void> tentarNovamente() => retry();

  Future<List<CifAssessmentHistoryEntry>> _load({
    required int? patientId,
    required int requestNumber,
  }) async {
    try {
      if (patientId == null) {
        throw const CifApiException(
          message: 'Selecione um paciente antes de abrir o histórico CIF.',
        );
      }
      final loaded = await service.listarHistorico(patientId: patientId);
      if (requestNumber != _requestNumber || _patientId != patientId) {
        return const [];
      }

      // Mesmo que um servidor ou fake malformado devolva itens de outra
      // pessoa, eles nunca chegam à tela. O ID da rota continua sendo a
      // autoridade do contexto selecionado.
      _entries = List.unmodifiable(
        loaded.where((entry) => entry.patientId == patientId),
      );
      _errorMessage = null;
      notifyListeners();
      return _entries;
    } catch (error) {
      if (requestNumber == _requestNumber) {
        _errorMessage = _messageFor(error);
        notifyListeners();
      }
      rethrow;
    } finally {
      if (requestNumber == _requestNumber) {
        _isLoading = false;
        _loadingFuture = null;
        notifyListeners();
      }
    }
  }

  /// Cria uma avaliação vazia, preservando todos os registros anteriores.
  Future<CifAssessment> createNewAssessment({
    required int? patientId,
    DateTime? assessmentDate,
  }) async {
    if (_isCreating) {
      throw const CifApiException(
        message: 'Já existe uma nova avaliação CIF em criação.',
      );
    }
    if (patientId == null) {
      throw const CifApiException(
        message: 'Selecione um paciente antes de criar uma avaliação CIF.',
      );
    }
    if (_patientId != null && _patientId != patientId) {
      throw const CifApiException(
        message: 'O paciente selecionado não corresponde ao histórico CIF.',
      );
    }

    _isCreating = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final created = await service.criarRascunho(
        patientId: patientId,
        assessmentDate: _dateOnly(assessmentDate ?? _today()),
        responses: const {},
      );
      if (created.patientId != patientId) {
        throw const CifApiException(
          message: 'O servidor retornou uma avaliação de outro paciente.',
        );
      }

      if (_patientId == patientId) {
        final item = CifAssessmentHistoryEntry.fromAssessment(created);
        _entries = List.unmodifiable(<CifAssessmentHistoryEntry>[
          item,
          ..._entries,
        ]);
        notifyListeners();
      }
      return created;
    } catch (error) {
      _errorMessage = _messageFor(error);
      notifyListeners();
      rethrow;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<CifAssessment> novaAvaliacao({
    required int? patientId,
    DateTime? assessmentDate,
  }) =>
      createNewAssessment(patientId: patientId, assessmentDate: assessmentDate);

  String _messageFor(Object error) {
    if (error is CifApiException) return error.message;
    if (error is CifNetworkException) return error.message;
    if (error is UnsupportedError) {
      return 'O serviço atual não oferece o histórico de avaliações CIF.';
    }
    return 'Não foi possível carregar o histórico de avaliações CIF.';
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

typedef CIFHistoryProvider = CifHistoryProvider;
