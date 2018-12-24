import 'dart:async';

import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/media_type.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/request_body.dart';
import 'package:fake_http/okhttp3/response.dart';
import 'package:fake_http/okhttp3/tools/progress_interceptor.dart';

/// 网络层拦截器
class ProgressRequestInterceptor implements ProgressInterceptor {
  final ProgressListener _listener;

  ProgressRequestInterceptor(ProgressListener listener) : _listener = listener;

  @override
  Future<Response> intercept(Chain chain) {
    Request originalRequest = chain.request();
    if (originalRequest.body() == null) {
      return chain.proceed(originalRequest);
    }

    Request progressRequest = originalRequest
        .newBuilder()
        .method(
            originalRequest.method(),
            new _ProgressRequestBody(
                originalRequest.body(),
                new _CallbackAdapter(originalRequest.url().toString(),
                    originalRequest.method(), _listener)))
        .build();
    return chain.proceed(progressRequest);
  }
}

abstract class _Callback {
  void onWrite(int progressBytes, int totalBytes);

  void onClose(int progressBytes, int totalBytes);
}

class _CallbackAdapter implements _Callback {
  final String url;
  final String method;
  final ProgressListener listener;

  _CallbackAdapter(this.url, this.method, this.listener);

  @override
  void onWrite(int progressBytes, int totalBytes) {
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

class _ProgressRequestBody extends RequestBody {
  final RequestBody wrapped;
  final _Callback callback;

  _ProgressRequestBody(this.wrapped, this.callback);

  @override
  MediaType contentType() {
    return wrapped.contentType();
  }

  @override
  int contentLength() {
    return wrapped.contentLength();
  }

  @override
  Future<void> writeTo(StreamSink<List<int>> sink) async {
    _ProgressByteStreamSink progressSink =
        new _ProgressByteStreamSink(sink, contentLength(), callback);
    await wrapped.writeTo(progressSink);
    await progressSink.close();
  }
}

class _ProgressByteStreamSink extends StreamSink<List<int>> {
  final StreamSink wrapped;
  final int totalBytes;
  final _Callback callback;

  int progressBytes = 0;

  _ProgressByteStreamSink(this.wrapped, this.totalBytes, this.callback);

  @override
  void add(List<int> event) {
    wrapped.add(event);
    progressBytes += event.length;
    if (callback != null) {
      callback.onWrite(progressBytes, totalBytes);
    }
  }

  @override
  void addError(Object error, [StackTrace stackTrace]) {
    wrapped.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    StreamTransformer<List<int>, List<int>> streamTransformer =
        new StreamTransformer.fromHandlers(handleData:
            (List<int> data, EventSink<List<int>> sink) {
      sink.add(data);
      progressBytes += data.length;
      if (callback != null) {
        callback.onWrite(progressBytes, totalBytes);
      }
    }, handleError:
            (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
      sink.addError(error, stackTrace);
    }, handleDone: (EventSink<List<int>> sink) {
      sink.close();
    });
    return wrapped.addStream(stream.transform(streamTransformer));
  }

  @override
  Future close() async {
    if (callback != null) {
      callback.onClose(progressBytes, totalBytes);
    }
    return;
  }

  @override
  Future get done =>
      Future.error(new UnsupportedError('$runtimeType#done is not supported!'));
}
