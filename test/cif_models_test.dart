import 'package:flutter_test/flutter_test.dart';
import 'package:projeto/Core/Models/cifModels.dart';

void main() {
  test('desserializa formulários Feminino e Masculino em ordem', () {
    Map<String, dynamic> json(String sex) => {
      'catalogo_versao': '0.1.0',
      'regras_versao': '0.1.0',
      'sexo': sex,
      'total_campos': 2,
      'escala': {
        'valores_permitidos': [0, 1, 2, 3, 4],
        'permite_sem_resposta_no_rascunho': true,
        'obrigatoria_na_conclusao': true,
      },
      'campos': [
        {
          'ordem': 2,
          'chave': 'b:E2',
          'codigo': 'b1100',
          'codigo_original': 'b1100',
          'descricao': 'Segundo',
          'area_codigo': 'b',
          'area_descricao': 'Corpo',
          'capitulo_codigo': 'b1',
          'capitulo_descricao': 'Mental',
          'obrigatorio_na_conclusao': true,
        },
        {
          'ordem': 1,
          'chave': 'b:E1',
          'codigo': 'b1100',
          'codigo_original': 'b1100',
          'descricao': 'Primeiro',
          'area_codigo': 'b',
          'area_descricao': 'Corpo',
          'capitulo_codigo': 'b1',
          'capitulo_descricao': 'Mental',
          'obrigatorio_na_conclusao': true,
        },
      ],
    };

    final feminine = CifForm.fromJson(json('Feminino'));
    final masculine = CifForm.fromJson(json('Masculino'));
    expect(feminine.sex, 'Feminino');
    expect(masculine.sex, 'Masculino');
    expect(feminine.fields.map((field) => field.key), ['b:E1', 'b:E2']);
    expect(feminine.totalFields, 2);
  });

  test('mantém códigos duplicados distintos pelas chaves', () {
    final form = CifForm.fromJson({
      'sexo': 'Feminino',
      'total_campos': 2,
      'escala': {
        'valores_permitidos': [0, 1, 2, 3, 4],
        'permite_sem_resposta_no_rascunho': true,
        'obrigatoria_na_conclusao': true,
      },
      'campos': [
        {
          'ordem': 1,
          'chave': 'b:E1',
          'codigo': 'b1100',
          'codigo_original': 'b1100',
          'descricao': 'A',
          'area_codigo': 'b',
          'area_descricao': 'B',
          'capitulo_codigo': 'b1',
          'capitulo_descricao': 'C',
          'obrigatorio_na_conclusao': true,
        },
        {
          'ordem': 2,
          'chave': 'b:E2',
          'codigo': 'b1100',
          'codigo_original': 'b1100',
          'descricao': 'B',
          'area_codigo': 'b',
          'area_descricao': 'B',
          'capitulo_codigo': 'b1',
          'capitulo_descricao': 'C',
          'obrigatorio_na_conclusao': true,
        },
      ],
    });
    expect(form.fields[0].code, form.fields[1].code);
    expect(form.fields.map((field) => field.key).toSet(), {'b:E1', 'b:E2'});
  });
}
