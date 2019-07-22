import 'dart:async';
import 'dart:convert';

import 'package:fake_okhttp/okhttp3/http_url.dart';
import 'package:fake_okhttp/okhttp3/request_body.dart';
import 'package:fake_okhttp/okhttp3/response_body.dart';

class Util {
  Util._();

  static final ResponseBody emptyResponse =
      ResponseBody.bytesBody(null, const <int>[]);

  static final RequestBody emptyRequest =
      RequestBody.bytesBody(null, const <int>[]);

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

  static Future<List<int>> readAsBytes(Stream<List<int>> source) {
    Completer<List<int>> completer = Completer<List<int>>();
    ByteConversionSink sink =
        ByteConversionSink.withCallback((List<int> accumulated) {
      completer.complete(accumulated);
    });
    source.listen(
      sink.add,
      onError: completer.completeError,
      onDone: sink.close,
      cancelOnError: true,
    );
    return completer.future;
  }
}
