import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifFormProvider.dart';
import 'package:projeto/Core/Providers/cifHistoryProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/CommonWidgets/appDrawer.dart';
import 'package:projeto/Presentation/Screens/ananmeseForm.dart';
import 'package:projeto/Presentation/Screens/cifComparison.dart';
import 'package:projeto/Presentation/Screens/cifForm.dart';
import 'package:projeto/Presentation/Screens/cifHistory.dart';
import 'package:projeto/Presentation/Screens/cifSummary.dart';
import 'package:projeto/Presentation/Screens/pacienteSearch.dart';
import 'package:projeto/main.dart';

import 'cif_test_support.dart';

Map<String, WidgetBuilder> _placeholderRoutes() => {
  '/anamnese_form': (_) => const Scaffold(body: Text('ROTA ANAMNESE')),
  '/cif_history': (_) => const Scaffold(body: Text('ROTA CIF')),
  '/asia_form': (_) => const Scaffold(body: Text('ROTA ASIA')),
  '/meem_form': (_) => const Scaffold(body: Text('ROTA MEEM')),
  '/eletro_form': (_) => const Scaffold(body: Text('ROTA ELETRO')),
  '/dex_form': (_) => const Scaffold(body: Text('ROTA DEX')),
  '/gas_form': (_) => const Scaffold(body: Text('ROTA GAS')),
};

PatientProvider _patient(int id, String name) {
  final provider = PatientProvider();
  provider.setPatient({'id': id, 'nome_completo': name, 'sexo': 'Feminino'});
  return provider;
}

CifAssessmentHistoryEntry _historyEntry({
  required int id,
  required int patientId,
  String status = 'rascunho',
  bool resultsAvailable = false,
}) {
  return CifAssessmentHistoryEntry(
    id: id,
    patientId: patientId,
    assessmentDate: DateTime(2026, 9, id),
    status: status,
    catalogVersion: 'test-catalog',
    rulesVersion: 'test-rules',
    completed: status == 'concluida',
    resultsAvailable: resultsAvailable,
    isInitial: null,
    reassessmentReferenceDate: null,
  );
}

