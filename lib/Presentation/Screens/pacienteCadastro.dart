import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projeto/Core/Config/api_config.dart';

class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _cpfController = TextEditingController();
  final _rgController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Emergência
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String? _selectedSex;
  DateTime? _dateOfBirth;
  bool _isLoading = false;

  String? _optionalText(String text) {
    final value = text.trim();
    return value.isEmpty ? null : value;
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
        if (detail is List) {
          final fields = <String>{};
          const labels = {
            'nome_completo': 'nome completo',
            'data_nascimento': 'data de nascimento',
            'peso': 'peso',
            'altura': 'altura',
            'cpf': 'CPF',
            'rg': 'RG',
            'sexo': 'sexo',
            'telefone': 'telefone',
            'email': 'e-mail',
            'emergencia_nome': 'nome do contato de emergência',
            'emergencia_telefone': 'telefone do contato de emergência',
          };
          for (final error in detail) {
            if (error is Map && error['loc'] is List) {
              final location = error['loc'] as List;
              if (location.isNotEmpty) {
                final field = location.last.toString();
                fields.add(labels[field] ?? field);
              }
            }
          }
          if (fields.isNotEmpty) {
            return 'Confira os campos: ${fields.join(', ')}.';
          }
          return 'Confira os dados informados e tente novamente.';
        }
      }
    } on FormatException {
      // Respostas sem JSON ainda devem mostrar um erro útil.
    }
    return 'Erro ao salvar paciente (HTTP ${response.statusCode}).';
  }

  Future<void> _registerPatient() async {
    final missingFields = <String>[
      if (_nameController.text.trim().isEmpty) 'nome completo',
      if (_dateOfBirth == null) 'data de nascimento',
      if (_selectedSex == null) 'sexo',
      if (_cpfController.text.trim().isEmpty) 'CPF',
    ];
    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preencha os campos obrigatórios: ${missingFields.join(', ')}.',
          ),
        ),
      );
      return;
    }

    final weightText = _weightController.text.trim();
    final heightText = _heightController.text.trim();
    final weight = weightText.isEmpty
        ? null
        : double.tryParse(weightText.replaceAll(',', '.'));
    final height = heightText.isEmpty
        ? null
        : double.tryParse(heightText.replaceAll(',', '.'));
    if ((weightText.isNotEmpty &&
            (weight == null || !weight.isFinite || weight <= 0)) ||
        (heightText.isNotEmpty &&
            (height == null || !height.isFinite || height <= 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe peso e altura válidos.')),
      );
      return;
    }

    final body = jsonEncode({
      "nome_completo": _nameController.text.trim(),
      "data_nascimento": _dateOfBirth?.toIso8601String().substring(0, 10),
      "peso": weight,
      "altura": height,
      "cpf": _optionalText(_cpfController.text),
      "rg": _optionalText(_rgController.text),
      "sexo": _selectedSex,
      "telefone": _optionalText(_phoneController.text),
      "email": _optionalText(_emailController.text),
      "emergencia_nome": _optionalText(_emergencyNameController.text),
      "emergencia_telefone": _optionalText(_emergencyPhoneController.text),
    });

    setState(() => _isLoading = true);
    late final http.Response response;
    try {
      response =
          await (widget.client?.post(
                ApiConfig.endpoint('patients'),
                headers: {"Content-Type": "application/json"},
                body: body,
              ) ??
              http.post(
                ApiConfig.endpoint('patients'),
                headers: {"Content-Type": "application/json"},
                body: body,
              ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível conectar à API.')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Paciente salvo com sucesso!"),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(_errorMessage(response)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          "Dados do Paciente",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('* Campos obrigatórios'),
            const SizedBox(height: 12),
            _buildLabel("Nome Completo *"),
            _buildGreenTextField(controller: _nameController),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Data de nascimento *"),
                      _buildGreenTextField(
                        controller: _dobController,
                        isDate: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Sexo *"),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: const Color(0xFF4CAF50),
                            value: _selectedSex,
                            hint: const Text(
                              "Selecione",
                              style: TextStyle(color: Colors.white),
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                            items: ['Masculino', 'Feminino', 'Outro'].map((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedSex = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Peso e Altura
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Peso (kg)"),
                      _buildGreenTextField(
                        controller: _weightController,
                        isNumber: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Altura (cm)"),
                      _buildGreenTextField(
                        controller: _heightController,
                        isNumber: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CPF e RG
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("CPF *"),
                      _buildGreenTextField(
                        controller: _cpfController,
                        isNumber: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("RG"),
                      _buildGreenTextField(
                        controller: _rgController,
                        isNumber: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildLabel("Telefone"),
            _buildGreenTextField(controller: _phoneController, isNumber: true),
            const SizedBox(height: 16),

            _buildLabel("E-mail"),
            _buildGreenTextField(controller: _emailController),

            const SizedBox(height: 24),
            const Divider(thickness: 1.5),
            const SizedBox(height: 16),

            const Text(
              "Contato de Emergência",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildLabel("Nome"),
            _buildGreenTextField(controller: _emergencyNameController),
            const SizedBox(height: 16),

            _buildLabel("Telefone"),
            _buildGreenTextField(
              controller: _emergencyPhoneController,
              isNumber: true,
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerPatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Cadastrar", style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }

  Widget _buildGreenTextField({
    required TextEditingController controller,
    bool isNumber = false,
    bool isDate = false,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        readOnly: isDate,
        onTap: isDate
            ? () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null && mounted) {
                  setState(() {
                    _dateOfBirth = pickedDate;
                    controller.text =
                        '${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}';
                  });
                }
              }
            : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF4CAF50),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
        ),
      ),
    );
  }
}
