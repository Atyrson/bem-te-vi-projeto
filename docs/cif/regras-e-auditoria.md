# CIF — entrega da etapa 1 para revisão

Status: inventário concluído; decisões parciais de revisão registradas; regras
clínicas e correções restantes **pendentes de aprovação**.
Não iniciar a etapa 2 sem nova ordem. Nenhuma regra da planilha foi tratada como
instrução operacional ao agente. Não foram alterados app, API ou banco.

## Como localizar as referências no Excel

Neste documento, **planilha** significa o arquivo `.xlsx`; **aba** é o nome
exibido na parte inferior do Excel; **célula** é o endereço, como `E105`.
Os dois arquivos originais estão em `/home/atyrson/Downloads/`:

- **PLANILHA CIF de Qualificação.xlsx**: contém as abas `FUNÇÕES DO CORPO`,
  `ESTRUTURA DO CORPO`, `ATIVIDADES E PARTICIPAÇÃO`, `FATORES AMBIENTAIS`,
  `Plan1` (oculta) e `LEGENDA`.
- **Quadro Resumo de Qualificadores Resultantes.xlsx**: contém as abas
  `ORIGINAL`, `TRADUÇÃO`, `PORCENTAGEM` e `final`.

Para conferir uma referência, abra o arquivo indicado, selecione a aba e digite
o endereço na **caixa de nome**, à esquerda da barra de fórmulas. Pressione Enter.
A barra de fórmulas mostra o cálculo da célula selecionada. No Excel em português,
`AVERAGE` pode aparecer como `MÉDIA`, e `SUM` como `SOMA`, com `;` no lugar de `,`.
Um intervalo como `E9:E12` inclui E9, E10, E11 e E12.
Todos os endereços mencionados em cada achado abaixo pertencem ao arquivo e à aba
indicados naquele achado, salvo indicação explícita em contrário.

## Reprodução

Executar na raiz, com Python 3 e somente biblioteca padrão:

```bash
python scripts/cif/extrair_catalogo.py \
  '/home/atyrson/Downloads/PLANILHA CIF de Qualificação.xlsx' \
  '/home/atyrson/Downloads/Quadro Resumo de Qualificadores Resultantes.xlsx'
python -m unittest discover -s scripts/cif -p 'test_*.py'
```

Fontes identificadas por nome e SHA-256 no catálogo. Os arquivos originais não
foram copiados ao Git. Saída determinística, sem datas de geração, dependências
externas, execução de fórmulas, respostas numéricas ou resultados em cache.
O inventário de textos inclui legendas e títulos; não constitui regras aprovadas.

## Catálogo e limites

`catalogos/cif/catalogo.v0.1.json` contém quatro áreas:

| Área | Capítulos | Ocorrências, incluindo raiz e capítulos |
| --- | --- | --- |
| b — Funções do corpo | b1–b8 | 493 |
| s — Estrutura do corpo | s1–s8 | 311 |
| d — Atividades e participação | d1–d9 | 393 |
| e — Fatores ambientais | e1–e5 | 258 |

São 1.455 ocorrências, não 1.455 campos obrigatórios. A identificação por área e
linha preserva duplicatas. Códigos foram aparados e convertidos para minúsculas
(incluindo os textos `B126` e `B130`, que são códigos, não endereços de células:
eles estão em `D26` e `D37`, respectivamente, na aba `FUNÇÕES DO CORPO` da planilha
**PLANILHA CIF de Qualificação.xlsx**). O texto original continua na auditoria.
Nas quatro abas de áreas dessa mesma planilha, as descrições vêm da coluna B
ou do título na coluna A, na mesma linha do código na coluna D. `parent_by_code` é o maior prefixo existente, uma
hierarquia estrutural candidata, **não uma decisão de cálculo**. Não há deduplicação
nem correção clínica silenciosa.

Cada campo registra endereço, fórmula e estilos de código/valor; `required: null`
significa não decidido. `input_candidate` significa apenas ausência de fórmula,
não autorização para renderizar um campo obrigatório. Negrito e cor são preservados
como propriedades OOXML: o destaque predominante usa tema 7 com tint
0.59999389629810485. Não se deduz obrigatoriedade apenas da cor.

As colunas e variantes estão na planilha **PLANILHA CIF de Qualificação.xlsx**:

