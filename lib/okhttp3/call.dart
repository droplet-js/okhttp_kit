import 'dart:async';

import 'package:okhttp_kit/okhttp3/chain.dart';
import 'package:okhttp_kit/okhttp3/interceptor.dart';
import 'package:okhttp_kit/okhttp3/internal/cache/cache_interceptor.dart';
import 'package:okhttp_kit/okhttp3/internal/http/bridge_interceptor.dart';
import 'package:okhttp_kit/okhttp3/internal/http/call_server_interceptor.dart';
import 'package:okhttp_kit/okhttp3/okhttp_client.dart';
import 'package:okhttp_kit/okhttp3/request.dart';
import 'package:okhttp_kit/okhttp3/response.dart';

abstract class Call {
  Future<Response> enqueue();

  void cancel(Object error, [StackTrace stackTrace]);
}

class RealCall implements Call {
  RealCall.newRealCall(OkHttpClient client, Request originalRequest)
      : _client = client,
        _originalRequest = originalRequest;

  final OkHttpClient _client;
  final Request _originalRequest;
  final Completer<Response> _completer = Completer<Response>();

  @override
  Future<Response> enqueue() {
    List<Interceptor> interceptors = <Interceptor>[];
    interceptors.addAll(_client.interceptors());
    interceptors.add(BridgeInterceptor(_client.cookieJar()));
    interceptors.add(CacheInterceptor(_client.cache()));
    interceptors.addAll(_client.networkInterceptors());
    interceptors.add(CallServerInterceptor(_client));
    Chain chain = RealInterceptorChain(interceptors, 0, _originalRequest);
    _completer.complete(chain.proceed(_originalRequest));
    return _completer.future;
  }

  @override
  void cancel(Object error, [StackTrace stackTrace]) {
    _completer.completeError(error, stackTrace);
  }
}
