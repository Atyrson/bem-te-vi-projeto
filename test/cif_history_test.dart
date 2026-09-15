import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifHistoryProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/Screens/cifHistory.dart';

import 'cif_test_support.dart';

CifAssessmentHistoryEntry historyEntry({
  int id = 1,
  int patientId = 1,
  String status = 'rascunho',
  bool? completed,
  bool resultsAvailable = false,
  DateTime? date,
}) {
  return CifAssessmentHistoryEntry(
    id: id,
    patientId: patientId,
    assessmentDate: date ?? DateTime(2026, 9, id),
    status: status,
    catalogVersion: 'test-catalog',
    rulesVersion: 'test-rules',
    completed: completed ?? status == 'concluida',
    resultsAvailable: resultsAvailable,
    isInitial: null,
    reassessmentReferenceDate: null,
  );
}

void main() {
  test('desserializa uma entrada do histórico concluída com resultados', () {
    final entry = CifAssessmentHistoryEntry.fromJson({
      'id': 21,
      'paciente_id': 4,
      'data_avaliacao': '2026-01-31',
      'status': 'concluida',
      'catalogo_versao': 'catalog-1',
      'regras_versao': 'rules-1',
      'resultados': {'definitivo': true},
      'concluido_em': '2026-01-31T12:00:00Z',
    });

    expect(entry.id, 21);
    expect(entry.patientId, 4);
    expect(entry.assessmentDate, DateTime(2026, 1, 31));
    expect(entry.isCompleted, isTrue);
    expect(entry.resultsAvailable, isTrue);
    expect(entry.catalogVersion, 'catalog-1');
  });

  test('datas ausentes ou inválidas não quebram o histórico', () {
    final invalid = CifAssessmentHistoryEntry.fromJson({
      'id': 1,
      'paciente_id': 1,
      'data_avaliacao': 'data-inválida',
      'status': 'rascunho',
    });
    final initial = CifAssessmentHistoryEntry.fromJson({
      'id': 2,
      'paciente_id': 1,
      'data_avaliacao': '2026-01-31',
      'status': 'concluida',
      'avaliacao_inicial': true,
    });

    expect(invalid.assessmentDate, isNull);
    expect(invalid.reassessmentReferenceDate, isNull);
    expect(initial.reassessmentReferenceDate, DateTime(2026, 4, 30));
  });

  test('lista vazia, múltiplas avaliações e isolamento por paciente', () async {
    final service = FakeCifService();
    final provider = CifHistoryProvider(service: service);
    addTearDown(provider.dispose);

    await provider.load(patientId: 1);
    expect(provider.entries, isEmpty);

    service.historyEntries = [
      historyEntry(id: 1),
      historyEntry(id: 2, status: 'concluida', resultsAvailable: true),
      historyEntry(id: 3, patientId: 2),
    ];
    await provider.load(patientId: 1);

    expect(provider.entries.map((entry) => entry.id), [1, 2]);
    expect(provider.entries.every((entry) => entry.patientId == 1), isTrue);
  });

  test('erro de rede e retry do histórico', () async {
    final service = FakeCifService()..failHistory = true;
    final provider = CifHistoryProvider(service: service);
    addTearDown(provider.dispose);

    await expectLater(
      provider.load(patientId: 1),
      throwsA(isA<CifNetworkException>()),
    );
    expect(provider.errorMessage, 'falha no histórico');
    service.failHistory = false;
    service.historyEntries = [historyEntry(id: 8)];
    await provider.retry();

    expect(provider.entries.single.id, 8);
    expect(service.historyCalls, 2);
  });

  test('nova avaliação cria registro vazio sem apagar as anteriores', () async {
    final service = FakeCifService();
    final provider = CifHistoryProvider(service: service);
    addTearDown(provider.dispose);
    service.historyEntries = [historyEntry(id: 1)];
    await provider.load(patientId: 1);

    final created = await provider.createNewAssessment(
      patientId: 1,
      assessmentDate: DateTime(2026, 10, 5),
    );

    expect(created.id, 8);
    expect(created.responses, isEmpty);
    expect(created.assessmentDate, DateTime(2026, 10, 5));
    expect(provider.entries.map((entry) => entry.id), [8, 1]);
    expect(service.createCalls, 1);
  });

  testWidgets('rascunho abre formulário e concluída abre resumo', (
    tester,
  ) async {
    final service = FakeCifService()
      ..historyEntries = [
        historyEntry(id: 1),
        historyEntry(id: 2, status: 'concluida', resultsAvailable: true),
      ];
    final history = CifHistoryProvider(service: service);
    final patient = PatientProvider()
      ..setPatient({'id': 1, 'nome_completo': 'Paciente', 'sexo': 'Feminino'});
    addTearDown(history.dispose);
    addTearDown(patient.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: patient),
          ChangeNotifierProvider.value(value: history),
        ],
        child: MaterialApp(
          home: const CifHistoryScreen(),
          routes: {
            '/cif_form': (_) => const Scaffold(body: Text('FORM CIF')),
            '/cif_summary': (_) => const Scaffold(body: Text('RESUMO CIF')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Avaliação #1'), findsOneWidget);
    expect(find.text('Avaliação #2'), findsOneWidget);
    expect(find.text('Avaliação #3'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cif-history-open-draft-1')));
    await tester.pumpAndSettle();
    expect(find.text('FORM CIF'), findsOneWidget);
    Navigator.of(tester.element(find.text('FORM CIF'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cif-history-open-summary-2')));
    await tester.pumpAndSettle();
    expect(find.text('RESUMO CIF'), findsOneWidget);
  });

  testWidgets('seleciona duas concluídas para comparação', (tester) async {
    final service = FakeCifService()
      ..historyEntries = [
        historyEntry(id: 1, status: 'concluida', resultsAvailable: true),
        historyEntry(id: 2, status: 'concluida', resultsAvailable: true),
      ];
    final history = CifHistoryProvider(service: service);
    final patient = PatientProvider()
      ..setPatient({'id': 1, 'nome_completo': 'Paciente', 'sexo': 'Feminino'});
    addTearDown(history.dispose);
    addTearDown(patient.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: patient),
          ChangeNotifierProvider.value(value: history),
        ],
        child: const MaterialApp(home: CifHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cif-history-select-1')));
    await tester.tap(find.byKey(const ValueKey('cif-history-select-2')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('cif-history-compare-action')),
      findsOneWidget,
    );
  });
}
