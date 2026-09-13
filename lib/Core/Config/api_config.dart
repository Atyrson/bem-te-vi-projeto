/// Configuração central do endereço da API do Bem-Te-Vi.
///
/// O valor pode ser substituído no build com:
/// `--dart-define=API_BASE_URL=http://<ip-do-computador>:8000/api/v1`
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static Uri endpoint(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$normalizedBase/$normalizedPath');
  }
}
