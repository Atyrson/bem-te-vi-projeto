import 'package:flutter/material.dart';

class PatientProvider extends ChangeNotifier {
  // Guarda o JSON completo vindo do banco de dados
  Map<String, dynamic>? _patientData;

  Map<String, dynamic>? get patientData => _patientData;

  // --- GETTERS SIMPLES (Dados Diretos) ---
  int? get id {
    final value = _patientData?['id'];
    if (value is int) return value;
    if (value is num && value == value.round()) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? get nome => _patientData?['nome_completo']?.toString();

  // Tratamento para garantir que números venham certos (int ou double)
  double? get peso => (_patientData?['peso'] as num?)?.toDouble();
  double? get altura => (_patientData?['altura'] as num?)?.toDouble();

  String? get cpf => _patientData?['cpf'];
  String? get rg => _patientData?['rg'];
  String? get sexo => _patientData?['sexo'];
  String? get telefone => _patientData?['telefone'];
  String? get email => _patientData?['email'];
  String? get dataNascimento =>
      _patientData?['data_nascimento']; // String "YYYY-MM-DD"

  // Dados de Emergência
  String? get emergenciaNome => _patientData?['emergencia_nome'];
  String? get emergenciaTelefone => _patientData?['emergencia_telefone'];

  // --- CÁLCULO DA IDADE (AQUI ESTÁ A CORREÇÃO) ---
  int? get idade {
    final dobString = _patientData?['data_nascimento'];

    // Se não tem data de nascimento, não tem idade
    if (dobString == null || dobString.isEmpty) return null;

    try {
      // O Python manda "YYYY-MM-DD", o Dart entende esse formato nativamente
      DateTime birthDate = DateTime.parse(dobString);
      DateTime today = DateTime.now();

      int age = today.year - birthDate.year;

      // Ajuste fino: Se ainda não fez aniversário este ano, diminui 1
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      return age;
    } catch (e) {
      print("Erro ao calcular idade no Provider: $e");
      return null;
    }
  }

  // --- AÇÕES ---
  void setPatient(Map<String, dynamic> data) {
    // A seleção é uma fotografia do registro retornado pela API. Assim, uma
    // lista reutilizada ou uma mutação posterior não altera o contexto ativo.
    _patientData = Map<String, dynamic>.from(data);
    notifyListeners();
  }

  void clearPatient() {
    _patientData = null;
    notifyListeners();
  }
}
