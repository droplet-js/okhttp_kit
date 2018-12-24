import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_http/okhttp3/headers.dart';
import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/internal/encoding_util.dart';
import 'package:fake_http/okhttp3/internal/http_extension.dart';
import 'package:fake_http/okhttp3/lang/character.dart';
import 'package:fake_http/okhttp3/media_type.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/request_body.dart';
import 'package:fake_http/okhttp3/response.dart';
import 'package:fake_http/okhttp3/response_body.dart';
import 'package:quiver/async.dart';

/// 网络层拦截器
class HttpLoggingInterceptor implements Interceptor {
  final LoggerLevel _level;
  final LoggerFactory _factory;

  HttpLoggingInterceptor({
    LoggerLevel level: LoggerLevel.BASIC,
    LoggerFactory factory: LoggerFactory.PLATFORM,
  })  : assert(level != null),
        assert(factory != null),
        _level = level,
        _factory = factory;

  @override
  Future<Response> intercept(Chain chain) async {
    if (_level == LoggerLevel.NONE) {
      return await chain.proceed(chain.request());
    }

    Logger logger = _factory.logger();

    bool logBody = _level == LoggerLevel.BODY;
    bool logHeaders = logBody || _level == LoggerLevel.HEADERS;

    Request request = chain.request();
    RequestBody requestBody = request.body();
    bool hasRequestBody = requestBody != null;
    if (!logHeaders && hasRequestBody) {
      logger.start(request.method(), request.url().toString(),
          message: '${requestBody.contentLength()}-byte body');
    } else {
      logger.start(request.method(), request.url().toString());
    }

    if (logHeaders) {
      Map<String, List<String>> requestHeaders = {};
      if (hasRequestBody) {
        if (requestBody.contentType() != null) {
          requestHeaders.putIfAbsent(HttpHeaders.contentTypeHeader,
              () => [requestBody.contentType().toString()]);
        }
        int contentLength = requestBody.contentLength();
        if (contentLength != -1) {
          requestHeaders.putIfAbsent(HttpHeaders.contentLengthHeader,
              () => [contentLength.toString()]);
        }
      }

      Headers headers = request.headers();
      headers.names().forEach((String name) {
        if (HttpHeaders.contentTypeHeader != name &&
            HttpHeaders.contentLengthHeader != name) {
          requestHeaders.putIfAbsent(name, () => headers.values(name));
        }
      });

      logger.requestHeaders(requestHeaders);

      if (!logBody || !hasRequestBody) {
        logger.requestOmitted(request.method());
      } else if (_bodyEncoded(request.headers())) {
        logger.requestOmitted(request.method(),
            message: 'encoded body omitted');
      } else {
        MediaType contentType = requestBody.contentType();
        int contentLength = requestBody.contentLength();

        if (_isPlainContentType(contentType)) {
          StreamBuffer<int> buffer = new StreamBuffer();
          StreamSink<List<int>> sink = new IOSink(buffer);
          await requestBody.writeTo(sink);
          List<int> bytes = await buffer.read(buffer.buffered);

          Encoding encoding = EncodingUtil.encoding(contentType);
          String body = encoding.decode(bytes);

          if (_isPlainText(body)) {
            logger.requestPlaintextBody(body);
            logger.requestOmitted(request.method(),
                message: 'plaintext ${bytes.length}-byte body');
          } else {
            logger.requestOmitted(request.method(),
                message: 'binary ${bytes.length}-byte body');
          }

          request = request
              .newBuilder()
              .method(
                  request.method(), RequestBody.bytesBody(contentType, bytes))
              .build();
        } else {
          logger.requestOmitted(request.method(),
              message:
                  'binary ${contentLength != -1 ? '$contentLength-byte body' : 'unknown-length body'}');
        }
      }
    }

    Stopwatch watch = new Stopwatch()..start();
    Response response;
    try {
      response = await chain.proceed(request);
    } catch (e) {
      logger.error(request.url().toString(), e);
      logger.end();
      rethrow;
    }
    int tookMs = watch.elapsedMilliseconds;
    ResponseBody responseBody = response.body();
    int contentLength = responseBody.contentLength();
    String message = contentLength != -1
        ? '$contentLength-byte body'
        : 'unknown-length body';
    logger.status(response.code(), response.message(),
        response.request().url().toString(), tookMs, message);

    if (logHeaders) {
      Map<String, List<String>> responseHeaders = {};
      if (responseBody.contentType() != null) {
        responseHeaders.putIfAbsent(HttpHeaders.contentTypeHeader,
            () => [responseBody.contentType().toString()]);
      }
      int contentLength = responseBody.contentLength();
      if (contentLength != -1) {
        responseHeaders.putIfAbsent(
            HttpHeaders.contentLengthHeader, () => [contentLength.toString()]);
      }

      Headers headers = response.headers();
      headers.names().forEach((String name) {
        if (HttpHeaders.contentTypeHeader != name &&
            HttpHeaders.contentLengthHeader != name) {
          responseHeaders.putIfAbsent(name, () => headers.values(name));
        }
      });

      logger.responseHeaders(responseHeaders);

      if (!logBody || !HttpHeadersExtension.hasBody(response)) {
        logger.responseOmitted(response.request().method());
      } else if (_bodyEncoded(response.headers())) {
        logger.responseOmitted(response.request().method(),
            message: 'encoded body omitted');
      } else {
        MediaType contentType = responseBody.contentType();

        if (_isPlainContentType(contentType)) {
          List<int> bytes = await responseBody.bytes();

          Encoding encoding = EncodingUtil.encoding(contentType);
          String body = encoding.decode(bytes);
          if (_isPlainText(body)) {
            logger.responsePlaintextBody(body);
            logger.responseOmitted(response.request().method(),
                message: 'plaintext ${bytes.length}-byte body omitted');
          } else {
            logger.responseOmitted(response.request().method(),
                message: 'binary ${bytes.length}-byte body omitted');
          }

          response = response
              .newBuilder()
              .body(ResponseBody.bytesBody(contentType, bytes))
              .build();
        } else {
          logger.responseOmitted(response.request().method(),
              message:
                  'binary ${contentLength != -1 ? '$contentLength-byte body' : 'unknown-length body'}');
        }
      }
    }
    logger.finish(contentLength);
    logger.end();
    return response;
  }

