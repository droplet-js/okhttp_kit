import 'dart:async';
import 'dart:convert';

import 'package:fake_http/okhttp3/media_type.dart';
import 'package:fake_http/okhttp3/request_body.dart';

class FormBody extends RequestBody {
  FormBody._(
    Encoding encoding,
    List<String> namesAndValues,
  )   : _encoding = encoding,
        _contentType =
            MediaType('application', 'x-www-form-urlencoded', encoding.name),
        _namesAndValues = namesAndValues,
        _bytes = encoding.encode(_pairsToQuery(namesAndValues));

  final Encoding _encoding;
  final MediaType _contentType;
  final List<String> _namesAndValues;
  final List<int> _bytes;

  @override
  MediaType contentType() {
    return _contentType;
  }

  @override
  int contentLength() {
    return _bytes.length;
  }

  @override
  Future<void> writeTo(StreamSink<List<int>> sink) async {
    sink.add(_bytes);
  }

  static String _pairsToQuery(List<String> namesAndValues) {
    return List.generate(namesAndValues.length ~/ 2, (int index) {
      return '${namesAndValues[index * 2]}=${namesAndValues[index * 2 + 1]}';
    }).join('&');
  }
}

class FormBodyBuilder {
  FormBodyBuilder([
    Encoding encoding = utf8,
  ])  : assert(encoding != null),
        _encoding = encoding;

  final Encoding _encoding;
  final List<String> _namesAndValues = [];

  FormBodyBuilder add(String name, String value) {
    assert(name != null);
    assert(value != null);
    _namesAndValues.add(Uri.encodeQueryComponent(name, encoding: _encoding));
    _namesAndValues.add(Uri.encodeQueryComponent(value, encoding: _encoding));
    return this;
  }

  FormBody build() {
    return FormBody._(_encoding, List.unmodifiable(_namesAndValues));
  }
}
