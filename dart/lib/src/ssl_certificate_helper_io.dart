import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http;

class _SslCertificateBypassOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class SslCertificateHelper {
  static HttpOverrides? _originalHttpOverrides;

  static http.Client? createHttpClient(bool ignoreSslCertificateErrors) {
    if (ignoreSslCertificateErrors) {
      return http.IOClient(
        HttpClient()
          ..badCertificateCallback = (X509Certificate cert, String host, int port) => true,
      );
    }
    return null;
  }

  static void setupSslCertificateBypass() {
    _originalHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _SslCertificateBypassOverride();
  }

  static void restoreHttpOverrides([dynamic originalOverrides]) {
    HttpOverrides.global = _originalHttpOverrides;
  }
}