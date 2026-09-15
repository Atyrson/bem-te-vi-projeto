import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
}
