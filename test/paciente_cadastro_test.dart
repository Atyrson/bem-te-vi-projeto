import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto/Presentation/Screens/pacienteCadastro.dart';

void main() {
  testWidgets('cadastro bloqueia envio com apenas o nome', (tester) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 201);
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(home: PatientRegistrationScreen(client: client)),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Paciente Teste');
    await tester.ensureVisible(find.text('Cadastrar'));
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(
      find.text(
        'Preencha os campos obrigatórios: data de nascimento, sexo, CPF.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cadastro mostra o campo rejeitado pela API', (tester) async {
    final today = DateTime.now();
    final expectedDate =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-01';
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/patients');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['nome_completo'], 'Paciente Teste');
      expect(body['data_nascimento'], expectedDate);
      expect(body['sexo'], 'Feminino');
      expect(body['cpf'], '12345678909');
      expect(body['peso'], 72.5);
      expect(body['email'], isNull);
      return http.Response(
        jsonEncode({
          'detail': [
            {
              'loc': ['body', 'data_nascimento'],
              'msg': 'Input should be a valid date',
              'type': 'date_from_datetime_parsing',
            },
          ],
        }),
        422,
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(home: PatientRegistrationScreen(client: client)),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Paciente Teste');
    await tester.enterText(find.byType(TextField).at(2), '72,5');
    await tester.enterText(find.byType(TextField).at(4), '12345678909');
    await tester.tap(find.byType(TextField).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feminino').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cadastrar'));
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('Confira os campos: data de nascimento.'), findsOneWidget);
  });
}
