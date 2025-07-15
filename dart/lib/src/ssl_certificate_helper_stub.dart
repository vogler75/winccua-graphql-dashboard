import 'package:http/http.dart' as http;

class SslCertificateHelper {
  static http.Client? createHttpClient(bool ignoreSslCertificateErrors) {
    return null;
  }

  static void setupSslCertificateBypass() {
    // No-op for unsupported platforms
  }

  static void restoreHttpOverrides([dynamic originalOverrides]) {
    // No-op for unsupported platforms
  }
}