import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:projeto/Core/Config/api_config.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';

class PatientSearchDialog extends StatefulWidget {
  const PatientSearchDialog({super.key});

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
      final url = ApiConfig.endpoint('patients');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allPatients = data;
          _filteredPatients = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        print("Erro ao buscar pacientes: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Erro de conexão: $e");
    }
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

                              Provider.of<PatientProvider>(
                                context,
                                listen: false,
                              ).setPatient(patient);
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/asia_form');
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
