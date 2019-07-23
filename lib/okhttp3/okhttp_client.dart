import 'package:fake_okhttp/okhttp3/cache.dart';
import 'package:fake_okhttp/okhttp3/call.dart';
import 'package:fake_okhttp/okhttp3/cookie_jar.dart';
import 'package:fake_okhttp/okhttp3/interceptor.dart';
import 'package:fake_okhttp/okhttp3/proxy.dart';
import 'package:fake_okhttp/okhttp3/request.dart';

class OkHttpClient {
  OkHttpClient._(
    OkHttpClientBuilder builder,
  )   : _interceptors = List<Interceptor>.unmodifiable(builder._interceptors),
        _networkInterceptors =
            List<Interceptor>.unmodifiable(builder._networkInterceptors),
        _proxy = builder._proxy,
        _proxySelector = builder._proxySelector,
        _cookieJar = builder._cookieJar,
        _cache = builder._cache,
        _followRedirects = builder._followRedirects,
        _maxRedirects = builder._maxRedirects,
        _idleTimeout = builder._idleTimeout,
        _connectionTimeout = builder._connectionTimeout;

  final List<Interceptor> _interceptors;
  final List<Interceptor> _networkInterceptors;

  final Proxy _proxy;
  final ProxySelector _proxySelector;

  final CookieJar _cookieJar;
  final Cache _cache;

  final bool _followRedirects;
  final int _maxRedirects;

  final Duration _idleTimeout;
  final Duration _connectionTimeout;

  List<Interceptor> interceptors() {
    return _interceptors;
  }

  List<Interceptor> networkInterceptors() {
    return _networkInterceptors;
  }

  Proxy proxy() {
    return _proxy;
  }

  ProxySelector proxySelector() {
    return _proxySelector;
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
      : _proxy = client._proxy,
        _proxySelector = client._proxySelector,
        _cookieJar = client._cookieJar,
        _cache = client._cache,
        _followRedirects = client._followRedirects,
        _maxRedirects = client._maxRedirects,
        _idleTimeout = client._idleTimeout,
        _connectionTimeout = client._connectionTimeout {
    _interceptors.addAll(client._interceptors);
    _networkInterceptors.addAll(client._networkInterceptors);
  }

  final List<Interceptor> _interceptors = <Interceptor>[];
  final List<Interceptor> _networkInterceptors = <Interceptor>[];

  Proxy _proxy;
  ProxySelector _proxySelector;

  CookieJar _cookieJar = CookieJar.noCookies;
  Cache _cache;

  bool _followRedirects = true;
  int _maxRedirects = 5;

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

  OkHttpClientBuilder proxy(Proxy proxy) {
    _proxy = proxy;
    return this;
  }

  OkHttpClientBuilder proxySelector(ProxySelector proxySelector) {
    _proxySelector = proxySelector;
    return this;
  }

  OkHttpClientBuilder cookieJar(CookieJar cookieJar) {
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

  OkHttpClient build() {
    return OkHttpClient._(this);
  }
}
