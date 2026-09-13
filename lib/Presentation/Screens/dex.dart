import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:projeto/Core/Constants/appStrings.dart';
import 'package:projeto/Core/Config/api_config.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/CommonWidgets/appDrawer.dart';

class RegionData {
  final String name;
  final TextEditingController controller = TextEditingController();
  RegionData(this.name);
}

class TrendData {
  final TextEditingController dateCtrl = TextEditingController();
  final TextEditingController ageCtrl = TextEditingController();
  final TextEditingController bmdCtrl = TextEditingController();
  DateTime? selectedDate;
}

class CompositionData {
  final TextEditingController dateCtrl = TextEditingController();
  final TextEditingController ageCtrl = TextEditingController();
  final TextEditingController tecidoCtrl = TextEditingController();
  final TextEditingController massaTotalCtrl = TextEditingController();
  final TextEditingController gordoCtrl = TextEditingController();
  final TextEditingController magroCtrl = TextEditingController();
  DateTime? selectedDate;
}

class DensitometryFormPage extends StatefulWidget {
  const DensitometryFormPage({super.key});

  @override
  State<DensitometryFormPage> createState() => _DensitometryFormPageState();
}

class _DensitometryFormPageState extends State<DensitometryFormPage> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  String _imcResult = "";
  bool _isLoading = false;

  late List<RegionData> lumbarList;
  late TrendData lumbarTrend;

  late List<RegionData> bodyList;
  late TrendData bodyTrend;

  late CompositionData compositionTrend;

  late List<RegionData> femurRightList;
  late TrendData femurRightTrend;

  late List<RegionData> femurLeftList;
  late TrendData femurLeftTrend;

  @override
  void initState() {
    super.initState();
    _initData();
    _loadPatient();
  }

  void _initData() {
    lumbarList = [
      'L1',
      'L2',
      'L3',
      'L4',
      'L1-L2',
      'L1-L3',
      'L1-L4',
      'L2-L3',
      'L2-L4',
      'L3-L4',
    ].map((e) => RegionData(e)).toList();
    lumbarTrend = TrendData();

    bodyList = [
      'Cabeça',
      'Braços',
      'Pernas',
      'Tronco',
      'Costelas',
      'Coluna',
      'Pelve',
      'Total',
    ].map((e) => RegionData(e)).toList();
    bodyTrend = TrendData();

    compositionTrend = CompositionData();

    femurRightList = ['Colo', 'Total'].map((e) => RegionData(e)).toList();
    femurRightTrend = TrendData();

    femurLeftList = ['Colo', 'Total'].map((e) => RegionData(e)).toList();
    femurLeftTrend = TrendData();
  }

  void _loadPatient() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Provider.of<PatientProvider>(context, listen: false);
      if (p.nome != null) {
        setState(() {
          if (p.peso != null) _weightController.text = p.peso.toString();
          if (p.altura != null) _heightController.text = p.altura.toString();
          if (_weightController.text.isNotEmpty &&
              _heightController.text.isNotEmpty)
            _calculateIMC();
        });
      }
    });
  }

  // --- LÓGICA DE ENVIO PARA O BACKEND ---
  Future<void> _saveExam() async {
    setState(() => _isLoading = true);

    try {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      final url = ApiConfig.endpoint('densitometry');

      // 2. Montagem do JSON
      final body = jsonEncode({
        "patientName": patientProvider.nome ?? "Paciente Teste",
        "examDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
        "weight":
            double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0.0,
        "height":
            double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 0.0,
        "imc": double.tryParse(_imcResult.replaceAll("IMC: ", "")) ?? 0.0,

        // Enviando as listas preenchidas
        "lumbarRegions": lumbarList
            .map((e) => {"regiao": e.name, "bmd": _toDouble(e.controller)})
            .toList(),
        "lumbarTrend": _trendToMap(lumbarTrend),

        "bodyRegions": bodyList
            .map((e) => {"regiao": e.name, "bmd": _toDouble(e.controller)})
            .toList(),
        "bodyTrend": _trendToMap(bodyTrend),

        "compositionTrend": {
          "data": _dateToString(compositionTrend.selectedDate),
          "idade": int.tryParse(compositionTrend.ageCtrl.text) ?? 0,
          "tecido_percent": _toDouble(compositionTrend.tecidoCtrl),
          "massa_total": _toDouble(compositionTrend.massaTotalCtrl),
          "gordo": _toDouble(compositionTrend.gordoCtrl),
          "magro": _toDouble(compositionTrend.magroCtrl),
        },

        "femurRightRegions": femurRightList
            .map((e) => {"regiao": e.name, "bmd": _toDouble(e.controller)})
            .toList(),
        "femurRightTrend": _trendToMap(femurRightTrend),

        "femurLeftRegions": femurLeftList
            .map((e) => {"regiao": e.name, "bmd": _toDouble(e.controller)})
            .toList(),
        "femurLeftTrend": _trendToMap(femurLeftTrend),
      });

      // 3. Envio HTTP
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Salvo com sucesso!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erro: ${response.body}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro conexão: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helpers para limpar o código acima
  double _toDouble(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;
  String _dateToString(DateTime? d) => d != null
      ? DateFormat('yyyy-MM-dd').format(d)
      : DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, dynamic> _trendToMap(TrendData t) => {
    "data": _dateToString(t.selectedDate),
    "idade": int.tryParse(t.ageCtrl.text) ?? 0,
    "bmd": _toDouble(t.bmdCtrl),
  };

  void _calculateIMC() {
    double? weight = double.tryParse(
      _weightController.text.replaceAll(',', '.'),
    );
    double? height = double.tryParse(
      _heightController.text.replaceAll(',', '.'),
    );
    if (weight != null && height != null && height > 0) {
      if (height > 3) height = height / 100;
      double imc = weight / (height * height);
      setState(() => _imcResult = "IMC: ${imc.toStringAsFixed(2)}");
    }
  }

  final roundedInputDecoration = InputDecoration(
    filled: true,
    fillColor: AppColors.emerald,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: Colors.white),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: Colors.white, width: 2),
    ),
    labelStyle: const TextStyle(color: Colors.white),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
            ),
          ),
        ),
      ),
      drawer: AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(title: "1. Dados do Paciente & IMC"),
                  Card(
                    color: AppColors.emerald,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _weightController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: roundedInputDecoration.copyWith(
                                    labelText: 'Peso (kg)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _heightController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: roundedInputDecoration.copyWith(
                                    labelText: 'Altura (m)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: _calculateIMC,
                              child: const Text(
                                "Calcular IMC",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          if (_imcResult.isNotEmpty) ...[
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                _imcResult,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const SectionTitle(title: "2. Coluna Lombar"),
                  RegionTableWidget(dataList: lumbarList),
                  const SizedBox(height: 5),
                  TrendTableWidget(
                    label: "Tendência: L1-L4",
                    data: lumbarTrend,
                  ),
                  const SizedBox(height: 24),

                  const SectionTitle(title: "3. Densitometria (Corpo Inteiro)"),
                  RegionTableWidget(dataList: bodyList),
                  const SizedBox(height: 5),
                  TrendTableWidget(
                    label: "Tendência: Total (Análise optimizada)",
                    data: bodyTrend,
                  ),
                  const SizedBox(height: 24),

                  const SectionTitle(
                    title: "3.1. Tendência: Composição Corporal",
                  ),
                  CompositionTrendWidget(data: compositionTrend),
                  const SizedBox(height: 24),

                  const SectionTitle(title: "4. Fêmur (Direito)"),
                  RegionTableWidget(dataList: femurRightList),
                  const SizedBox(height: 5),
                  TrendTableWidget(
                    label: "Tendência: Total",
                    data: femurRightTrend,
                  ),
                  const SizedBox(height: 30),

                  const SectionTitle(title: "5. Fêmur (Esquerdo)"),
                  RegionTableWidget(dataList: femurLeftList),
                  const SizedBox(height: 5),
                  TrendTableWidget(
                    label: "Tendência: Total",
                    data: femurLeftTrend,
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 6, 190, 123),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _saveExam,
                      child: const Text(
                        "Salvar Exame",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}

class RegionTableWidget extends StatelessWidget {
  final List<RegionData> dataList;
  const RegionTableWidget({super.key, required this.dataList});

  @override
  Widget build(BuildContext context) {
    final tableInputDecoration = InputDecoration(
      filled: true,
      fillColor: AppColors.emerald,
      contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: const BorderSide(color: Colors.white),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
    );

    return Card(
      color: AppColors.emerald,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(15),
          bottom: Radius.circular(5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Região',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        'BMD (g/cm²)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white54, height: 1),
            ...dataList
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              controller: item.controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                              decoration: tableInputDecoration,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }
}

class TrendTableWidget extends StatelessWidget {
  final String label;
  final TrendData data;

  const TrendTableWidget({super.key, required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    final tableInputDecoration = InputDecoration(
      filled: true,
      fillColor: AppColors.emerald,
      contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: const BorderSide(color: Colors.white),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
    );

    return Card(
      color: AppColors.emerald,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(5),
          bottom: Radius.circular(15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      'Data Medido',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Idade',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'BMD (g/cm²)',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: DateSelectorInput(
                      controller: data.dateCtrl,
                      decoration: tableInputDecoration,
                      onDateSelected: (d) => data.selectedDate = d,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: TextFormField(
                      controller: data.ageCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                      decoration: tableInputDecoration,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: TextFormField(
                      controller: data.bmdCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                      decoration: tableInputDecoration,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CompositionTrendWidget extends StatelessWidget {
  final CompositionData data;

  const CompositionTrendWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final tableInputDecoration = InputDecoration(
      filled: true,
      fillColor: AppColors.emerald,
      contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: const BorderSide(color: Colors.white),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
    );
    const double dateWidth = 110, smallWidth = 60, mediumWidth = 90;

    return Card(
      color: AppColors.emerald,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _header("Data", dateWidth),
                  const SizedBox(width: 8),
                  _header("Idade", smallWidth),
                  const SizedBox(width: 8),
                  _header("Tecido\n(%Gordura)", mediumWidth),
                  const SizedBox(width: 8),
                  _header("Massa Total\n(kg)", mediumWidth),
                  const SizedBox(width: 8),
                  _header("Gordo\n(g)", mediumWidth),
                  const SizedBox(width: 8),
                  _header("Magro\n(g)", mediumWidth),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: dateWidth,
                    height: 40,
                    child: DateSelectorInput(
                      controller: data.dateCtrl,
                      decoration: tableInputDecoration,
                      onDateSelected: (d) => data.selectedDate = d,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: smallWidth,
                    height: 40,
                    child: _input(data.ageCtrl, tableInputDecoration),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: mediumWidth,
                    height: 40,
                    child: _input(data.tecidoCtrl, tableInputDecoration),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: mediumWidth,
                    height: 40,
                    child: _input(data.massaTotalCtrl, tableInputDecoration),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: mediumWidth,
                    height: 40,
                    child: _input(data.gordoCtrl, tableInputDecoration),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: mediumWidth,
                    height: 40,
                    child: _input(data.magroCtrl, tableInputDecoration),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String t, double w) => SizedBox(
    width: w,
    child: Center(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
  Widget _input(TextEditingController c, InputDecoration d) => TextFormField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textAlign: TextAlign.center,
    style: const TextStyle(color: Colors.white),
    decoration: d,
  );
}

class DateSelectorInput extends StatelessWidget {
  final InputDecoration decoration;
  final TextEditingController controller;
  final Function(DateTime) onDateSelected;
  const DateSelectorInput({
    super.key,
    required this.decoration,
    required this.controller,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: decoration.copyWith(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2101),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.emerald,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
        if (d != null) {
          onDateSelected(d);
          controller.text = DateFormat('dd/MM/yyyy').format(d);
        }
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    ),
  );
}
