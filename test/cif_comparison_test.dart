import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifComparisonProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/Screens/cifComparison.dart';

import 'cif_test_support.dart';

CifAssessment comparisonAssessment({
  required int id,
  int patientId = 1,
  String catalogVersion = 'test-catalog',
  String rulesVersion = 'test-rules',
  required Map<String, dynamic> chapters,
  required Map<String, dynamic> areas,
}) {
  return fakeAssessment(
    id: id,
    patientId: patientId,
    status: 'concluida',
    catalogVersion: catalogVersion,
    rulesVersion: rulesVersion,
    results: {'definitivo': true, 'capitulos': chapters, 'areas': areas},
  );
}

Map<String, dynamic> chapter(
  String code,
  Object? value, {
  bool pending = false,
}) => {
  'codigo': code,
  'valor': value,
  'pendente': pending,
  'campo': '$code:E1',
};

Map<String, dynamic> area(String code, Object? value, {bool pending = false}) =>
    {
      'codigo': code,
      'nome': 'Área $code',
      'valor': value,
      'pendente': pending,
      'campo': '$code:E1',
    };

void main() {
  test('compara capítulos e áreas preservando zero e pendências', () {
    final first = comparisonAssessment(
      id: 1,
      chapters: {
        'b1': chapter('b1', 0),
        'b2': chapter('b2', 4),
        'b3': chapter('b3', null, pending: true),
      },
      areas: {'b': area('b', 0)},
    );
    final second = comparisonAssessment(
      id: 2,
      chapters: {
        'b1': chapter('b1', 2),
        'b2': chapter('b2', 0),
        'b3': chapter('b3', 1),
      },
      areas: {'b': area('b', 3)},
    );

    final result = CifComparisonResult.fromSummaries(
      CifSummary.fromAssessment(first),
      CifSummary.fromAssessment(second),
    );

    expect(result.canCompare, isTrue);
    expect(result.chapters['b1']!.firstValue, 0);
    expect(result.chapters['b1']!.difference, 2);
    expect(result.chapters['b2']!.difference, -4);
    expect(result.chapters['b3']!.firstMissing, isTrue);
    expect(result.chapters['b3']!.difference, isNull);
    expect(result.areas['b']!.difference, 3);
  });

  test('sinaliza versões incompatíveis sem permitir comparação automática', () {
    final first = comparisonAssessment(
      id: 1,
      catalogVersion: 'catalog-a',
      rulesVersion: 'rules-a',
      chapters: {'b1': chapter('b1', 1)},
      areas: {'b': area('b', 1)},
    );
    final second = comparisonAssessment(
      id: 2,
      catalogVersion: 'catalog-b',
      rulesVersion: 'rules-a',
      chapters: {'b1': chapter('b1', 2)},
      areas: {'b': area('b', 2)},
    );

    final result = CifComparisonResult.fromSummaries(
      CifSummary.fromAssessment(first),
      CifSummary.fromAssessment(second),
    );

    expect(result.versionsCompatible, isFalse);
    expect(result.canCompare, isFalse);
    expect(result.versionMismatchMessage, contains('catalog-a'));
    expect(result.versionMismatchMessage, contains('catalog-b'));
    expect(result.chapters['b1']!.difference, isNull);
  });

  test(
    'provider seleciona duas avaliações e bloqueia pacientes diferentes',
    () async {
      final service = FakeCifService();
      service.assessmentsToConsult.addAll({
        1: comparisonAssessment(
          id: 1,
          chapters: {'b1': chapter('b1', 0)},
          areas: {'b': area('b', 0)},
        ),
        2: comparisonAssessment(
          id: 2,
          chapters: {'b1': chapter('b1', 4)},
          areas: {'b': area('b', 4)},
        ),
      });
      final provider = CifComparisonProvider(service: service);
      addTearDown(provider.dispose);

      final comparison = await provider.compare(
        patientId: 1,
        firstAssessmentId: 1,
        secondAssessmentId: 2,
      );
      expect(comparison!.firstAssessmentId, 1);
      expect(comparison.secondAssessmentId, 2);
      expect(comparison.chapters['b1']!.difference, 4);

      service.assessmentsToConsult[2] = comparisonAssessment(
        id: 2,
        patientId: 2,
        chapters: {'b1': chapter('b1', 4)},
        areas: {'b': area('b', 4)},
      );
      await expectLater(
        provider.compare(
          patientId: 1,
          firstAssessmentId: 1,
          secondAssessmentId: 2,
        ),
        throwsA(isA<CifApiException>()),
      );
      expect(provider.errorMessage, contains('não correspondem'));
    },
  );

  test('provider expõe erro de rede e permite retry', () async {
    final service = FakeCifService()..failConsult = true;
    final provider = CifComparisonProvider(service: service);
    addTearDown(provider.dispose);

    await expectLater(
      provider.compare(
        patientId: 1,
        firstAssessmentId: 1,
        secondAssessmentId: 2,
      ),
      throwsA(isA<CifNetworkException>()),
    );
    expect(provider.errorMessage, 'falha ao consultar');
  });

  testWidgets('exibe apenas valores e diferenças numéricas', (tester) async {
    final service = FakeCifService();
    service.assessmentsToConsult.addAll({
      1: comparisonAssessment(
        id: 1,
        chapters: {'b1': chapter('b1', 0)},
        areas: {'b': area('b', 1)},
      ),
      2: comparisonAssessment(
        id: 2,
        chapters: {'b1': chapter('b1', 2)},
        areas: {'b': area('b', 3)},
      ),
    });
    final comparisonProvider = CifComparisonProvider(service: service);
    final patientProvider = PatientProvider()
      ..setPatient({'id': 1, 'nome_completo': 'Paciente', 'sexo': 'Feminino'});
    addTearDown(comparisonProvider.dispose);
    addTearDown(patientProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: patientProvider),
          ChangeNotifierProvider.value(value: comparisonProvider),
        ],
        child: const MaterialApp(
          home: CifComparisonScreen(
            firstAssessmentId: 1,
            secondAssessmentId: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1ª: 0.0'), findsOneWidget);
    expect(find.text('2ª: 2.0'), findsOneWidget);
    expect(find.text('Diferença (2ª − 1ª): 2.0'), findsNWidgets(2));
    expect(find.textContaining('melhor'), findsNothing);
    expect(find.textContaining('pior'), findsNothing);
    expect(find.textContaining('evolu'), findsNothing);
  });
}
