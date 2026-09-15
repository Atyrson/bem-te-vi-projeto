import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifFormProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/Screens/cifSummary.dart';

import 'cif_test_support.dart';

Map<String, dynamic> summaryResults({
  bool definitive = true,
  Object? generalResult,
  bool includeGeneralResult = false,
}) {
  final chapterCodes = [
    ...List.generate(8, (index) => 'b${index + 1}'),
    ...List.generate(8, (index) => 's${index + 1}'),
    ...List.generate(9, (index) => 'd${index + 1}'),
    ...List.generate(5, (index) => 'e${index + 1}'),
  ];
  final chapters = <String, dynamic>{};
  for (var index = 0; index < chapterCodes.length; index++) {
    final code = chapterCodes[index];
    chapters[code] = {
      'codigo': code,
      'valor': index == 1 ? null : 0.0,
      'pendente': index == 1,
      'campo': '$code:E${index + 1}',
    };
  }
  final areas = <String, dynamic>{
    'b': {
      'codigo': 'b',
      'nome': 'Funções do corpo',
      'valor': 0.0,
      'pendente': false,
      'campo': 'b:E4',
    },
    's': {
      'codigo': 's',
      'nome': 'Estruturas do corpo',
      'valor': 0.0,
      'pendente': false,
      'campo': 's:E3',
    },
    'd': {
      'codigo': 'd',
      'nome': 'Atividades e participação',
      'valor': 0.0,
      'pendente': false,
      'campo': 'd:E2',
    },
    'e': {
      'codigo': 'e',
      'nome': 'Fatores ambientais',
      'valor': 0.0,
      'pendente': false,
      'campo': 'e:E2',
    },
  };
  return {
    'status': definitive ? 'completa' : 'pendente',
    'definitivo': definitive,
    'capitulos': chapters,
    'areas': areas,
    if (includeGeneralResult) 'resultado_geral': generalResult,
  };
}

CifAssessment completedAssessment({
  int patientId = 1,
  int id = 7,
  String catalogVersion = 'test-catalog',
  String rulesVersion = 'test-rules',
  Object? generalResult,
  bool includeGeneralResult = false,
}) {
  return fakeAssessment(
    id: id,
    patientId: patientId,
    status: 'concluida',
    responses: const {'f:E1': 0},
    catalogVersion: catalogVersion,
    rulesVersion: rulesVersion,
    results: summaryResults(
      generalResult: generalResult,
      includeGeneralResult: includeGeneralResult,
    ),
  );
}

void main() {
  test('desserializa os 30 capítulos, 4 áreas, zero e pendência', () {
    final summary = CifSummary.fromAssessment(completedAssessment());

    expect(summary.chapters, hasLength(30));
    expect(summary.areas, hasLength(4));
    expect(summary.chapters['b1']!.value, 0.0);
    expect(summary.chapters['b1']!.pending, isFalse);
    expect(summary.chapters['b1']!.sourceField, 'b1:E1');
    expect(summary.chapters['b2']!.value, isNull);
    expect(summary.chapters['b2']!.pending, isTrue);
    expect(summary.generalResult, isNull);
  });

  test('não carrega resumo para avaliação não concluída', () async {
    final service = FakeCifService()
      ..assessmentToConsult = fakeAssessment(id: 7, status: 'rascunho');
    final provider = CifFormProvider(service: service);
    addTearDown(provider.dispose);

    await expectLater(
      provider.loadSummary(patientId: 1, assessmentId: 7),
      throwsA(isA<CifApiException>()),
    );
    expect(provider.summary, isNull);
    expect(provider.summaryError, contains('conclusão'));
  });

  test('preserva respostas locais em erro de rede do resumo', () async {
    final service = FakeCifService();
    final provider = CifFormProvider(service: service);
    addTearDown(provider.dispose);
    await provider.initialize(
      patientId: 1,
      patientName: 'Paciente',
      sex: 'Feminino',
    );
    provider.setAnswer('f:E1', 0);
    service.failConsult = true;

    await expectLater(
      provider.loadSummary(patientId: 1, assessmentId: 7),
      throwsA(isA<CifNetworkException>()),
    );
    expect(provider.answerFor('f:E1'), 0);
    expect(provider.summaryError, 'falha ao consultar');
  });

  test('bloqueia paciente incorreto e versão incompatível', () async {
    final patientService = FakeCifService()
      ..assessmentToConsult = completedAssessment(patientId: 2);
    final patientProvider = CifFormProvider(service: patientService);
    addTearDown(patientProvider.dispose);
    await expectLater(
      patientProvider.loadSummary(patientId: 1, assessmentId: 7),
      throwsA(isA<CifApiException>()),
    );
    expect(patientProvider.summaryError, contains('não correspondem'));

    final versionService = FakeCifService()
      ..assessmentToConsult = completedAssessment(catalogVersion: 'old');
    final versionProvider = CifFormProvider(service: versionService);
    addTearDown(versionProvider.dispose);
    await versionProvider.initialize(
      patientId: 1,
      patientName: 'Paciente',
      sex: 'Feminino',
    );
    await expectLater(
      versionProvider.loadSummary(
        patientId: 1,
        assessmentId: 7,
        sex: 'Feminino',
      ),
      throwsA(isA<CifApiException>()),
    );
    expect(versionProvider.summaryError, contains('versão'));
  });

  testWidgets(
    'exibe áreas, capítulos, pendências e respostas somente leitura',
    (tester) async {
      final service = FakeCifService()
        ..assessmentToConsult = completedAssessment();
      final cifProvider = CifFormProvider(service: service);
      final patientProvider = PatientProvider()
        ..setPatient({
          'id': 1,
          'nome_completo': 'Maria da Silva',
          'cpf': '000.000.000-00',
          'sexo': 'Feminino',
        });
      addTearDown(cifProvider.dispose);
      addTearDown(patientProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: patientProvider),
            ChangeNotifierProvider.value(value: cifProvider),
          ],
          child: const MaterialApp(home: CifSummaryScreen(assessmentId: 7)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maria da Silva'), findsOneWidget);
      expect(find.text('Funções do corpo'), findsOneWidget);
      await tester.tap(find.text('Consultar respostas originais'));
      await tester.pumpAndSettle();
      expect(
        find.text('Respostas originais (somente leitura)'),
        findsOneWidget,
      );
      expect(find.text('f:E1'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Capítulos (30)'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Capítulos (30)'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
      expect(find.text('b1'), findsOneWidget);
      expect(find.text('Resultado geral'), findsNothing);
    },
  );
}
