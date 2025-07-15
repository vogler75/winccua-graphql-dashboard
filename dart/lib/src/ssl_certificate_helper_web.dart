import 'package:http/http.dart' as http;

class SslCertificateHelper {
  static http.Client? createHttpClient(bool ignoreSslCertificateErrors) {
    // For web, we can't control SSL certificate validation
    // The browser handles SSL certificates, and we can't bypass them programmatically
    return null;
  }

  static void setupSslCertificateBypass() {
    // No-op for web - SSL certificate handling is managed by the browser
  }

  static void restoreHttpOverrides([dynamic originalOverrides]) {
    // No-op for web
  }
}