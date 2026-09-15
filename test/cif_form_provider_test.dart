import 'package:flutter_test/flutter_test.dart';
import 'package:projeto/Core/Providers/cifFormProvider.dart';

import 'cif_test_support.dart';

void main() {
  late FakeCifService service;
  late CifFormProvider provider;

  setUp(() {
    service = FakeCifService();
    provider = CifFormProvider(service: service);
  });

  tearDown(() => provider.dispose());

  Future<void> load({int patientId = 1, String sex = 'Feminino'}) {
    return provider.initialize(
      patientId: patientId,
      patientName: 'Paciente',
      sex: sex,
    );
  }

  test(
    'distingue resposta zero de campo sem resposta e calcula progresso',
    () async {
      await load();
      expect(provider.answerFor('f:E1'), isNull);
      expect(provider.answeredCount, 0);
      provider.setAnswer('f:E1', 0);
      expect(provider.answerFor('f:E1'), 0);
      expect(provider.answeredCount, 1);
      expect(provider.progress, 0.5);
    },
  );

  test('bloqueia sexo ausente ou inválido antes da API', () async {
    await provider.initialize(patientId: 1, patientName: 'Paciente', sex: null);
    expect(provider.errorMessage, contains('sexo'));
    expect(service.formCalls, 0);

    await provider.initialize(
      patientId: 1,
      patientName: 'Paciente',
      sex: 'Outro',
    );
    expect(provider.errorMessage, contains('exatamente'));
    expect(service.formCalls, 0);
  });

  test('preserva resposta local quando salvar falha', () async {
    await load();
    provider.setAnswer('f:E1', 0);
    service.failSave = true;
    await expectLater(provider.saveDraft(), throwsA(isA<Exception>()));
    expect(provider.answerFor('f:E1'), 0);
    expect(provider.hasUnsavedChanges, isTrue);
  });

  test('remove incompatibilidades explicitamente com null no PATCH', () async {
    service.assessmentToConsult = fakeAssessment(
      id: 44,
      responses: {'f:E1': 0},
    );
    await provider.initialize(
      patientId: 1,
      patientName: 'Paciente',
      sex: 'Feminino',
      assessmentId: 44,
    );
    await provider.initialize(
      patientId: 1,
      patientName: 'Paciente',
      sex: 'Masculino',
      assessmentId: 44,
    );
    expect(provider.hasIncompatibleResponses, isTrue);
    await provider.removeIncompatibleResponses();
    expect(service.updatePatches.single['f:E1'], isNull);
    expect(provider.hasIncompatibleResponses, isFalse);
  });

  test('cria somente um rascunho para prévias concorrentes', () async {
    await load();
    provider.setAnswer('f:E1', 0);
    service.previewDelay = const Duration(milliseconds: 5);
    await Future.wait([provider.requestPreview(), provider.requestPreview()]);
    expect(service.createCalls, 1);
    expect(service.previewCalls, 2);
    expect(provider.preview, isNotNull);
  });

  test('retoma rascunho e atualiza por PATCH', () async {
    service.assessmentToConsult = fakeAssessment(
      id: 44,
      responses: {'f:E1': 0},
    );
    await provider.initialize(
      patientId: 1,
      patientName: 'Paciente',
      sex: 'Feminino',
      assessmentId: 44,
    );
    expect(provider.assessmentId, 44);
    expect(provider.answerFor('f:E1'), 0);
    provider.setAnswer('f:E2', 4);
    await provider.saveDraft();
    expect(service.updateCalls, 1);
    expect(service.updatePatches.single['f:E2'], 4);
  });

  test(
    'trocar paciente limpa respostas e sexo preserva chaves incompatíveis',
    () async {
      await load(patientId: 1);
      provider.setAnswer('f:E1', 0);
      await load(patientId: 2);
      expect(provider.responses, isEmpty);

      await load(patientId: 1);
      provider.setAnswer('f:E1', 0);
      await load(patientId: 1, sex: 'Masculino');
      expect(provider.answerFor('f:E1'), 0);
      expect(provider.hasIncompatibleResponses, isTrue);
      final result = await provider.concludeAssessment();
      expect(result, isNull);
      expect(service.concludeCalls, 0);
    },
  );

  test(
    'ignora uma segunda conclusão enquanto a primeira está em andamento',
    () async {
      await load();
      provider.setAnswer('f:E1', 0);
      final first = provider.concludeAssessment();
      final second = provider.concludeAssessment();
      await Future.wait([first, second]);
      expect(service.concludeCalls, 1);
    },
  );
}
