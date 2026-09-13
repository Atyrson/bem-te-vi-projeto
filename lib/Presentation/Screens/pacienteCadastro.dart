import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projeto/Core/Config/api_config.dart';

class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key});

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
  bool _isLoading = false;

  // --- FUNÇÃO PARA SALVAR NO BACKEND ---
  Future<void> _registerPatient() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("O nome é obrigatório!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Formatar Data (De 25/12/2000 para 2000-12-25)
      String? formattedDate;
      if (_dobController.text.isNotEmpty && _dobController.text.contains('/')) {
        final parts = _dobController.text.split('/');
        if (parts.length == 3) {
          formattedDate = "${parts[2]}-${parts[1]}-${parts[0]}";
        }
      }

      final url = ApiConfig.endpoint('patients');

      // 3. Montar JSON
      final body = jsonEncode({
        "nome_completo": _nameController.text,
        "data_nascimento": formattedDate,
        "peso": double.tryParse(_weightController.text),
        "altura": double.tryParse(_heightController.text),
        "cpf": _cpfController.text,
        "rg": _rgController.text,
        "sexo": _selectedSex,
        "telefone": _phoneController.text,
        "email": _emailController.text,
        "emergencia_nome": _emergencyNameController.text,
        "emergencia_telefone": _emergencyPhoneController.text,
      });

      // 4. Enviar
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text("Paciente salvo com sucesso!"),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          final msg = jsonDecode(response.body)['detail'] ?? "Erro ao salvar";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text(msg)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro de conexão: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
            _buildLabel("Nome Completo"),
            _buildGreenTextField(controller: _nameController),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Data de nascimento"),
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
                      _buildLabel("Sexo"),
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
                      _buildLabel("CPF"),
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
                if (pickedDate != null) {
                  setState(() {
                    controller.text =
                        "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
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
