import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:projeto/Core/Config/api_config.dart';
import 'package:projeto/Core/Providers/meemFormProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/CommonWidgets/appDrawer.dart';
import 'package:provider/provider.dart';

class MeemFormScreen extends StatefulWidget {
  const MeemFormScreen({super.key});

  @override
  State<MeemFormScreen> createState() => _MeemFormScreenState();
}

class PentagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    Path path1 = Path();
    path1.moveTo(size.width * 0.70, size.height * 0.15);
    path1.lineTo(size.width * 0.45, size.height * 0.45);
    path1.lineTo(size.width * 0.55, size.height * 0.85);
    path1.lineTo(size.width * 0.85, size.height * 0.85);
    path1.lineTo(size.width * 0.95, size.height * 0.45);
    path1.close();
    canvas.drawPath(path1, paint);

    Path path2 = Path();
    path2.moveTo(size.width * 0.30, size.height * 0.15);
    path2.lineTo(size.width * 0.05, size.height * 0.45);
    path2.lineTo(size.width * 0.15, size.height * 0.85);
    path2.lineTo(size.width * 0.45, size.height * 0.85);
    path2.lineTo(size.width * 0.55, size.height * 0.45);
    path2.close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MeemFormScreenState extends State<MeemFormScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  final _formKeyStep0 = GlobalKey<FormState>();
  final _examDateController = TextEditingController();
  DateTime? _examDate;

  // --- FUNÇÃO PARA SALVAR NA API ---
  Future<void> _saveAndFinalizeForm(MeemFormProvider provider) async {
    if (!_formKeyStep0.currentState!.validate()) {
      setState(() {
        _currentStep = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os dados do paciente.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final url = ApiConfig.endpoint('meem-evaluations');

    try {
      final body = jsonEncode({
        "patientName": provider.nomeController.text,
        "examDate": DateFormat('yyyy-MM-dd').format(_examDate!),
        "examinerName": "Dr. Examinador",
        "age": int.tryParse(provider.idadeController.text) ?? 0,
        "escolaridade": provider.escolaridade,
        "pontos": {
          "orientacaoTemporal": provider.pontosOrientacaoTemporal,
          "orientacaoEspacial": provider.pontosOrientacaoEspacial,
          "memoriaImediata": provider.pontosMemoriaImediata,
          "atencaoCalculo": provider.pontosAtencaoCalculo,
          "memoriaEvocativa": provider.pontosMemoriaEvocativa,
          "linguagemNomear": provider.pontosLinguagemNomear,
          "linguagemRepetir": provider.pontoLinguagemRepetir,
          "linguagemComandoVerbal": provider.pontosLinguagemComandoVerbal,
          "linguagemComandoEscrito": provider.pontoLinguagemComandoEscrito,
          "linguagemFrase": provider.pontoLinguagemFrase,
          "linguagemCopia": provider.pontoLinguagemCopia,
        },
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exame MEEM salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _showResultDialog(provider);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['detail'] ?? 'Ocorreu um erro desconhecido.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro de conexão: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildScoreSelector({
    required String question,
    required int currentValue,
    required ValueChanged<int> onScoreSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(question, style: const TextStyle(fontSize: 15))),
          const SizedBox(width: 16),
          ToggleButtons(
            isSelected: [currentValue == 0, currentValue == 1],
            onPressed: (index) {
              onScoreSelected(index);
            },
            borderRadius: BorderRadius.circular(8.0),
            selectedColor: Colors.white,
            fillColor: Theme.of(context).primaryColor,
            color: Theme.of(context).primaryColor,
            constraints: const BoxConstraints(minHeight: 32.0, minWidth: 40.0),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('0'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('1'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionTitle(String text) {
    return ListTile(
      title: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildInstructionText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildExpansionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.grey.shade700),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
        children: children,
      ),
    );
  }

  @override
  @override
  void initState() {
    super.initState();

    // Preenchimento Automático
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final meemProvider = Provider.of<MeemFormProvider>(
        context,
        listen: false,
      );
      final patientGlobal = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      // --- DEBUG: Veja isso no console ---
      print("MEEM DEBUG - Nome: ${patientGlobal.nome}");
      print("MEEM DEBUG - Data Nasc: ${patientGlobal.dataNascimento}");
      print("MEEM DEBUG - Idade Calculada: ${patientGlobal.idade}");
      // ----------------------------------

      if (patientGlobal.nome != null) {
        meemProvider.nomeController.text = patientGlobal.nome!;

        // Se a idade foi calculada corretamente no Provider, preenche aqui
        if (patientGlobal.idade != null) {
          meemProvider.idadeController.text = patientGlobal.idade.toString();
        }
      }
    });
  }

  void dispose() {
    _examDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MeemFormProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: const Text('Mini-Exame do Estado Mental (MEEM)'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 80, 200, 120),
                Color.fromARGB(255, 6, 190, 123),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.3, 0.9],
            ),
          ),
        ),
      ),
      drawer: AppDrawer(),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 8) {
            setState(() => _currentStep += 1);
          } else {
            _saveAndFinalizeForm(provider);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: _buildSteps(context, provider),
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(8.0),
                    ),
                    child: Text(
                      _currentStep == 8 ? 'Finalizar e Salvar' : 'Próximo',
                    ),
                  ),
                const SizedBox(width: 8),
                if (_currentStep > 0 && !_isLoading)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Voltar'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Step> _buildSteps(BuildContext context, MeemFormProvider provider) {
    return [
      Step(
        title: const Text('Dados do Paciente'),
        isActive: _currentStep >= 0,
        content: Form(
          key: _formKeyStep0,
          child: Column(
            children: [
              TextFormField(
                controller: provider.nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Paciente',
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Campo obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: provider.idadeController,
                decoration: const InputDecoration(labelText: 'Idade'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Campo obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: provider.escolaridade,
                decoration: const InputDecoration(labelText: 'Escolaridade'),
                items: const [
                  DropdownMenuItem(
                    value: 'Analfabeto',
                    child: Text('Analfabetos'),
                  ),
                  DropdownMenuItem(
                    value: '1-4 anos',
                    child: Text('1 a 4 anos'),
                  ),
                  DropdownMenuItem(
                    value: '5-8 anos',
                    child: Text('5 a 8 anos'),
                  ),
                  DropdownMenuItem(
                    value: '9-11 anos',
                    child: Text('9 a 11 anos'),
                  ),
                  DropdownMenuItem(
                    value: '12+ anos',
                    child: Text('12 anos ou mais'),
                  ),
                ],
                onChanged: (value) => provider.updateEscolaridade(value),
                validator: (value) =>
                    (value == null) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _examDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Data do Exame',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _examDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _examDate = pickedDate;
                      _examDateController.text = DateFormat(
                        'dd/MM/yyyy',
                      ).format(pickedDate);
                    });
                  }
                },
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Campo obrigatório'
                    : null,
              ),
            ],
          ),
        ),
      ),
      // Step 1: Orientação Temporal
      Step(
        title: const Text('Orientação Temporal'),
        isActive: _currentStep >= 1,
        content: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildScoreSelector(
                  question: 'Que dia da semana é hoje?',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoTemporal[0],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoTemporal,
                    0,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Que dia do mês é hoje?',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoTemporal[1],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoTemporal,
                    1,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Em qual mês estamos?',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoTemporal[2],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoTemporal,
                    2,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Em qual ano estamos?',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoTemporal[3],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoTemporal,
                    3,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question:
                      'Que horas são, mais ou menos? (Aceite até 1h de diferença)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoTemporal[4],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoTemporal,
                    4,
                    score,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Step 2: Orientação Espacial
      Step(
        title: const Text('Orientação Espacial'),
        isActive: _currentStep >= 2,
        content: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildScoreSelector(
                  question: 'Que lugar é este aqui? (Cômodo - consultório)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoEspacial[0],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoEspacial,
                    0,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question:
                      'Que lugar nós estamos? (Edifício - clínica, hospital)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoEspacial[1],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoEspacial,
                    1,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question:
                      'Que rua ou bairro estamos? (Aceite ponto de referência)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoEspacial[2],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoEspacial,
                    2,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Que cidade estamos?',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoEspacial[3],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoEspacial,
                    3,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Que estado estamos?',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosOrientacaoEspacial[4],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosOrientacaoEspacial,
                    4,
                    score,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Step 3: Memória Imediata
      Step(
        title: const Text('Memória Imediata (Registro)'),
        isActive: _currentStep >= 3,
        content: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInstructionText(
                  "Eu vou falar três palavras. Quero que repita as palavras para mim logo após eu terminar de falar.",
                ),
                _buildInstructionText(
                  "Lembre-se delas, porque vai precisar recordá-las mais a frente.",
                ),
                _buildInstructionText(
                  "(Pontue só se acertar na primeira tentativa. Repita até 3 vezes para aprender).",
                ),
                const SizedBox(height: 16),
                _buildScoreSelector(
                  question: 'Carro',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosMemoriaImediata[0],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosMemoriaImediata,
                    0,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Vaso',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosMemoriaImediata[1],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosMemoriaImediata,
                    1,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Tijolo',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosMemoriaImediata[2],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosMemoriaImediata,
                    2,
                    score,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Step 4: Atenção e Cálculo
      Step(
        title: const Text('Atenção e Cálculo'),
        isActive: _currentStep >= 4,
        content: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScoreSelector(
                  question: 'Quanto é 100 menos 7? (93)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosAtencaoCalculo[0],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosAtencaoCalculo,
                    0,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Quanto é 93 menos 7? (86)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosAtencaoCalculo[1],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosAtencaoCalculo,
                    1,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Quanto é 86 menos 7? (79)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosAtencaoCalculo[2],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosAtencaoCalculo,
                    2,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Quanto é 79 menos 7? (72)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosAtencaoCalculo[3],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosAtencaoCalculo,
                    3,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Quanto é 72 menos 7? (65)',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosAtencaoCalculo[4],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosAtencaoCalculo,
                    4,
                    score,
                  ),
                ),
                _buildExpansionCard(
                  title: 'Distração (Não pontua)',
                  icon: Icons.lightbulb_outline,
                  children: [
                    _buildInstructionText(
                      "Utilizar apenas se o paciente não souber calcular.",
                    ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText(
                        "Soletre a palavra MUNDO ao contrário.",
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText("Soletre seu nome."),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText(
                        "Repita os números na ordem correta e inversa: 1, 5, 7, 3, 2.",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // Step 5: Memória Evocativa
      Step(
        title: const Text('Memória Evocativa'),
        isActive: _currentStep >= 5,
        content: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInstructionText(
                  "Quais palavras você repetiu para mim agora há pouco? (Não precisa ser na mesma sequência)",
                ),
                _buildScoreSelector(
                  question: 'Carro',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosMemoriaEvocativa[0],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosMemoriaEvocativa,
                    0,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Vaso',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosMemoriaEvocativa[1],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosMemoriaEvocativa,
                    1,
                    score,
                  ),
                ),
                _buildScoreSelector(
                  question: 'Tijolo',
                  currentValue: context
                      .watch<MeemFormProvider>()
                      .pontosMemoriaEvocativa[2],
                  onScoreSelected: (score) => provider.updatePontos(
                    provider.pontosMemoriaEvocativa,
                    2,
                    score,
                  ),
                ),
                _buildExpansionCard(
                  title: 'Dicas (Não pontua)',
                  icon: Icons.help_outline,
                  children: [
                    _buildInstructionText(
                      "Utilizar apenas se não lembrar espontaneamente.",
                    ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText(
                        '"Era um meio de transporte"',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText(
                        '"Era carro, moto ou bicicleta?"',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText(
                        '"Era um objeto decorativo"',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText(
                        '"Era quadro, tapete ou vaso?"',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText(
                        '"Era um material de construção"',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInstructionText(
                        '"Era tijolo, martelo ou prego?"',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // Step 6: Linguagem Verbal
      Step(
        title: const Text('Linguagem Verbal'),
        isActive: _currentStep >= 6,
        content: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInstructionTitle('Nomear Objetos (2 pontos)'),
                    _buildInstructionText("O que é isso que estou apontando?"),
                    _buildScoreSelector(
                      question: 'Caneta',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontosLinguagemNomear[0],
                      onScoreSelected: (score) => provider.updatePontos(
                        provider.pontosLinguagemNomear,
                        0,
                        score,
                      ),
                    ),
                    _buildScoreSelector(
                      question: 'Relógio',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontosLinguagemNomear[1],
                      onScoreSelected: (score) => provider.updatePontos(
                        provider.pontosLinguagemNomear,
                        1,
                        score,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInstructionTitle('Repetição (1 ponto)'),
                    _buildScoreSelector(
                      question:
                          'Repita o que vou falar: Nem aqui, nem ali, nem lá.',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontoLinguagemRepetir,
                      onScoreSelected: (score) => provider.updatePontoSimples(
                        score,
                        (s) => provider.pontoLinguagemRepetir = s,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInstructionTitle('Comando Verbal (3 pontos)'),
                    _buildInstructionText(
                      "Faça o que vou pedir: (Coloque um papel no meio da mesa e dê todos os comandos)",
                    ),
                    _buildScoreSelector(
                      question: 'Pegue esse papel com a mão direita',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontosLinguagemComandoVerbal[0],
                      onScoreSelected: (score) => provider.updatePontos(
                        provider.pontosLinguagemComandoVerbal,
                        0,
                        score,
                      ),
                    ),
                    _buildScoreSelector(
                      question: 'Dobre ao meio',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontosLinguagemComandoVerbal[1],
                      onScoreSelected: (score) => provider.updatePontos(
                        provider.pontosLinguagemComandoVerbal,
                        1,
                        score,
                      ),
                    ),
                    _buildScoreSelector(
                      question: 'Coloque no chão',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontosLinguagemComandoVerbal[2],
                      onScoreSelected: (score) => provider.updatePontos(
                        provider.pontosLinguagemComandoVerbal,
                        2,
                        score,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Step 7: Linguagem Escrita e Cópia
      Step(
        title: const Text('Linguagem Escrita e Cópia'),
        isActive: _currentStep >= 7,
        content: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInstructionTitle('Comando Escrito (1 ponto)'),
                    _buildInstructionText("Faça o que está escrito aqui:"),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8, bottom: 16),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Text(
                        'FECHE OS OLHOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    _buildScoreSelector(
                      question: 'Leu e obedeceu ao comando',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontoLinguagemComandoEscrito,
                      onScoreSelected: (score) => provider.updatePontoSimples(
                        score,
                        (s) => provider.pontoLinguagemComandoEscrito = s,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInstructionTitle('Frase Escrita (1 ponto)'),
                    _buildInstructionText("Escreva uma frase para mim:"),
                    _buildScoreSelector(
                      question: 'Escreveu uma frase.',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontoLinguagemFrase,
                      onScoreSelected: (score) => provider.updatePontoSimples(
                        score,
                        (s) => provider.pontoLinguagemFrase = s,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInstructionTitle('Cópia de Desenho (1 ponto)'),
                    _buildInstructionText("Copie este desenho:"),
                    Container(
                      height: 300,
                      width: 500,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: CustomPaint(
                        size: const Size(200, 100),
                        painter: PentagonPainter(),
                      ),
                    ),
                    _buildScoreSelector(
                      question: 'Copiou o desenho corretamente',
                      currentValue: context
                          .watch<MeemFormProvider>()
                          .pontoLinguagemCopia,
                      onScoreSelected: (score) => provider.updatePontoSimples(
                        score,
                        (s) => provider.pontoLinguagemCopia = s,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Step 8: Finalizar
      Step(
        title: const Text('Finalizar'),
        isActive: _currentStep >= 8,
        content: const Text(
          'Revise os dados e clique em "Finalizar" para salvar no banco de dados.',
        ),
      ),
    ];
  }

  void _showResultDialog(MeemFormProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resultado Final do MEEM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pontuação Total: ${provider.totalScore} / 30',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text('Escolaridade: ${provider.escolaridade ?? "Não informada"}'),
            Text('Pontuação Mínima Esperada: ${provider.pontuacaoEsperada}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('FECHAR'),
          ),
        ],
      ),
    );
  }
}
