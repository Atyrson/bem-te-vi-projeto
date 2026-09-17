import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:projeto/Core/Models/cifModels.dart';
import 'package:projeto/Core/Providers/cifFormProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/Screens/cifForm.dart';

import 'cif_test_support.dart';

void main() {
  testWidgets('exibe código e descrição e permite selecionar zero', (
    tester,
  ) async {
    final service = FakeCifService();
    final cifProvider = CifFormProvider(service: service);
    final patientProvider = PatientProvider()
      ..setPatient({
        'id': 1,
        'nome_completo': 'Maria da Silva',
        'cpf': '000.000.000-00',
        'sexo': 'Feminino',
      });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: patientProvider),
          ChangeNotifierProvider.value(value: cifProvider),
        ],
        child: const MaterialApp(home: CifFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('b1100'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Descrição do primeiro campo'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Descrição do primeiro campo'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('cif-field-card-f:E1')),
        matching: find.widgetWithText(ChoiceChip, '0'),
      ),
    );
    await tester.pump();
    expect(cifProvider.answerFor('f:E1'), 0);

    cifProvider.dispose();
    patientProvider.dispose();
  });

  testWidgets('exibe prévias calculadas por código em todas as áreas', (
    tester,
  ) async {
    final service = FakeCifService()..previewResponse = _partialPreview();
    final cifProvider = CifFormProvider(service: service);
    final patientProvider = PatientProvider()
      ..setPatient({
        'id': 1,
        'nome_completo': 'Maria da Silva',
        'sexo': 'Feminino',
      });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: patientProvider),
          ChangeNotifierProvider.value(value: cifProvider),
        ],
        child: const MaterialApp(home: CifFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prévia'));
    await tester.pumpAndSettle();

    expect(
      find.text('Prévia parcial pelo backend; não é resultado definitivo.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cif-preview-area-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('cif-preview-area-s')), findsOneWidget);
    expect(find.byKey(const ValueKey('cif-preview-area-d')), findsOneWidget);
    expect(find.byKey(const ValueKey('cif-preview-area-e')), findsOneWidget);
    expect(find.text('1.25'), findsOneWidget);
    expect(find.text('Pendente'), findsWidgets);
    expect(
      cifProvider.preview!.result.chapters.values
          .where((chapter) => chapter.area == 'b')
          .length,
      1,
    );

    expect(
      find.byKey(const ValueKey('cif-preview-chapter-b-b1')),
      findsOneWidget,
    );
    expect(find.text('1.50'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cif-preview-chapter-b-b1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cif-preview-result-b:E3')),
      findsOneWidget,
    );
    expect(find.text('b110'), findsOneWidget);
    expect(find.text('0.50'), findsOneWidget);

    for (final areaCode in ['s', 'd', 'e']) {
      final chapterTile = find.byKey(
        ValueKey('cif-preview-chapter-$areaCode-${areaCode}1'),
      );
      await tester.scrollUntilVisible(
        chapterTile,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(chapterTile);
      await tester.pumpAndSettle();
      await tester.tap(chapterTile);
      await tester.pumpAndSettle();

      final calculatedCode = find.byKey(
        ValueKey('cif-preview-result-$areaCode:E3'),
      );
      await tester.scrollUntilVisible(
        calculatedCode,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(calculatedCode);
      await tester.pumpAndSettle();
      expect(calculatedCode, findsOneWidget);
    }

    cifProvider.dispose();
    patientProvider.dispose();
  });
}

CifPreview _partialPreview() {
  CifPartialResult partial({
    required String code,
    required String area,
    required String field,
    double? value,
    bool pending = false,
    String? name,
  }) => CifPartialResult(
    code: code,
    area: area,
    field: field,
    value: value,
    exactValue: value,
    pending: pending,
    name: name,
  );

  final result = CifPreviewResult(
    status: 'pendente',
    definitive: false,
    sex: 'Feminino',
    chapters: {
      'b1': partial(code: 'b1', area: 'b', field: 'b:E2', value: 1.5),
      's1': partial(code: 's1', area: 's', field: 's:E2', pending: true),
      'd1': partial(code: 'd1', area: 'd', field: 'd:E2', value: 2.0),
      'e1': partial(code: 'e1', area: 'e', field: 'e:E2', value: 0.75),
    },
    areas: {
      'b': partial(
        code: 'b',
        area: 'b',
        field: 'b:E4',
        value: 1.25,
        name: 'FUNÇÕES DO CORPO',
      ),
      's': partial(
        code: 's',
        area: 's',
        field: 's:E3',
        pending: true,
        name: 'ESTRUTURA DO CORPO',
      ),
      'd': partial(
        code: 'd',
        area: 'd',
        field: 'd:E3',
        value: 2.0,
        name: 'ATIVIDADES E PARTICIPAÇÃO',
      ),
      'e': partial(
        code: 'e',
        area: 'e',
        field: 'e:E3',
        value: 0.75,
        name: 'FATORES AMBIENTAIS',
      ),
    },
    intermediates: {
      'b:E3': partial(code: 'b110', area: 'b', field: 'b:E3', value: 0.5),
      's:E3': partial(code: 's110', area: 's', field: 's:E3', pending: true),
      'd:E3': partial(code: 'd110', area: 'd', field: 'd:E3', value: 1.5),
      'e:E3': partial(code: 'e110', area: 'e', field: 'e:E3', value: 0.25),
    },
    pendingIssues: const [],
    errors: const [],
    audit: const {},
  );

  return CifPreview(
    assessmentId: 8,
    patientId: 1,
    catalogVersion: 'test-catalog',
    rulesVersion: 'test-rules',
    status: 'pendente',
    definitive: false,
    result: result,
  );
}
