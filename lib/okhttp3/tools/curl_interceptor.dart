import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:okhttp_kit/okhttp3/chain.dart';
import 'package:okhttp_kit/okhttp3/foundation/character.dart';
import 'package:okhttp_kit/okhttp3/headers.dart';
import 'package:okhttp_kit/okhttp3/interceptor.dart';
import 'package:okhttp_kit/okhttp3/internal/encoding_util.dart';
import 'package:okhttp_kit/okhttp3/internal/util.dart';
import 'package:okhttp_kit/okhttp3/media_type.dart';
import 'package:okhttp_kit/okhttp3/request.dart';
import 'package:okhttp_kit/okhttp3/request_body.dart';
import 'package:okhttp_kit/okhttp3/response.dart';

/// 网络层拦截器
class CurlInterceptor implements Interceptor {
  CurlInterceptor([this.enabled = true, this.headerFilter]);

  bool enabled;
  bool Function(String) headerFilter;

  @override
  Future<Response> intercept(Chain chain) async {
    Request request = chain.request();
    if (!enabled) {
      return await chain.proceed(request);
    }
    bool supportCurl = false;
    List<String> parts = <String>[];
    parts.add('curl');
    parts.add('-X ${request.method()}');
    parts.add('${request.url().toString()}');
    Headers headers = request.headers();
    headers.names().forEach((String name) {
      if (headerFilter == null || headerFilter(name)) {
        parts.add('-H \'$name:${headers.value(name)}\'');
      }
    });
    RequestBody requestBody = request.body();
    if (requestBody != null) {
      if (!_bodyHasUnknownEncoding(request.headers())) {
        MediaType contentType = requestBody.contentType();
        if (_isPlainContentType(contentType)) {
          List<int> bytes = await Util.readAsBytes(requestBody.source());
          Encoding encoding = EncodingUtil.encoding(contentType);
          String body = encoding.decode(bytes);
          if (_isPlainText(body)) {
            supportCurl = true;
            parts.add('-d \'$body\'');
          }
          request = request
              .newBuilder()
              .method(
                  request.method(), RequestBody.bytesBody(contentType, bytes))
              .build();
        }
      }
    } else {
      supportCurl = true;
    }
    if (supportCurl) {
      print('curl: ${parts.join(' ')}');
    }
    return await chain.proceed(request);
  }

  bool _bodyHasUnknownEncoding(Headers headers) {
    String contentEncoding = headers.value(HttpHeaders.contentEncodingHeader);
    return contentEncoding != null &&
        contentEncoding.toLowerCase() != 'identity' &&
        contentEncoding.toLowerCase() != 'gzip';
  }

  static bool _isPlainContentType(MediaType contentType) {
    if (contentType != null &&
        ('text' == contentType.type().toLowerCase() ||
            'json' == contentType.subtype().toLowerCase() ||
            'application/x-www-form-urlencoded' ==
                contentType.mimeType().toLowerCase())) {
      return true;
    }
    return false;
  }

  static bool _isPlainText(String body) {
    return body.runes.take(16).every((int rune) {
      return !Character.isIsoControl(rune) || Character.isWhitespace(rune);
    });
  }
}
