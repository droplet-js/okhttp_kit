import 'dart:async';

import 'package:fake_okhttp/okhttp3/chain.dart';
import 'package:fake_okhttp/okhttp3/http_url.dart';
import 'package:fake_okhttp/okhttp3/interceptor.dart';
import 'package:fake_okhttp/okhttp3/media_type.dart';
import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/request_body.dart';
import 'package:fake_okhttp/okhttp3/response.dart';
import 'package:fake_okhttp/okhttp3/response_body.dart';

typedef void ProgressListener(
    HttpUrl url, String method, int progressBytes, int totalBytes, bool isDone);

/// 网络层拦截器
class ProgressRequestInterceptor implements Interceptor {
  ProgressRequestInterceptor(
    ProgressListener listener,
  ) : _listener = listener;

  final ProgressListener _listener;

  @override
  Future<Response> intercept(Chain chain) {
    Request originalRequest = chain.request();
    if (originalRequest.body() == null) {
      return chain.proceed(originalRequest);
    }
    RequestBody originalRequestBody = originalRequest.body();
    int totalBytes = originalRequestBody.contentLength();
    int progressBytes = 0;
    Stream<List<int>> source =
        StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> data, EventSink<List<int>> sink) {
      sink.add(data);
      progressBytes += data.length;
      if (_listener != null) {
        _listener(originalRequest.url(), originalRequest.method(),
            progressBytes, totalBytes, false);
      }
    }, handleDone: (EventSink<List<int>> sink) {
      sink.close();
      if (_listener != null) {
        _listener(originalRequest.url(), originalRequest.method(),
            progressBytes, totalBytes, true);
      }
    }).bind(originalRequestBody.source());
    Request progressRequest = originalRequest
        .newBuilder()
        .method(
            originalRequest.method(),
            _StreamRequestBody(originalRequestBody.contentType(),
                originalRequestBody.contentLength(), source))
        .build();
    return chain.proceed(progressRequest);
  }
}

class _StreamRequestBody extends RequestBody {
  _StreamRequestBody(
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

/// 网络层拦截器
class ProgressResponseInterceptor implements Interceptor {
  ProgressResponseInterceptor(
    ProgressListener listener,
  ) : _listener = listener;

  final ProgressListener _listener;

  @override
  Future<Response> intercept(Chain chain) async {
    Request originalRequest = chain.request();
    Response originalResponse = await chain.proceed(originalRequest);
    if (originalResponse.body() == null) {
      return originalResponse;
    }
    ResponseBody originalResponseBody = originalResponse.body();
    int totalBytes = originalResponseBody.contentLength();
    int progressBytes = 0;
    Stream<List<int>> source =
        StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> data, EventSink<List<int>> sink) {
      sink.add(data);
      progressBytes += data.length;
      if (_listener != null) {
        _listener(originalRequest.url(), originalRequest.method(),
            progressBytes, totalBytes, false);
      }
    }, handleDone: (EventSink<List<int>> sink) {
      sink.close();
      if (_listener != null) {
        _listener(originalRequest.url(), originalRequest.method(),
            progressBytes, totalBytes, true);
      }
    }).bind(originalResponseBody.source());
    return originalResponse
        .newBuilder()
        .body(ResponseBody.streamBody(originalResponseBody.contentType(),
            originalResponseBody.contentLength(), source))
        .build();
  }
}