| Aba | Valores principais | Células de variantes Homem |
| --- | --- | --- |
| FUNÇÕES DO CORPO | Coluna E; cabeçalho Mulher em D2 | G4: total da área; I384: capítulo b6; cabeçalho Homem em F2 e indicação em I383 |
| ESTRUTURA DO CORPO | Coluna E; cabeçalho Mulher em D2 | H3: total da área; H173: capítulo s6; G183: agregado na linha de s630; cabeçalho Homem em G2 |
| ATIVIDADES E PARTICIPAÇÃO | Coluna E; cabeçalho em E2 | Nenhuma variante mapeada |
| FATORES AMBIENTAIS | Coluna E; cabeçalho em E2 | Nenhuma variante mapeada |

A associação de `I384` a b6 na aba `FUNÇÕES DO CORPO` e de `G183` a s630 na
aba `ESTRUTURA DO CORPO`, ambas no arquivo acima, está marcada como proposta.
A seleção do perfil e a aplicabilidade de cada item continuam pendentes;
referências compartilhadas não devem virar respostas independentes.

`auditoria.v0.1.json` registra todas as abas (incluindo a aba `Plan1`, oculta na planilha **PLANILHA CIF de Qualificação.xlsx**), textos,
fórmulas expandidas de células compartilhadas e validações de dados (nenhuma
nas quatro abas de qualificação). Não é um avaliador Excel genérico: a análise
de referências cobre endereços A1/ranges locais presentes nesses arquivos.

## Achados e propostas, ainda não adotadas

### 1. Uma célula conta duas vezes na média

**Planilha:** PLANILHA CIF de Qualificação.xlsx

**Aba:** FUNÇÕES DO CORPO

**Célula para selecionar:** E105

A fórmula é `=AVERAGE(E106,E112,E118,E119,E119)`. A célula `E119` aparece duas
vezes e, portanto, tem peso duplo. O código do agregado está em `D105`: **b167**,
“Funções mentais da linguagem” (título em `A105`). O código repetido está em
`D119`: b1678, com descrição em `B119`.

**Correção desta documentação:** a versão anterior citava b164 neste achado;
a conferência mostra que o correto é b167. A fórmula original não foi alterada.

Proposta: confirmar se remover a repetição ou substituir por outra referência.

### 2. Códigos que aparecem em mais de uma linha

**Planilha de todas as linhas desta tabela:** PLANILHA CIF de Qualificação.xlsx.
As células abaixo apontam para a coluna D, usada como código no catálogo.

| Aba | Código repetido | Células dos códigos | Onde conferir os títulos ou descrições |
| --- | --- | --- | --- |
| ESTRUTURA DO CORPO | s73020 | D243 e D244 | B243 e B244: ossos versus articulações da mão |
| ATIVIDADES E PARTICIPAÇÃO | d335 | D81 e D98 | A81 e A98: mensagens não verbais versus discussão |
| FATORES AMBIENTAIS | e5151 | D169 e D170 | B169 e B170: sistemas relacionados com arquitetura e construção |
| FATORES AMBIENTAIS | e598 | D263 e D269 | A263 e A269: sistema político versus outros especificados |

Na aba `FATORES AMBIENTAIS` dessa planilha, há ainda uma divergência na mesma
linha: `A263` menciona e595 no título, enquanto `D263` contém e598. O catálogo
preservou o código de D263; a correção depende de confirmação.

Proposta: confirmar o código correto ou a exclusão de cada ocorrência antes de
usar código como chave de resposta. Duplicatas foram preservadas no catálogo.

### 3. Um item detalhado não entra na média do seu grupo

**Planilha:** PLANILHA CIF de Qualificação.xlsx

**Aba:** FUNÇÕES DO CORPO

**Célula para selecionar:** E8

A fórmula `=AVERAGE(E9:E12)` inclui `E9` a `E12`, mas não `E13`. O código do
item omitido está em `D13`: b1109. Isso pode ser uma exclusão intencional de
item não especificado; não foi classificado automaticamente como erro.

O relatório contém 212 ocorrências, incluindo repetição e divergências da
hierarquia por prefixo, **não 212 erros confirmados**. Para revisar todas sem
ler JSON, consulte o [índice completo de referências](referencias-da-auditoria.md):
cada ocorrência informa planilha, aba, célula da fórmula e células relacionadas.

### 4. Os cálculos Mulher/Homem usam endereços diferentes

**Planilha:** PLANILHA CIF de Qualificação.xlsx.

