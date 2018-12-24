import 'dart:async';
import 'dart:convert';

import 'package:fake_http/okhttp3/internal/encoding_util.dart';
import 'package:fake_http/okhttp3/io/closeable.dart';
import 'package:fake_http/okhttp3/media_type.dart';

abstract class ResponseBody implements Closeable {
  MediaType contentType();

  int contentLength() {
    return -1;
  }

  Stream<List<int>> source();

//  Future<List<int>> bytes() async {
//    StreamBuffer<int> sink = new StreamBuffer();
//    await sink.addStream(source());
//    return await sink.read(sink.buffered);
//  }

  Future<List<int>> bytes() {
    Completer completer = new Completer<List<int>>();
    ByteConversionSink sink =
        new ByteConversionSink.withCallback((List<int> accumulated) {
      completer.complete(accumulated);
    });
    source().listen(sink.add,
        onError: completer.completeError,
        onDone: sink.close,
        cancelOnError: true);
    return completer.future;
  }

  Future<String> string() async {
    Encoding encoding = EncodingUtil.encoding(contentType());
    return encoding.decode(await bytes());
//    return encoding.decodeStream(source());
  }

  static ResponseBody bytesBody(MediaType contentType, List<int> bytes) {
    return streamBody(
        contentType, bytes.length, new Stream.fromIterable([bytes]));
  }

  static ResponseBody streamBody(
      MediaType contentType, int contentLength, Stream<List<int>> source) {
    return new _SimpleResponseBody(contentType, contentLength, source);
  }
}

class _SimpleResponseBody extends ResponseBody {
  final MediaType _contentType;
  final int _contentLength;
  final Stream<List<int>> _source;

  _SimpleResponseBody(
    MediaType contentType,
    int contentLength,
    Stream<List<int>> source,
  )   : _contentType = contentType,
        _contentLength = contentLength,
        _source = source;

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

  @override
  void close() {}
}
