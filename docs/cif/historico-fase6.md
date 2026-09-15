# CIF — histórico, reavaliação e comparação

## Isolamento

O aplicativo consulta `GET /api/v1/patients/{patient_id}/cif-avaliacoes` e
filtra novamente os itens pelo `paciente_id` retornado. A avaliação usada para
abrir formulário, resumo ou comparação também precisa corresponder ao paciente
selecionado.

## Reavaliação

O contrato atual do backend não informa qual avaliação é a inicial nem fornece
uma data de referência de reavaliação. Por isso o aplicativo não escolhe a
primeira avaliação do histórico por posição ou data e não inventa uma regra
clínica. A referência de três meses só é exibida quando o backend enviar
`data_reavaliacao_referencia` ou marcar explicitamente `avaliacao_inicial`;
nesse último caso a data é calculada como três meses corridos no calendário,
com ajuste seguro para o último dia do mês.

Avaliações anteriores ao marco continuam permitidas. Datas ausentes ou inválidas
não interrompem a tela.

## Comparação

A tela alinha apenas capítulos e áreas presentes nos dois resumos já devolvidos
pela API. A diferença exibida é `segunda avaliação - primeira avaliação`.
Valores nulos ou pendentes não viram zero e não geram diferença numérica.
Catálogo, regras e pacientes incompatíveis bloqueiam a comparação automática;
nenhuma conversão ou recálculo local é feito.