Widget _drawerApp(
  PatientProvider patient, {
  Map<String, WidgetBuilder>? routes,
}) {
  return ChangeNotifierProvider.value(
    value: patient,
    child: MaterialApp(
      key: UniqueKey(),
      routes: routes ?? _placeholderRoutes(),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            Builder(
              builder: (context) => IconButton(
                key: const ValueKey('open-app-drawer'),
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: const Text('HOME'),
      ),
    ),
  );
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-app-drawer')));
  await tester.pumpAndSettle();
}

void main() {
  test('PatientProvider preserva o registro selecionado pelo ID', () {
    final provider = PatientProvider();
    addTearDown(provider.dispose);
    final original = <String, dynamic>{
      'id': '12',
      'nome_completo': 'Paciente Original',
      'sexo': 'Feminino',
    };

    provider.setPatient(original);
    original['nome_completo'] = 'Nome alterado fora do provider';

    expect(provider.id, 12);
    expect(provider.nome, 'Paciente Original');
    expect(provider.patientData?['id'], '12');

    provider.setPatient({
      'id': 13,
      'nome_completo': 'Novo Paciente',
      'sexo': 'Masculino',
    });
    expect(provider.id, 13);
    expect(provider.nome, 'Novo Paciente');
  });

  testWidgets('busca seleciona pelo ID e entra pela Anamnese', (tester) async {
    final patient = PatientProvider();
    addTearDown(patient.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: patient,
        child: MaterialApp(
          routes: {
            '/anamnese_form': (_) => const Scaffold(body: Text('ANAMNESE')),
          },
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PatientSearchDialog(
                    loadPatients: () async => [
                      {
                        'id': 21,
                        'nome_completo': 'Paciente Selecionado',
                        'sexo': 'Feminino',
                      },
                    ],
                  ),
                ),
                child: const Text('Buscar'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paciente Selecionado'));
    await tester.pumpAndSettle();

    expect(patient.id, 21);
    expect(find.text('ANAMNESE'), findsOneWidget);
  });

  testWidgets('drawer respeita a sequência e mantém acesso independente', (
    tester,
  ) async {
    final patient = _patient(1, 'Paciente Menu');
    addTearDown(patient.dispose);
    await tester.pumpWidget(_drawerApp(patient));
    await _openDrawer(tester);

    final labels = find.byType(ListTile).evaluate().map((element) {
      final tile = element.widget as ListTile;
      return (tile.title as Text).data;
    }).toList();
    expect(labels, [
      'Anamnese',
      'CIF',
      'ASIA',
      'MEEM',
      'Eletrodiagnóstico',
      'DEX',
      'GAS',
    ]);
    tester.state<ScaffoldState>(find.byType(Scaffold)).closeDrawer();
    await tester.pumpAndSettle();

    final destinations = {
      'app-drawer-anamnese': 'ROTA ANAMNESE',
      'app-drawer-cif': 'ROTA CIF',
      'app-drawer-asia': 'ROTA ASIA',
      'app-drawer-meem': 'ROTA MEEM',
      'app-drawer-eletro': 'ROTA ELETRO',
      'app-drawer-dex': 'ROTA DEX',
      'app-drawer-gas': 'ROTA GAS',
    };
    for (final destination in destinations.entries) {
      await tester.pumpWidget(_drawerApp(patient));
      await _openDrawer(tester);
      await tester.tap(find.byKey(ValueKey(destination.key)));
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
      expect(patient.id, 1);
    }
  });

  testWidgets('drawer informa e não abre CIF sem paciente', (tester) async {
    final patient = PatientProvider();
    addTearDown(patient.dispose);
    await tester.pumpWidget(_drawerApp(patient));
    await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('app-drawer-cif')));
    await tester.pumpAndSettle();

    expect(
      find.text('Selecione um paciente antes de abrir o histórico CIF.'),
      findsOneWidget,
    );
    expect(find.text('ROTA CIF'), findsNothing);
  });

  testWidgets('Anamnese abre o histórico CIF e o histórico avança para ASIA', (
    tester,
  ) async {
    final patient = _patient(1, 'Paciente Fluxo');
    final history = CifHistoryProvider(service: FakeCifService());
    addTearDown(patient.dispose);
    addTearDown(history.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: patient),
          ChangeNotifierProvider.value(value: history),
        ],
        child: MaterialApp(
          routes: {
            '/cif_history': (_) => const Scaffold(body: Text('HISTÓRICO')),
          },
          home: const AnmeneseForm(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir histórico CIF'));
    await tester.tap(find.text('Abrir histórico CIF'));
    await tester.pumpAndSettle();
    expect(find.text('HISTÓRICO'), findsOneWidget);
    Navigator.of(tester.element(find.text('HISTÓRICO'))).pop();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: patient),
          ChangeNotifierProvider.value(value: history),
        ],
        child: MaterialApp(
          routes: {
            '/asia_form': (_) => const Scaffold(body: Text('ASIA SEGUINTE')),
          },
          home: const CifHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cif-history-next-asia-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ASIA SEGUINTE'), findsOneWidget);
  });

  testWidgets('histórico recarrega e remove dados ao trocar de paciente', (
    tester,
  ) async {
    final service = FakeCifService()
      ..historyEntries = [
        _historyEntry(id: 1, patientId: 1),
        _historyEntry(id: 2, patientId: 2),
      ];
    final patient = _patient(1, 'Paciente Um');
    final history = CifHistoryProvider(service: service);
    addTearDown(patient.dispose);
    addTearDown(history.dispose);

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
    expect(find.text('Paciente Um'), findsOneWidget);
    expect(find.text('Avaliação #1'), findsOneWidget);
    expect(find.text('Avaliação #2'), findsNothing);

    patient.setPatient({
      'id': 2,
      'nome_completo': 'Paciente Dois',
      'sexo': 'Feminino',
    });
    await tester.pumpAndSettle();

    expect(find.text('Paciente Dois'), findsOneWidget);
    expect(find.text('Avaliação #1'), findsOneWidget);
    expect(find.text('Avaliação #2'), findsNothing);
    expect(history.patientId, 2);
  });

  testWidgets('formulário CIF bloqueia paciente ausente e limpa na troca', (
    tester,
  ) async {
    final service = FakeCifService();
    final cif = CifFormProvider(service: service);
    final patient = PatientProvider();
    addTearDown(cif.dispose);
    addTearDown(patient.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: patient),
          ChangeNotifierProvider.value(value: cif),
        ],
        child: const MaterialApp(home: CifFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Selecione um paciente antes de abrir o formulário CIF.'),
      findsOneWidget,
    );

    patient.setPatient({
      'id': 1,
      'nome_completo': 'Paciente CIF Um',
      'sexo': 'Feminino',
    });
    await tester.pumpAndSettle();
    cif.setAnswer('f:E1', 4);
    expect(cif.responses['f:E1'], 4);

    patient.setPatient({
      'id': 2,
      'nome_completo': 'Paciente CIF Dois',
      'sexo': 'Feminino',
    });
    await tester.pumpAndSettle();

    expect(find.text('Paciente CIF Dois'), findsOneWidget);
    expect(cif.patientId, 2);
    expect(cif.responses, isEmpty);
  });

  testWidgets('rotas CIF aceitam IDs válidos e tratam argumentos inválidos', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    navigator.pushNamed('/cif_form', arguments: {'assessmentId': 17});
    await tester.pumpAndSettle();
    expect(
      tester.widget<CifFormScreen>(find.byType(CifFormScreen)).assessmentId,
      17,
    );
    navigator.pop();
    await tester.pumpAndSettle();

    navigator.pushNamed('/cif_summary', arguments: {'assessment_id': 18});
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CifSummaryScreen>(find.byType(CifSummaryScreen))
          .assessmentId,
      18,
    );
    expect(
      find.text('Selecione um paciente antes de abrir o quadro resumo CIF.'),
      findsOneWidget,
    );
    navigator.pop();
    await tester.pumpAndSettle();

    navigator.pushNamed(
      '/cif_comparison',
      arguments: {'firstAssessmentId': 'bad', 'secondAssessmentId': -1},
    );
    await tester.pumpAndSettle();
    final comparison = tester.widget<CifComparisonScreen>(
      find.byType(CifComparisonScreen),
    );
    expect(comparison.firstAssessmentId, isNull);
    expect(comparison.secondAssessmentId, isNull);
    expect(
      find.text('Selecione um paciente antes de comparar avaliações CIF.'),
      findsOneWidget,
    );
  });
}
