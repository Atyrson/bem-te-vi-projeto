import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projeto/Core/Constants/appStrings.dart';
import 'package:projeto/Core/Config/api_config.dart';
import 'package:projeto/Core/Providers/eletroFormProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/CommonWidgets/appDrawer.dart';
import 'package:provider/provider.dart';

class EletrodiagnosticoScreen extends StatelessWidget {
  const EletrodiagnosticoScreen({super.key});

  Widget _buildMeasurementField(
    TextEditingController controller, {
    Function(String)? onChanged,
  }) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.center,
        cursorColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCalculatedValue(String value) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMuscleTableRow({
    required BuildContext context,
    required String muscleName,
    required MuscleData data,
  }) {
    List<Widget> centerLabels = [
      _buildLabel('Reobase (mA)'),
      _buildLabel('Cronaxia (µs)'),
      _buildLabel('Acomodação (mA)'),
      _buildLabel('Índice de Acomodação'),
    ];

    final rightInputs = [
      _buildMeasurementField(data.reobaseDireito),
      _buildMeasurementField(data.cronaxiaDireito),
      _buildMeasurementField(data.acomodacaoDireito),
      _buildCalculatedValue(data.indiceAcomodacaoDireito),
    ];

    final leftInputs = [
      _buildMeasurementField(data.reobaseEsquerdo),
      _buildMeasurementField(data.cronaxiaEsquerdo),
      _buildMeasurementField(data.acomodacaoEsquerdo),
      _buildCalculatedValue(data.indiceAcomodacaoEsquerdo),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
          child: Text(
            muscleName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Card(
          color: AppColors.emerald,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // COLUNA DIREITA
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Direito',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Divider(color: Colors.white),
                        ...rightInputs
                            .expand((w) => [w, const SizedBox(height: 8)])
                            .toList()
                          ..removeLast(),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                    width: 24,
                    thickness: 1,
                    color: Colors.white,
                  ),
                  // COLUNA CENTRAL
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 32),
                        ...centerLabels
                            .expand((w) => [w, const SizedBox(height: 8)])
                            .toList()
                          ..removeLast(),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                    width: 24,
                    thickness: 1,
                    color: Colors.white,
                  ),
                  // COLUNA ESQUERDA
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Esquerdo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Divider(color: Colors.white),
                        ...leftInputs
                            .expand((w) => [w, const SizedBox(height: 8)])
                            .toList()
                          ..removeLast(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Campo de observações
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Card(
            color: AppColors.emerald,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Observações',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Divider(color: Colors.white),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: data.observacoesController,
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Digite suas observações aqui...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EletrodiagnosticoProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final patientGlobal = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      if (patientGlobal.nome != null &&
          provider.pacienteController.text.isEmpty) {
        provider.pacienteController.text = patientGlobal.nome!;
      }
    });
    final muscleData = provider.muscleDataMap;

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
        title: const Text('Teste de Eletrodiagnóstico'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(provider),
            const SizedBox(height: 16),
            ...muscleData.entries
                .map(
                  (entry) => _buildMuscleTableRow(
                    context: context,
                    muscleName: entry.key,
                    data: entry.value,
                  ),
                )
                .expand((w) => [w, const SizedBox(height: 16)])
                .toList(),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                final apiUrl = ApiConfig.endpoint(
                  'electrodiagnosis',
                ).toString();

                final provider = context.read<EletrodiagnosticoProvider>();

                final String jsonData = provider.formatForApi();

                if (kDebugMode) {
                  print("Enviando JSON para a API ($apiUrl):");
                  print(jsonData);
                }

                // 3. Mostrar um diálogo de "carregando"
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  // 4. Enviar os dados para a API
                  final response = await http.post(
                    ApiConfig.endpoint('electrodiagnosis'),
                    headers: {
                      'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: jsonData,
                  );

                  // 5. Fechar o diálogo de "carregando"
                  if (!context.mounted) return;
                  Navigator.of(context).pop();

                  // 6. Checar a resposta da API
                  if (response.statusCode == 201) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Avaliação salva com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    provider.clearForm();
                  } else {
                    if (kDebugMode) {
                      print('Erro da API: ${response.statusCode}');
                      print('Corpo da resposta: ${response.body}');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao salvar: ${response.statusCode}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  // 7. Lidar com erros de rede (ex: sem internet, API desligada)
                  if (context.mounted) Navigator.of(context).pop();
                  if (kDebugMode) print('Erro de conexão: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro de conexão. A API está ligada? $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                'SALVAR AVALIAÇÃO',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

Widget _buildHeaderCard(EletrodiagnosticoProvider provider) {
  return Card(
    color: AppColors.emerald,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextFieldWithIcon(
            icon: Icons.person_outline,
            controller: provider.pacienteController,
            hint: 'Paciente',
          ),
          const SizedBox(height: 12),
          _buildTextFieldWithIcon(
            icon: Icons.person_outline,
            controller: provider.avaliadorController,
            hint: 'Avaliador',
          ),
          const SizedBox(height: 12),
          _buildTextFieldWithIcon(
            icon: Icons.calendar_today_outlined,
            controller: provider.dataController,
            hint: 'Data',
          ),
          const SizedBox(height: 12),
          _buildTextFieldWithIcon(
            icon: Icons.monitor_heart_outlined,
            controller: provider.equipamentoController,
            hint: 'Equipamento',
          ),
        ],
      ),
    ),
  );
}

Widget _buildTextFieldWithIcon({
  required IconData icon,
  required TextEditingController controller,
  required String hint,
}) {
  return Row(
    children: [
      Icon(icon, color: Colors.white),
      const SizedBox(width: 10),
      Expanded(
        child: TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ),
    ],
  );
}
