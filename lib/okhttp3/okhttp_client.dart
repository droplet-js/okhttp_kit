import 'package:fake_http/okhttp3/authenticator.dart';
import 'package:fake_http/okhttp3/cache.dart';
import 'package:fake_http/okhttp3/call.dart';
import 'package:fake_http/okhttp3/cookie_jar.dart';
import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/real_call.dart';
import 'package:fake_http/okhttp3/request.dart';

class OkHttpClient implements Factory {
  OkHttpClient._(
    OkHttpClientBuilder builder,
  )   : _interceptors = List<Interceptor>.unmodifiable(builder._interceptors),
        _networkInterceptors =
            List<Interceptor>.unmodifiable(builder._networkInterceptors),
        _cookieJar = builder._cookieJar,
        _cache = builder._cache,
        _authenticator = builder._authenticator,
        _proxyAuthenticator = builder._proxyAuthenticator,
        _followRedirects = builder._followRedirects,
        _retryOnConnectionFailure = builder._retryOnConnectionFailure,
        _idleTimeout = builder._idleTimeout,
        _connectionTimeout = builder._connectionTimeout;

  final List<Interceptor> _interceptors;
  final List<Interceptor> _networkInterceptors;

  final CookieJar _cookieJar;
  final Cache _cache;

  final Authenticator _authenticator;
  final ProxyAuthenticator _proxyAuthenticator;

  final bool _followRedirects;
  final bool _retryOnConnectionFailure;

  final Duration _idleTimeout;
  final Duration _connectionTimeout;

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

  Authenticator authenticator() {
    return _authenticator;
  }

  ProxyAuthenticator proxyAuthenticator() {
    return _proxyAuthenticator;
  }

  bool followRedirects() {
    return _followRedirects;
  }

  bool retryOnConnectionFailure() {
    return _retryOnConnectionFailure;
  }

  Duration idleTimeout() {
    return _idleTimeout;
  }

  Duration connectionTimeout() {
    return _connectionTimeout;
  }

  @override
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
        _authenticator = client._authenticator,
        _proxyAuthenticator = client._proxyAuthenticator,
        _followRedirects = client._followRedirects,
        _retryOnConnectionFailure = client._retryOnConnectionFailure,
        _idleTimeout = client._idleTimeout,
        _connectionTimeout = client._connectionTimeout {
    _interceptors.addAll(client._interceptors);
    _networkInterceptors.addAll(client._networkInterceptors);
  }

  final List<Interceptor> _interceptors = <Interceptor>[];
  final List<Interceptor> _networkInterceptors = <Interceptor>[];

  CookieJar _cookieJar = CookieJar.NO_COOKIES;
  Cache _cache;

  Authenticator _authenticator = Authenticator.NONE;
  ProxyAuthenticator _proxyAuthenticator = ProxyAuthenticator.NONE;

  bool _followRedirects = true;
  bool _retryOnConnectionFailure = true;

  Duration _idleTimeout = Duration(seconds: 15);
  Duration _connectionTimeout = Duration(seconds: 10);

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

  OkHttpClientBuilder authenticator(Authenticator authenticator) {
    assert(authenticator != null);
    _authenticator = authenticator;
    return this;
  }

  OkHttpClientBuilder proxyAuthenticator(
      ProxyAuthenticator proxyAuthenticator) {
    assert(proxyAuthenticator != null);
    _proxyAuthenticator = proxyAuthenticator;
    return this;
  }

  OkHttpClientBuilder followRedirects(bool value) {
    _followRedirects = value;
    return this;
  }

  OkHttpClientBuilder retryOnConnectionFailure(bool value) {
    _retryOnConnectionFailure = value;
    return this;
  }

  OkHttpClientBuilder idleTimeout(Duration value) {
    _idleTimeout = value;
    return this;
  }

  OkHttpClientBuilder connectionTimeout(Duration value) {
    _connectionTimeout = value;
    return this;
  }

  OkHttpClient build() {
    return OkHttpClient._(this);
  }
}