  bool _bodyEncoded(Headers headers) {
    String header = headers != null
        ? headers.value(HttpHeaders.contentEncodingHeader)
        : null;
    if (header != null && header.toLowerCase() == 'identity') {
      return true;
    }
    return false;
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

enum LoggerLevel {
  NONE,
  BASIC,
  HEADERS,
  BODY,
}

abstract class Logger {
  void start(String method, String url, {String message});

  void requestHeaders(Map<String, List<String>> requestHeaders);

  void requestPlaintextBody(String plaintext);

  void requestOmitted(String method, {String message});

  void response();

  void error(String url, Object e);

  void status(int statusCode, String reasonPhrase, String url, int tookMs,
      String message);

  void responseHeaders(Map<String, List<String>> responseHeaders);

  void responsePlaintextBody(String plaintext);

  void responseOmitted(String method, {String message});

  void finish(int contentLength);

  void end();
}

abstract class LoggerFactory {
  static const LoggerFactory PLATFORM = _PlatformLoggerFactory();

  Logger logger();
}

class _PlatformLoggerFactory implements LoggerFactory {
  const _PlatformLoggerFactory();

  @override
  Logger logger() {
    return new _PlatformLogger();
  }
}

class _PlatformLogger implements Logger {
  @override
  void start(String method, String url, {String message}) {
    print('--> $method $url ${message != null ? message : ''}');
  }

  @override
  void requestHeaders(Map<String, List<String>> requestHeaders) {
    requestHeaders.forEach((String name, List<String> values) {
      values.forEach((String value) {
        print('$name: $value');
      });
    });
  }

  @override
  void requestPlaintextBody(String plaintext) {
    if (plaintext != null && plaintext.isNotEmpty) {
      print(plaintext);
    }
  }

  @override
  void requestOmitted(String method, {String message}) {
    print('--> END $method ${message != null ? message : ''}');
  }

  @override
  void response() {}

  @override
  void error(String url, Object e) {
    print('<-- HTTP FAILED: $url ${e.toString()}');
  }

  @override
  void status(int statusCode, String reasonPhrase, String url, int tookMs,
      String message) {
    print('<-- $statusCode $reasonPhrase $url (${tookMs}ms, $message)');
  }

  @override
  void responseHeaders(Map<String, List<String>> responseHeaders) {
    responseHeaders.forEach((String name, List<String> values) {
      values.forEach((String value) {
        print('$name: $value');
      });
    });
  }

  @override
  void responsePlaintextBody(String plaintext) {
    if (plaintext != null && plaintext.isNotEmpty) {
      print(plaintext);
    }
  }

  @override
  void responseOmitted(String method, {String message}) {
    print('<-- END $method ${message != null ? message : ''}');
  }

  @override
  void finish(int contentLength) {}

  @override
  void end() {}
}
