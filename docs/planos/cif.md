# Plano incremental: avaliações CIF

Branch: `feat/cif-avaliacoes`, criada a partir de `dev`.

## Escopo e situação inicial

O app usa Flutter/Dart, FastAPI e PostgreSQL. Existem cadastro/busca de pacientes, anamnese, ASIA, MEEM, eletrodiagnóstico, densitometria e GAS. A seleção de paciente abre ASIA e o menu atual não segue a ordem enviada. Não há módulo CIF, resumo CIF ou consulta de histórico de avaliações na API inspecionada.

Implementar CIF completa, resumo automático, persistência por paciente, múltiplas avaliações e comparação. Reutilizar tema e componentes atuais. Telas próprias de plano de treino, evolução, IA, exportação Excel/PDF e mudanças nas outras escalas ficam fora desta demanda.

Preservar as alterações locais preexistentes. Adicionar aos commits somente os arquivos desta demanda; não usar `git add .`. Não executar scripts de população ou recriação de banco como parte da implementação.

## 0. Registrar o plano

- [x] Inspecionar estrutura e navegação existentes.
- [x] Criar branch dedicada.
- [x] Registrar módulos, critérios e commits previstos.

Commit: `docs(cif): registrar plano incremental de implementacao`

## 1. Validar regras e converter o catálogo

- [x] Mapear as quatro áreas e os 30 capítulos, códigos, descrições, hierarquia e campos de entrada do Excel.
- [x] Definir campos de entrada pelas folhas alcançáveis na cadeia de fórmulas;
  usar negrito/roxo como indicação visual, não como única regra de inclusão.
- [x] Exigir sexo `Masculino` ou `Feminino` para a CIF; bloquear tela e servidor
  quando o sexo estiver ausente ou for `Outro`, informando o motivo.
- [x] Definir valores de entrada como inteiros de 0 a 4, sem decimais.
- [x] Marcar como obrigatórios os campos de entrada alcançáveis pelas fórmulas e
  bloquear o cálculo automático enquanto algum estiver ausente.
- [x] Não oferecer “não aplicável” nesta versão. Situações sem nota inteira de 0–4
  permanecerão pendentes e bloquearão o cálculo; ausência não será convertida em zero.
- [x] Manter precisão nos cálculos internos e arredondar somente a apresentação
  final para duas casas decimais.
- [x] Auditar referências, exclusões e repetições das fórmulas. A única correção
  autorizada é remover a repetição de `E119` em `E105`; as demais referências
  serão preservadas.
- [x] Confirmar as médias existentes e a aba `final` como referência do resumo de
  capítulos e dos quatro resultados separados por área.
- [ ] Confirmar posição da CIF e marco dos três meses: início do treino ou avaliação inicial.
- [x] Gerar catálogo versionado em JSON a partir de ferramenta reproduzível, sem importar valores preenchidos como respostas.
- [ ] Registrar exemplos de entrada e resultados esperados validados com o responsável pelas regras.

Saída: catálogo e especificação independentes de telas e banco. Dúvidas impedem apenas as regras dependentes; inventário e estrutura podem avançar.

Commit: `feat(cif): adicionar catalogo versionado e regras de qualificacao`

Entrega independente da etapa 1: [regras e auditoria](../cif/regras-e-auditoria.md).
Catálogo provisório e ferramenta reproduzível entregues; confirmações e exemplos
clínicos continuam pendentes. Execução pausada para revisão por solicitação do
usuário; não iniciar etapa 2 sem nova ordem.

Revisão posterior: as referências existentes nas fórmulas serão reproduzidas como
estão, sem correções estruturais automáticas. A única correção de fórmula aprovada
é remover a segunda ocorrência de `E119` em `E105`. Também foram registradas
decisões sobre código canônico, exclusão de `E13`, variantes Mulher/Homem e
inclusão da aba `TRADUÇÃO` como referência de auditoria. A aba `TRADUÇÃO` não será
fonte de qualificadores clínicos nem de cálculo do paciente; o motor usará o
catálogo principal e seus resultados hierárquicos. Permanecem pendentes o
tratamento de campos ausentes e não especificados, exemplos validados e as
demais decisões clínicas da etapa 1.

Diretriz de resumo: o motor produzirá os qualificadores dos 30 capítulos e os
quatro resultados de área por média hierárquica conforme as regras aprovadas.
As contagens da aba `TRADUÇÃO` serão somente referência de auditoria. O quadro
por área será o resumo clínico primário; um resultado geral único não será
interpretado clinicamente sem regra específica validada.

Validação clínica posterior: após a implementação integral e a rodada de testes,
o software será levado aos fisioterapeutas para avaliação e validação clínica
completa. Até essa etapa, a implementação será considerada tecnicamente provisória.

## 2. Implementar cálculo e validação isolados

- [ ] Criar modelos e calculador Python em módulo próprio, sem dependência HTTP ou banco.
- [ ] Calcular níveis intermediários, capítulos, áreas e resultado geral conforme regras validadas.
- [ ] Identificar pendências e rejeitar notas inválidas e códigos desconhecidos.
- [ ] Bloquear resultado automático quando houver campo de entrada obrigatório ausente.
- [ ] Bloquear resultado automático quando o sexo do paciente estiver ausente ou
  for `Outro`, tanto na API quanto na tela CIF.
- [ ] Testar valores extremos, rejeição de decimais, hierarquia com grupos de
  tamanhos diferentes e campos pendentes conforme as decisões da etapa 1.
- [ ] Testar que avaliação incompleta não produz resumo definitivo e que zero conta como resposta.

Saída: resultados reproduzíveis com testes automatizados. Backend é a fonte oficial dos cálculos, evitando dois motores divergentes em Dart e Python.

Commit: `feat(cif): implementar calculo hierarquico e validacao`

