import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:okhttp_kit/okhttp3/http_url.dart';
import 'package:okhttp_kit/okhttp3/request_body.dart';
import 'package:okhttp_kit/okhttp3/response_body.dart';

class Util {
  Util._();

  static const int _boundaryLength = 70;
  static const List<int> _boundaryCharacters = <int>[
    43,
    95,
    45,
    46,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    65,
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    88,
    89,
    90,
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114,
    115,
    116,
    117,
    118,
    119,
    120,
    121,
    122,
  ];

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

  static String boundaryString() {
    String prefix = "dart-http-boundary-";
    Random random = Random();
    List<int> list = List<int>.generate(
      _boundaryLength - prefix.length,
      (int index) =>
          _boundaryCharacters[random.nextInt(_boundaryCharacters.length)],
      growable: false,
    );
    return "$prefix${String.fromCharCodes(list)}";
  }
}
