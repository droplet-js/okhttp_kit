import 'dart:async';

import 'package:fake_http/okhttp3/call.dart';
import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/internal/cache/cache_interceptor.dart';
import 'package:fake_http/okhttp3/internal/http/bridge_interceptor.dart';
import 'package:fake_http/okhttp3/internal/http/call_server_interceptor.dart';
import 'package:fake_http/okhttp3/internal/http/real_interceptor_chain.dart';
import 'package:fake_http/okhttp3/internal/http/retry_and_follow_up_interceptor.dart';
import 'package:fake_http/okhttp3/okhttp_client.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';

class RealCall implements Call {
  final OkHttpClient _client;
  final Request _originalRequest;
  final RetryAndFollowUpInterceptor _retryAndFollowUpInterceptor;

  RealCall.newRealCall(OkHttpClient client, Request originalRequest)
      : _client = client,
        _originalRequest = originalRequest,
        _retryAndFollowUpInterceptor = new RetryAndFollowUpInterceptor(client);

  @override
  Request request() {
    return _originalRequest;
  }

  @override
  Future<Response> enqueue() {
    List<Interceptor> interceptors = [];
    interceptors.addAll(_client.interceptors());
    interceptors.add(_retryAndFollowUpInterceptor);
    interceptors.add(new BridgeInterceptor(_client.cookieJar()));
    interceptors.add(new CacheInterceptor(_client.cache()));
    interceptors.addAll(_client.networkInterceptors());
    interceptors.add(new CallServerInterceptor(_client));
    Chain chain =
        new RealInterceptorChain(interceptors, null, 0, _originalRequest, this);
    return chain.proceed(_originalRequest);
  }

  @override
  void cancel() {
    _retryAndFollowUpInterceptor.cancel();
  }

  @override
  bool isCanceled() {
    return _retryAndFollowUpInterceptor.isCanceled();
  }
}
