import 'dart:async';
import 'dart:convert';

import 'package:okhttp_kit/okhttp3/internal/encoding_util.dart';
import 'package:okhttp_kit/okhttp3/internal/util.dart';
import 'package:okhttp_kit/okhttp3/media_type.dart';

abstract class ResponseBody {
  MediaType contentType();

  int contentLength();

  Stream<List<int>> source();

  Future<List<int>> bytes() {
    return Util.readAsBytes(source());
  }

  Future<String> string() async {
    Encoding encoding = EncodingUtil.encoding(contentType());
    return encoding.decode(await bytes());
//    return encoding.decodeStream(source());
  }

  static ResponseBody bytesBody(MediaType contentType, List<int> bytes) {
    return streamBody(contentType, bytes.length,
        Stream<List<int>>.fromIterable(<List<int>>[bytes]));
  }

  static ResponseBody streamBody(
      MediaType contentType, int contentLength, Stream<List<int>> source) {
    return _StreamResponseBody(contentType, contentLength, source);
  }
}

class _StreamResponseBody extends ResponseBody {
  _StreamResponseBody(
    MediaType contentType,
    int contentLength,
    Stream<List<int>> source,
  )   : _contentType = contentType,
        _contentLength = contentLength,
        _source = source;

  final MediaType _contentType;
  final int _contentLength;
  final Stream<List<int>> _source;

  @override
  MediaType contentType() {
    return _contentType;
  }

  @override
  int contentLength() {
    return _contentLength;
  }

  @override
  Stream<List<int>> source() {
    return _source;
  }
}