| Aba | Célula para selecionar | Referência a conferir na mesma aba |
| --- | --- | --- |
| FUNÇÕES DO CORPO | G4 | Usa I384 para b6; os outros capítulos vêm da coluna E |
| ESTRUTURA DO CORPO | H3 | Usa H173 para s6; os outros capítulos vêm da coluna E |
| ESTRUTURA DO CORPO | H173 | Usa G183 para o agregado na linha de s630 |

Proposta: representar variantes explicitamente, sem presumir uma coluna Homem
para cada código. Os cabeçalhos e as colunas principais constam da tabela anterior.

### 5. Referências diferentes nas somas de distribuição

**Planilha:** Quadro Resumo de Qualificadores Resultantes.xlsx

**Aba:** TRADUÇÃO

**Células para selecionar:** C8 e D8

Em `C8`, a fórmula `=SUM(C18+ C28+C39+C87)` usa `C87`. Em `D8`, a fórmula
`=SUM(D18+D28+D38+D46)` usa `D38`. Compare com `E8`, cuja fórmula usa
`E18`, `E28`, `E39` e `E46`. Todas essas células estão na mesma aba `TRADUÇÃO`.
Proposta: confirmar se essa aba pertence ao escopo antes de corrigir referências.

### 6. O resumo final calcula médias, não somas de contagens

**Planilha:** Quadro Resumo de Qualificadores Resultantes.xlsx

**Aba:** final

| Célula para selecionar | O que calcula | Células de origem na mesma aba |
| --- | --- | --- |
| B13 | Média dos capítulos de funções do corpo | B5:B12 |
| B23 | Média dos capítulos de estruturas do corpo | B15:B22 |
| B34 | Média dos capítulos de atividades e participação | B25:B33 |
| B41 | Média dos capítulos de fatores ambientais | B36:B40 |
| B44 | Média das quatro áreas | B13, B23, B34 e B41 |

Os 30 valores de capítulos nos intervalos acima são preenchidos, não fórmulas
vinculadas à planilha **PLANILHA CIF de Qualificação.xlsx**. Não validam por si
só o motor futuro. Na planilha **Quadro Resumo de Qualificadores Resultantes.xlsx**,
as abas `ORIGINAL`, `TRADUÇÃO` e `PORCENTAGEM` tratam de distribuição/contagens;
o exemplo de somas auditado está em `TRADUÇÃO`, células `C8` e `D8` (achado 5).

## Decisões registradas após revisão

As decisões abaixo avançam a validação da etapa 1 e orientam a implementação, mas
não alteram as planilhas originais nem, sozinhas, liberam a etapa 2. Os valores e
fórmulas observados continuam preservados no catálogo e na auditoria para
rastreabilidade.

1. Considerar corretas, para a implementação, as referências atualmente existentes
   nas fórmulas, reproduzindo sua cadeia de dependências. A única correção de
   fórmula autorizada nesta revisão é em `E105`, removendo a segunda ocorrência
   de `E119`; não foi aprovada a substituição automática por `E120`. A fórmula
   resultante de `E105` será `AVERAGE(E106,E112,E118,E119)`.
2. Na divergência da linha 263 de `FATORES AMBIENTAIS`, usar como código canônico
   de implementação o código apresentado no título (`e595`), e não o valor
   observado em `D263` (`e598`). A divergência original deve permanecer registrada
   como evidência da auditoria até a reconciliação do catálogo.
3. Em `E8`, manter `E13` fora da média. A exclusão de `b1109` é uma decisão
   intencional para a regra atual.
4. Manter as referências Mulher/Homem como estão na fonte. A implementação deve
   representar explicitamente as variantes: `E384`/`I384` para `b6`,
   `E173`/`H173` para `s6` e `E183`/`G183` para `s630`, sem inferir a variante
   apenas pela coluna.
5. A aba `TRADUÇÃO` do **Quadro Resumo de Qualificadores Resultantes.xlsx**
   pertence ao escopo da etapa 1 como fonte de auditoria e referência da
   distribuição dos códigos. Suas contagens, percentuais e fórmulas devem ser
   auditados e registrados, mas não entram no cálculo do resultado clínico de um
   paciente. O calculador usará os qualificadores e a hierarquia do catálogo
   principal; eventual relatório de distribuição será uma saída separada. Isso
   não reabre o escopo de exportação Excel/PDF excluído no plano.
