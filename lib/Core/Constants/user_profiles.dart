class UserProfiles {
  static const String defaultLabel = 'Fisioterapeuta';

  static const List<String> labels = [
    'Administrador',
    'Fisioterapeuta',
    'Estagiário/Pesquisador',
    'Paciente',
  ];

  static const Map<String, String> valuesByLabel = {
    'Administrador': 'admin',
    'Fisioterapeuta': 'fisioterapeuta',
    'Estagiário/Pesquisador': 'estagiario',
    'Paciente': 'paciente',
  };

  static String valueFor(String label) => valuesByLabel[label] ?? label;
}
