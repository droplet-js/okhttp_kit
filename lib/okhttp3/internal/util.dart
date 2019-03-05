import 'package:fake_http/okhttp3/http_url.dart';
import 'package:fake_http/okhttp3/io/closeable.dart';
import 'package:fake_http/okhttp3/request_body.dart';
import 'package:fake_http/okhttp3/response_body.dart';

class Util {
  Util._();

  static final ResponseBody EMPTY_RESPONSE =
      ResponseBody.bytesBody(null, <int>[]);
  static final RequestBody EMPTY_REQUEST = RequestBody.bytesBody(null, <int>[]);

  static String hostHeader(HttpUrl url, bool includeDefaultPort) {
    String host = url.host().contains(':') ? '[${url.host()}]' : url.host();
    return includeDefaultPort || url.port() != HttpUrl.defaultPort(url.scheme())
        ? '$host:${url.port()}'
        : host;
  }

  static bool verifyAsIpAddress(String host) {
    return RegExp('([0-9a-fA-F]*:[0-9a-fA-F:.]*)|([\\d.]+)')
            .stringMatch(host) ==
        host;
  }

  static void closeQuietly(Closeable closeable) {
    if (closeable != null) {
      closeable.close();
    }
  }
}