6. Para o plano de implementação, os resultados clínicos resumidos serão
   baseados nos qualificadores dos capítulos e nas médias hierárquicas aprovadas,
   mantendo os quatro resultados de área separados. As contagens da aba
   `TRADUÇÃO` não serão usadas como escore. O valor geral equivalente a `B44` não
   será tratado como índice clínico automático; a avaliação só terá resultado
   geral definitivo se uma regra específica for validada. Campos ausentes devem
   manter a avaliação pendente, sem serem convertidos em zero.
7. Os campos de entrada aceitarão somente qualificadores inteiros de `0` a `4`,
   sem valores decimais.
8. Os campos utilizados no cálculo serão as células sem fórmula alcançáveis pela
   cadeia de referências dos capítulos e áreas. Células com fórmula serão apenas
   calculadas; células fora dessa cadeia não participarão do resultado. Negrito e
   roxo serão preservados como indicação visual, mas não serão a única fonte para
   definir os campos utilizados.
9. Os cálculos internos manterão a precisão necessária, sem arredondamento
   intermediário. Os resultados exibidos no resumo final serão arredondados para
   duas casas decimais.
10. Todos os campos de entrada que participam da cadeia de cálculo serão marcados
    como obrigatórios. Sem o preenchimento desses campos, o sistema poderá manter
    um rascunho, mas não poderá gerar ou concluir o cálculo automático. O valor
    `0` é uma resposta válida e não equivale a campo ausente.
11. O campo `sexo` já existe no cadastro do paciente, na API e no banco, mas é
    opcional e atualmente aceita `Masculino`, `Feminino` e `Outro`. Para a CIF,
    o sexo deverá estar informado como `Masculino` ou `Feminino` para selecionar
    a variante Mulher/Homem. A tela e o servidor deverão bloquear o cálculo e a
    conclusão quando o sexo estiver ausente ou for `Outro`, informando o motivo.
12. Nesta primeira versão não haverá opção `não aplicável`. Os campos de entrada
    aceitarão somente valores inteiros de `0` a `4`; se uma situação não puder
    receber uma dessas notas, o campo permanecerá pendente e o cálculo automático
    não poderá ser concluído. Essa situação não será convertida em zero.
13. A validação clínica completa será realizada posteriormente com fisioterapeutas,
    após a implementação integral e a execução dos testes. Até essa avaliação,
    as regras e os resultados serão considerados provisórios para fins de validação
    técnica do software.

## Decisões solicitadas para liberar as etapas dependentes

1. Como representar “não especificado”? Fatores ambientais admitem facilitadores
   e barreiras com sinais diferentes? Por enquanto não haverá opção “não aplicável”:
   situações sem nota de 0–4 permanecerão pendentes. Ausência nunca será convertida
   em zero.
2. Confirmar o tratamento de campos ausentes e não especificados no cálculo.
   Situações sem nota de 0–4 permanecerão pendentes nesta versão. Os cálculos não
   terão arredondamento intermediário e a apresentação usará duas casas decimais.
3. Confirmar a aba `final` da planilha **Quadro Resumo de Qualificadores Resultantes.xlsx**
   (células detalhadas no achado 6) como resumo desejado. As duplicatas, repetições,
   exclusões e demais referências existentes serão preservadas como estão, exceto
   pela repetição de `E119` em `E105`.
4. Confirmar sequência Anamnese → CIF → ASIA → MEEM → Eletrodiagnóstico → DEX → GAS
   e se os três meses contam da avaliação inicial ou do início do treino.

## Exemplos propostos para validação pelo responsável

Estes exemplos não estão aprovados nem implementados como motor:

| Entrada | Resultado esperado proposto |
| --- | --- |
| Todos os campos de entrada respondidos com 0 | 0; completo |
| Todos os campos de entrada respondidos com 4 | 4; completo |
| Um filho 0 e outro ausente | incompleto; sem resultado definitivo |
| Grupo A com [0, 4], grupo B com [4] | médias 2 e 4; pai 3 (não 8/3) |
| Filhos [1, 2] | 1,5 antes da regra de arredondamento |
| Campo [4, campo ausente] | pendente; sem resultado definitivo |
| Todos os campos ausentes | pendente; nunca divisão por zero |

A validação desses casos, dos valores permitidos e das correções é necessária
antes de declarar a etapa 1 integralmente validada. Esta entrega encerra somente
a parte independente da etapa 1 e pausa para revisão conforme solicitado.
