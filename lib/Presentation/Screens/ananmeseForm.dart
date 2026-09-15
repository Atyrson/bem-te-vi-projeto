import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:projeto/Core/Constants/appStrings.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Core/Services/api_service.dart';
import 'package:projeto/Presentation/CommonWidgets/appDrawer.dart';
import 'package:projeto/Presentation/CommonWidgets/customTextField.dart';
import 'package:provider/provider.dart';

class AnmeneseForm extends StatefulWidget {
  const AnmeneseForm({super.key});

  @override
  State<AnmeneseForm> createState() => _AnmeneseFormState();
}

class _AnmeneseFormState extends State<AnmeneseForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _patientNameController = TextEditingController();
  final _patientCelController = TextEditingController();
  final _patientEmailController = TextEditingController();
  final _comentsController = TextEditingController();
  final _examDateController = TextEditingController();
  final _patientBornDateController = TextEditingController();

  DateTime? _examDate;
  DateTime? _patientBornDate;

  @override
  void initState() {
    super.initState();

    // Preencher dados automaticamente se houver paciente selecionado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      // DEBUG: Verifique no console se os dados estão aparecendo aqui
      print("DEBUG ANAMNESE - Nome: ${patientProvider.nome}");
      print("DEBUG ANAMNESE - Tel: ${patientProvider.telefone}");
      print("DEBUG ANAMNESE - Data: ${patientProvider.dataNascimento}");

      if (patientProvider.nome != null) {
        setState(() {
          _patientNameController.text = patientProvider.nome!;
          _patientCelController.text = patientProvider.telefone ?? '';
          _patientEmailController.text = patientProvider.email ?? '';

          // Converter Data de Nascimento (YYYY-MM-DD para DateTime e Texto)
          if (patientProvider.dataNascimento != null) {
            try {
              _patientBornDate = DateTime.parse(
                patientProvider.dataNascimento!,
              );
              _patientBornDateController.text = DateFormat(
                'dd/MM/yyyy',
              ).format(_patientBornDate!);
            } catch (e) {
              print("Erro ao converter data: $e");
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientCelController.dispose();
    _patientEmailController.dispose();
    _comentsController.dispose();
    _examDateController.dispose();
    _patientBornDateController.dispose();
    super.dispose();
  }

  final ApiService _apiService = ApiService();

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.submitAnamnesis(
        patientName: _patientNameController.text,
        patientPhone: _patientCelController.text,
        patientEmail: _patientEmailController.text,
        examDate: _examDate!,
        birthDate: _patientBornDate!,
        comments: _comentsController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anamnese salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Precisamos acessar o provider aqui no build para usar nas Keys
    final provider = Provider.of<PatientProvider>(context);

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
        title: const Text(AppStrings.anmeneseTitle),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Passamos o provider para o widget filho
                _buildPatientDates(provider),
                const SizedBox(height: 24),
                _buildComentsArea(),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _saveForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Salvar Anamnese',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  icon: const Icon(Icons.history_outlined),
                  label: const Text('Abrir histórico CIF'),
                  onPressed: () {
                    Navigator.pushNamed(context, '/cif_history');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emerald,
                    side: const BorderSide(color: AppColors.emerald, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientDates(PatientProvider provider) {
    return Card(
      color: AppColors.emerald,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    // KEY para forçar atualização do Nome
                    key: Key(provider.nome ?? 'nome_field'),
                    controller: _patientNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nome Completo do Paciente',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.person, color: Colors.white),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira o nome.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _examDateController,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Data do exame',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                      ),
                    ),
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _examDate ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2101),
                        locale: const Locale('pt', 'BR'),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecione a data do exame.';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    // KEY para forçar atualização do Celular
                    key: Key(provider.telefone ?? 'cel_field'),
                    controller: _patientCelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Celular do paciente',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.phone, color: Colors.white),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira o celular.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    // KEY para forçar atualização do Email
                    key: Key(provider.email ?? 'email_field'),
                    controller: _patientEmailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Email do paciente',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.email, color: Colors.white),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira o email.';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Por favor, insira um email válido.';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              // KEY para forçar atualização da Data de Nascimento
              key: Key(provider.dataNascimento ?? 'nasc_field'),
              controller: _patientBornDateController,
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Data de nascimento do paciente',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                prefixIcon: Icon(Icons.cake, color: Colors.white),
              ),
              onTap: () async {
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _patientBornDate ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  locale: const Locale('pt', 'BR'),
                );

                if (pickedDate != null) {
                  setState(() {
                    _patientBornDate = pickedDate;
                    _patientBornDateController.text = DateFormat(
                      'dd/MM/yyyy',
                    ).format(pickedDate);
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Selecione a data de nascimento.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComentsArea() {
    return Card(
      color: AppColors.emerald,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomTextField(
          controller: _comentsController,
          labelText: 'Anotações, queixas e informações adicionais...',
          maxLines: 30,
          textColor: Colors.white,
          labelColor: Colors.white70,
          cursorColor: Colors.white,
          borderColor: Colors.white54,
        ),
      ),
    );
  }
}
