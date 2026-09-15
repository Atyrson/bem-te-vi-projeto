import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:projeto/Core/Config/api_config.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';

typedef PatientLoader = Future<List<dynamic>> Function();

class PatientSearchDialog extends StatefulWidget {
  final PatientLoader? loadPatients;

  const PatientSearchDialog({super.key, this.loadPatients});

  @override
  State<PatientSearchDialog> createState() => _PatientSearchDialogState();
}

class _PatientSearchDialogState extends State<PatientSearchDialog> {
  final _searchController = TextEditingController();

  List<dynamic> _allPatients = [];
  List<dynamic> _filteredPatients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      final data = widget.loadPatients == null
          ? await _loadPatientsFromApi()
          : await widget.loadPatients!();
      if (!mounted) return;
      setState(() {
        _allPatients = data;
        _filteredPatients = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Erro de conexão: $e");
    }
  }

  Future<List<dynamic>> _loadPatientsFromApi() async {
    final response = await http.get(ApiConfig.endpoint('patients'));
    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar pacientes: ${response.statusCode}');
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  void _filterList(String query) {
    setState(() {
      _filteredPatients = _allPatients.where((patient) {
        final name = patient['nome_completo'].toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5EAEA),
          borderRadius: BorderRadius.circular(16),
        ),
        height: 400,
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.cancel_outlined,
                  size: 28,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _searchController,
              onChanged: _filterList,
              decoration: InputDecoration(
                hintText: "Digite o nome do paciente...",
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2E7D32),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredPatients.length,
                        separatorBuilder: (ctx, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final patient = _filteredPatients[index];
                          return ListTile(
                            title: Text(
                              patient['nome_completo'],
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            onTap: () {
                              print("Selecionado: ${patient['nome_completo']}");

                              final patientProvider =
                                  Provider.of<PatientProvider>(
                                    context,
                                    listen: false,
                                  );
                              patientProvider.setPatient(patient);
                              if (patientProvider.id == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Não foi possível selecionar este paciente: ID não informado.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final navigator = Navigator.of(context);
                              Navigator.pop(context);
                              navigator.pushNamed('/anamnese_form');
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