## 3. Persistir avaliações e expor API

- [ ] Criar migração aditiva específica, sem depender de alterações locais não versionadas em `Backend/schema.sql`.
- [ ] Salvar avaliação com ID, paciente_id, data da avaliação, status, versão do catálogo/regras, respostas e resultados da conclusão.
- [ ] Usar ID do paciente, já disponível no PatientProvider, em vez do nome como vínculo.
- [ ] Separar rotas, modelos e acesso ao banco do módulo CIF; registrar router no app existente.
- [ ] Disponibilizar catálogo, criação de rascunho, atualização, prévia de cálculo, conclusão, listagem por paciente e consulta individual.
- [ ] Recalcular e validar no servidor ao concluir; não confiar em totais enviados pelo cliente.
- [ ] Preservar avaliações concluídas; impedir edição pelo endpoint de rascunho.
- [ ] Verificar salvamento transacional, isolamento entre pacientes, reabertura de rascunho e múltiplas avaliações do mesmo paciente.
- [ ] Evitar duplicação na conclusão repetida de uma avaliação; documentar contrato e erros.

Saída: fluxo completo via API em banco de desenvolvimento/teste, com migração documentada.

Commits:
1. `feat(cif): adicionar persistencia de avaliacoes`
2. `feat(cif): expor API de rascunhos calculo e conclusao`

## 4. Construir formulário Flutter

- [ ] Criar modelos, serviço CIF e provider próprios nas pastas Core existentes.
- [ ] Criar tela e componentes por área/capítulo em Presentation, reutilizando tema e campos comuns.
- [ ] Renderizar campos a partir do catálogo, sem centenas de inputs escritos manualmente.
- [ ] Exibir paciente, data, progresso e seleção 0–4, distinguindo sem resposta de zero.
- [ ] Salvar e retomar rascunho; exibir carregamento, falha de rede e nova tentativa sem apagar dados digitados.
- [ ] Mostrar pendências por capítulo e proteger contra saída com alterações não salvas.
- [ ] Consultar prévias do backend com controle de requisições e indicar resultados parciais.
- [ ] Limpar o estado ao trocar paciente/avaliação e evitar submissões duplicadas.
- [ ] Testar preenchimento, retomada, erro de rede e troca de paciente em widgets selecionados.

Saída: avaliação preenchível e retomável, acessível por rota dedicada até a integração final da navegação.

Commit: `feat(cif): adicionar formulario com progresso e rascunho`

## 5. Apresentar quadro resumo

- [ ] Exibir 30 qualificadores de capítulos, quatro resultados de áreas e resultado geral validado.
- [ ] Liberar resumo definitivo somente após conclusão aceita pelo backend.
- [ ] Identificar paciente, data e avaliação; permitir consultar respostas que originaram o resumo.
- [ ] Respeitar precisão definida e não exibir erro de divisão por zero em campos pendentes.
- [ ] Comparar tela e API com os exemplos validados da etapa 1.

Saída: formulário completo gera quadro resumido consistente com as regras acordadas.

Commit: `feat(cif): apresentar quadro resumo da avaliacao`

## 6. Histórico e reavaliação

- [ ] Listar avaliações do paciente com data e status, incluindo acesso aos rascunhos.
- [ ] Adicionar botão `+ Nova avaliação`, criando registro separado e respostas vazias.
- [ ] Permitir várias avaliações sem sobrescrever a primeira ou limitar a duas.
- [ ] Mostrar referência de reavaliação após três meses conforme marco confirmado, sem bloquear avaliações antecipadas.
- [ ] Comparar duas avaliações concluídas por capítulo e área, mostrando valores e diferença numérica.
- [ ] Não atribuir automaticamente significado clínico de melhora/piora sem regra validada, especialmente para fatores ambientais.
- [ ] Comparar somente versões compatíveis ou explicar incompatibilidade.
- [ ] Verificar preservação da avaliação inicial e ausência de dados de outros pacientes.

Commit: `feat(cif): adicionar historico reavaliacao e comparacao`

## 7. Integrar navegação e verificar regressões

- [ ] Organizar módulos existentes: Anamnese → CIF → ASIA → MEEM → Eletrodiagnóstico → DEX → GAS, sujeito à confirmação da sequência.
- [ ] Ajustar entrada após seleção de paciente e atalho da anamnese para a sequência confirmada.
- [ ] Manter acesso independente aos módulos; não impor bloqueio entre exames sem requisito.
- [ ] Não criar itens vazios de plano de treino/evolução/IA para simular módulos inexistentes.
- [ ] Garantir paciente selecionado ao abrir CIF.
- [ ] Substituir teste padrão de contador, que não corresponde ao app, por smoke test da tela inicial real.
- [ ] Executar análise Flutter, testes relevantes e build web, registrando problemas preexistentes separadamente.
- [ ] Executar testes Python e integração CIF em banco de teste.
- [ ] Validar manualmente cadastro/busca → CIF → rascunho → retomada → conclusão → resumo → nova avaliação → comparação.
- [ ] Conferir que formulários existentes continuam acessíveis e que o tema funciona em desktop e largura móvel.

Commits:
1. `feat(navigation): integrar CIF a sequencia de avaliacoes`
2. `test(cif): validar fluxo completo e navegacao existente`

## Entregas revisáveis

1. Regras e catálogo: etapa 1.
2. Cálculo e API utilizáveis: etapas 2–3.
3. Avaliação inicial com resumo: etapas 4–5.
4. Acompanhamento longitudinal: etapa 6.
5. Integração e validação final: etapa 7.

Cada commit deve compilar ou manter seus testes específicos passando. Se surgir correção independente, criar commit próprio; não misturar refatorações gerais. Não publicar, fazer merge ou alterar banco em uso como consequência automática deste plano.
