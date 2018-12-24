import 'dart:async';

import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/media_type.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';
import 'package:fake_http/okhttp3/response_body.dart';
import 'package:fake_http/okhttp3/tools/progress_interceptor.dart';

/// 网络层拦截器
class ProgressResponseInterceptor implements ProgressInterceptor {
  final ProgressListener _listener;

  ProgressResponseInterceptor(ProgressListener listener) : _listener = listener;

  @override
  Future<Response> intercept(Chain chain) async {
    Request originalRequest = chain.request();
    Response originalResponse = await chain.proceed(originalRequest);
    return originalResponse
        .newBuilder()
        .body(new _ProgressResponseBody(
            originalResponse.body(),
            new _CallbackAdapter(originalResponse.request().url().toString(),
                originalResponse.request().method(), _listener)))
        .build();
  }
}

abstract class _Callback {
  void onRead(int progressBytes, int totalBytes);

  void onClose(int progressBytes, int totalBytes);
}

class _CallbackAdapter implements _Callback {
  final String url;
  final String method;
  final ProgressListener listener;

  _CallbackAdapter(this.url, this.method, this.listener);

  @override
  void onRead(int progressBytes, int totalBytes) {
    if (listener != null) {
      listener(url, method, progressBytes, totalBytes, false);
    }
  }

  @override
  void onClose(int progressBytes, int totalBytes) {
    if (listener != null) {
      listener(url, method, progressBytes, totalBytes, true);
    }
  }
}

class _ProgressResponseBody extends ResponseBody {
  final ResponseBody wrapped;
  final _Callback callback;

  _ProgressResponseBody(this.wrapped, this.callback);

  @override
  MediaType contentType() {
    return wrapped.contentType();
  }

  @override
  int contentLength() {
    return wrapped.contentLength();
  }

  @override
  Stream<List<int>> source() {
    int totalBytes = contentLength();
    int progressBytes = 0;
    StreamTransformer<List<int>, List<int>> streamTransformer =
        new StreamTransformer.fromHandlers(handleData:
            (List<int> data, EventSink<List<int>> sink) {
      sink.add(data);
      progressBytes += data.length;
      if (callback != null) {
        callback.onRead(progressBytes, totalBytes);
      }
    }, handleError:
            (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
      sink.addError(error, stackTrace);
    }, handleDone: (EventSink<List<int>> sink) {
      sink.close();
      if (callback != null) {
        callback.onClose(progressBytes, totalBytes);
      }
    });
    return wrapped.source().transform(streamTransformer);
  }

  @override
  void close() {
    wrapped.close();
  }
}
