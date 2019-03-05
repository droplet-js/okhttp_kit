import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui show instantiateImageCodec, Codec;

import 'package:fake_http/okhttp3/headers.dart';
import 'package:fake_http/okhttp3/http_url.dart';
import 'package:fake_http/okhttp3/okhttp_client.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide NetworkImage;

class OkHttpNetworkImage extends ImageProvider<OkHttpNetworkImage> {
  OkHttpNetworkImage(
    OkHttpClient client,
    String url, {
    double scale = 1.0,
    Map<String, List<String>> headers = const <String, List<String>>{},
  })  : assert(client != null),
        assert(url != null),
        assert(headers != null),
        _client = client,
        _url = url,
        _scale = scale,
        _headers = headers;

  final OkHttpClient _client;
  final String _url;
  final double _scale;
  final Map<String, List<String>> _headers;

  @override
  Future<OkHttpNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OkHttpNetworkImage>(this);
  }

  @override
  ImageStreamCompleter load(OkHttpNetworkImage key) {
    return MultiFrameImageStreamCompleter(
        codec: _loadAsync(key),
        scale: key._scale,
        informationCollector: (StringBuffer information) {
          information.writeln('Image provider: $this');
          information.write('Image key: $key');
        });
  }

  Future<ui.Codec> _loadAsync(OkHttpNetworkImage key) async {
    assert(key == this);

    final Uri resolved = Uri.base.resolve(key._url);
    Response response = await _client
        .newCall(RequestBuilder()
            .url(HttpUrl.from(resolved))
            .headers(Headers.of(_headers))
            .get()
            .build())
        .enqueue();

    if (response.code() != HttpStatus.ok) {
      throw Exception(
          'HTTP request failed, statusCode: ${response.code()}, $resolved');
    }

    final Uint8List bytes = Uint8List.fromList(await response.body().bytes());
    if (bytes.lengthInBytes == 0) {
      throw Exception('FakeNetworkImage is an empty file: $resolved');
    }

    return await ui.instantiateImageCodec(bytes);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final OkHttpNetworkImage typedOther = other;
    return _url == typedOther._url && _scale == typedOther._scale;
  }

  @override
  int get hashCode => hashValues(_url, _scale);

  @override
  String toString() => '$runtimeType("$_url", scale: $_scale)';
}
