import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto/Presentation/Screens/pacienteCadastro.dart';

void main() {
  testWidgets('cadastro mostra o campo rejeitado pela API', (tester) async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/patients');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['nome_completo'], 'Paciente Teste');
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
    await tester.ensureVisible(find.text('Cadastrar'));
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('Confira os campos: data de nascimento.'), findsOneWidget);
  });
}
