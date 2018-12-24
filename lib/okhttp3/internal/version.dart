import 'dart:io';

class Version {
  Version._();

  static String userAgent() {
    String version = Platform.version;
    // Only include major and minor version numbers.
    int index = version.indexOf('.', version.indexOf('.') + 1);
    version = version.substring(0, index);
    return 'okhttp/3.10.0 Dart/$version (dart:io)';
  }
}
