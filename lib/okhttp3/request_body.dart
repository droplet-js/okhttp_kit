import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_http/okhttp3/internal/encoding_util.dart';
import 'package:fake_http/okhttp3/media_type.dart';

abstract class RequestBody {
  MediaType contentType();

  int contentLength() {
    return -1;
  }

  Future<void> writeTo(StreamSink<List<int>> sink);

  static RequestBody bytesBody(MediaType contentType, List<int> bytes) {
    return _SimpleRequestBody(contentType, bytes.length, bytes);
  }

  static RequestBody textBody(MediaType contentType, String text) {
    assert(text != null);
    Encoding encoding = EncodingUtil.encoding(contentType);
    return bytesBody(contentType, encoding.encode(text));
  }

  static RequestBody fileBody(MediaType contentType, File file) {
    return _FileRequestBody(contentType, file);
  }
}

class _SimpleRequestBody extends RequestBody {
  final MediaType _contentType;
  final int _contentLength;
  final List<int> _bytes;

  _SimpleRequestBody(MediaType contentType, int contentLength, List<int> bytes)
      : _contentType = contentType,
        _contentLength = contentLength,
        _bytes = bytes;

  @override
  MediaType contentType() {
    return _contentType;
  }

  @override
  int contentLength() {
    return _contentLength;
  }

  @override
  Future<void> writeTo(StreamSink<List<int>> sink) {
    return sink.addStream(Stream.fromIterable([_bytes]));
  }
}

class _FileRequestBody extends RequestBody {
  final MediaType _contentType;
  final File _file;

  _FileRequestBody(MediaType contentType, File file)
      : _contentType = contentType,
        _file = file;

  @override
  MediaType contentType() {
    return _contentType;
  }

  @override
  int contentLength() {
    return _file.lengthSync();
  }

  @override
  Future<void> writeTo(StreamSink<List<int>> sink) {
    return sink.addStream(_file.openRead());
  }
}
