import 'dart:async';

import 'package:fake_http/okhttp3/media_type.dart';
import 'package:fake_http/okhttp3/response_body.dart';

class RealResponseBody extends ResponseBody {
  final String _contentType;
  final int _contentLength;
  final Stream<List<int>> _source;

  RealResponseBody(
    String contentType,
    int contentLength,
    Stream<List<int>> source,
  )   : _contentType = contentType,
        _contentLength = contentLength,
        _source = source;

  @override
  MediaType contentType() {
    return _contentType != null ? MediaType.parse(_contentType) : null;
  }

  @override
  int contentLength() {
    return _contentLength;
  }

  @override
  Stream<List<int>> source() {
    return _source;
  }

  @override
  void close() {}
}
