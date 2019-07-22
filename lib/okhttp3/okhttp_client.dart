import 'dart:async';

import 'package:fake_okhttp/okhttp3/cache.dart';
import 'package:fake_okhttp/okhttp3/call.dart';
import 'package:fake_okhttp/okhttp3/cookie_jar.dart';
import 'package:fake_okhttp/okhttp3/interceptor.dart';
import 'package:fake_okhttp/okhttp3/request.dart';

class OkHttpClient {
  OkHttpClient._(
    OkHttpClientBuilder builder,
  )   : _interceptors = List<Interceptor>.unmodifiable(builder._interceptors),
        _networkInterceptors =
            List<Interceptor>.unmodifiable(builder._networkInterceptors),
        _cookieJar = builder._cookieJar,
        _cache = builder._cache,
        _followRedirects = builder._followRedirects,
        _maxRedirects = builder._maxRedirects,
        _idleTimeout = builder._idleTimeout,
        _connectionTimeout = builder._connectionTimeout,
        _findProxy = builder._findProxy;

  final List<Interceptor> _interceptors;
  final List<Interceptor> _networkInterceptors;

  final CookieJar _cookieJar;
  final Cache _cache;

  final bool _followRedirects;
  final int _maxRedirects;

  final Duration _idleTimeout;
  final Duration _connectionTimeout;

  final FutureOr<String Function(Uri url)> Function() _findProxy;

  List<Interceptor> interceptors() {
    return _interceptors;
  }

  List<Interceptor> networkInterceptors() {
    return _networkInterceptors;
  }

  CookieJar cookieJar() {
    return _cookieJar;
  }

  Cache cache() {
    return _cache;
  }

  bool followRedirects() {
    return _followRedirects;
  }

  int maxRedirects() {
    return _maxRedirects;
  }

  Duration idleTimeout() {
    return _idleTimeout;
  }

  Duration connectionTimeout() {
    return _connectionTimeout;
  }

  FutureOr<String Function(Uri url)> Function() findProxy() {
    return _findProxy;
  }

  Call newCall(Request request) {
    return RealCall.newRealCall(this, request);
  }

  OkHttpClientBuilder newBuilder() {
    return OkHttpClientBuilder._(this);
  }
}

class OkHttpClientBuilder {
  OkHttpClientBuilder();

  OkHttpClientBuilder._(OkHttpClient client)
      : _cookieJar = client._cookieJar,
        _cache = client._cache,
        _followRedirects = client._followRedirects,
        _maxRedirects = client._maxRedirects,
        _idleTimeout = client._idleTimeout,
        _connectionTimeout = client._connectionTimeout,
        _findProxy = client._findProxy {
    _interceptors.addAll(client._interceptors);
    _networkInterceptors.addAll(client._networkInterceptors);
  }

  final List<Interceptor> _interceptors = <Interceptor>[];
  final List<Interceptor> _networkInterceptors = <Interceptor>[];

  CookieJar _cookieJar = CookieJar.noCookies;
  Cache _cache;

  bool _followRedirects = true;
  int _maxRedirects = 5;

  Duration _idleTimeout = Duration(seconds: 15);
  Duration _connectionTimeout = Duration(seconds: 10);

  FutureOr<String Function(Uri url)> Function() _findProxy;

  OkHttpClientBuilder addInterceptor(Interceptor interceptor) {
    assert(interceptor != null);
    _interceptors.add(interceptor);
    return this;
  }

  OkHttpClientBuilder addNetworkInterceptor(Interceptor networkInterceptor) {
    assert(networkInterceptor != null);
    _networkInterceptors.add(networkInterceptor);
    return this;
  }

  OkHttpClientBuilder cookieJar(CookieJar cookieJar) {
    assert(cookieJar != null);
    _cookieJar = cookieJar;
    return this;
  }

  OkHttpClientBuilder cache(Cache cache) {
    _cache = cache;
    return this;
  }

  OkHttpClientBuilder followRedirects(bool value) {
    assert(value != null);
    _followRedirects = value;
    return this;
  }

  OkHttpClientBuilder maxRedirects(int value) {
    assert(value != null);
    _maxRedirects = value;
    return this;
  }

  OkHttpClientBuilder idleTimeout(Duration value) {
    assert(value != null);
    _idleTimeout = value;
    return this;
  }

  OkHttpClientBuilder connectionTimeout(Duration value) {
    assert(value != null);
    _connectionTimeout = value;
    return this;
  }

  OkHttpClientBuilder findProxy(FutureOr<String Function(Uri url)> Function() findProxy) {
    assert(findProxy != null);
    _findProxy = findProxy;
    return this;
  }

  OkHttpClient build() {
    return OkHttpClient._(this);
  }
}
