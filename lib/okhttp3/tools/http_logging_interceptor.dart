import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_okhttp/okhttp3/chain.dart';
import 'package:fake_okhttp/okhttp3/foundation/character.dart';
import 'package:fake_okhttp/okhttp3/headers.dart';
import 'package:fake_okhttp/okhttp3/interceptor.dart';
import 'package:fake_okhttp/okhttp3/internal/encoding_util.dart';
import 'package:fake_okhttp/okhttp3/internal/http_extension.dart';
import 'package:fake_okhttp/okhttp3/internal/util.dart';
import 'package:fake_okhttp/okhttp3/media_type.dart';
import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/request_body.dart';
import 'package:fake_okhttp/okhttp3/response.dart';
import 'package:fake_okhttp/okhttp3/response_body.dart';

enum LoggingLevel {
  none,
  basic,
  headers,
  body,
}

/// 网络层拦截器
class HttpLoggingInterceptor implements Interceptor {
  HttpLoggingInterceptor({
    LoggingLevel level = LoggingLevel.basic,
  }) : _level = level;

  final LoggingLevel _level;

  @override
  Future<Response> intercept(Chain chain) async {
    Request request = chain.request();
    if (_level == LoggingLevel.none) {
      return await chain.proceed(request);
    }

    bool logBody = _level == LoggingLevel.body;
    bool logHeaders = logBody || _level == LoggingLevel.headers;

    RequestBody requestBody = request.body();
    bool hasRequestBody = requestBody != null;
    if (!logHeaders && hasRequestBody) {
      print(
          '--> ${request.method()} ${request.url().toString()} ${requestBody.contentLength()}-byte body');
    } else {
      print('--> ${request.method()} ${request.url().toString()}');
    }

    if (logHeaders) {
      if (hasRequestBody) {
        if (requestBody.contentType() != null) {
          print(
              '${HttpHeaders.contentTypeHeader}: ${requestBody.contentType().toString()}');
        }
        if (requestBody.contentLength() != -1) {
          print(
              '${HttpHeaders.contentLengthHeader}: ${requestBody.contentLength()}');
        }
      }

      Headers headers = request.headers();
      headers.names().forEach((String name) {
        if (HttpHeaders.contentTypeHeader != name &&
            HttpHeaders.contentLengthHeader != name) {
          print('$name: ${headers.value(name)}');
        }
      });

      if (!logBody || !hasRequestBody) {
        print('--> END ${request.method()}');
      } else if (_bodyHasUnknownEncoding(request.headers())) {
        print('--> END ${request.method()} (encoded body omitted)');
      } else {
        MediaType contentType = requestBody.contentType();

        if (_isPlainContentType(contentType)) {
          List<int> bytes = await Util.readAsBytes(requestBody.source());

          Encoding encoding = EncodingUtil.encoding(contentType);
          String body = encoding.decode(bytes);

          if (_isPlainText(body)) {
            print(body);
            print('--> END ${request.method()} (${bytes.length}-byte body)');
          } else {
            print(
                '--> END ${request.method()} (binary ${bytes.length}-byte body omitted)');
          }

          request = request
              .newBuilder()
              .method(
                  request.method(), RequestBody.bytesBody(contentType, bytes))
              .build();
        } else {
          print(
              '--> END ${request.method()} (binary ${requestBody.contentLength()}-byte body omitted)');
        }
      }
    }

    Stopwatch watch = Stopwatch()..start();
    Response response;
    try {
      response = await chain.proceed(request);
    } catch (e) {
      print('<-- HTTP FAILED: ${e.toString()}');
      rethrow;
    }
    int tookMs = watch.elapsedMilliseconds;
    ResponseBody responseBody = response.body();
    String bodySize = responseBody.contentLength() != -1
        ? '${responseBody.contentLength()}-byte body'
        : 'unknown-length body';
    print(
        '<-- ${response.code()} ${response.message() ?? ''} ${response.request().url().toString()} (${tookMs}ms${!logHeaders ? ', $bodySize body' : ''})');

    if (logHeaders) {
      if (responseBody.contentType() != null) {
        print(
            '${HttpHeaders.contentTypeHeader}: ${responseBody.contentType().toString()}');
      }
      if (responseBody.contentLength() != -1) {
        print(
            '${HttpHeaders.contentLengthHeader}: ${responseBody.contentLength()}');
      }

      Headers headers = response.headers();
      headers.names().forEach((String name) {
        if (HttpHeaders.contentTypeHeader != name &&
            HttpHeaders.contentLengthHeader != name) {
          print('$name: ${headers.value(name)}');
        }
      });

      if (!logBody || !HttpHeadersExtension.hasBody(response)) {
        print('<-- END HTTP');
      } else if (_bodyHasUnknownEncoding(response.headers())) {
        print("<-- END HTTP (encoded body omitted)");
      } else {
        MediaType contentType = responseBody.contentType();

        if (_isPlainContentType(contentType)) {
          List<int> bytes = await responseBody.bytes();

          Encoding encoding = EncodingUtil.encoding(contentType);
          String body = encoding.decode(bytes);
          if (_isPlainText(body)) {
            print(body);
            print('<-- END HTTP (${bytes.length}-byte body)');
          } else {
            print('<-- END HTTP (binary ${bytes.length}-byte body omitted)');
          }

          response = response
              .newBuilder()
              .body(ResponseBody.bytesBody(contentType, bytes))
              .build();
        } else {
          print(
              '<-- END HTTP (binary ${responseBody.contentLength()}-byte body omitted)');
        }
      }
    }
    return response;
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
