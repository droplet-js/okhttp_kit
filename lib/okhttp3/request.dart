import 'dart:io';

import 'package:fake_http/okhttp3/cache_control.dart';
import 'package:fake_http/okhttp3/headers.dart';
import 'package:fake_http/okhttp3/http_url.dart';
import 'package:fake_http/okhttp3/internal/http/http_method.dart';
import 'package:fake_http/okhttp3/request_body.dart';

class Request {
  final HttpUrl _url;
  final String _method;
  final Headers _headers;
  final RequestBody _body;

  CacheControl _cacheControl;

  Request._(RequestBuilder builder)
      : _url = builder._url,
        _method = builder._method,
        _headers = builder._headers.build(),
        _body = builder._body;

  HttpUrl url() {
    return _url;
  }

  String method() {
    return _method;
  }

  String header(String name) {
    return _headers.value(name);
  }

  Headers headers() {
    return _headers;
  }

  CacheControl cacheControl() {
    if (_cacheControl == null) {
      _cacheControl = CacheControl.parse(_headers);
    }
    return _cacheControl;
  }

  RequestBody body() {
    return _body;
  }

  RequestBuilder newBuilder() {
    return new RequestBuilder._(this);
  }
}

class RequestBuilder {
  HttpUrl _url;
  String _method;
  HeadersBuilder _headers;
  RequestBody _body;

  RequestBuilder()
      : _method = HttpMethod.GET,
        _headers = new HeadersBuilder();

  RequestBuilder._(Request request)
      : _url = request._url,
        _method = request._method,
        _headers = request._headers.newBuilder(),
        _body = request._body;

  RequestBuilder url(HttpUrl value) {
    _url = value;
    return this;
  }

  RequestBuilder header(String name, String value) {
    _headers.set(name, value);
    return this;
  }

  RequestBuilder addHeader(String name, String value) {
    _headers.add(name, value);
    return this;
  }

  RequestBuilder removeHeader(String name) {
    _headers.removeAll(name);
    return this;
  }

  RequestBuilder headers(Headers headers) {
    _headers = headers.newBuilder();
    return this;
  }

  RequestBuilder cacheControl(CacheControl cacheControl) {
    String value = cacheControl != null ? cacheControl.toString() : '';
    if (value.isEmpty) {
      return removeHeader(HttpHeaders.cacheControlHeader);
    }
    return header(HttpHeaders.cacheControlHeader, value);
  }

  RequestBuilder get() {
    return method(HttpMethod.GET, null);
  }

  RequestBuilder head() {
    return method(HttpMethod.HEAD, null);
  }

  RequestBuilder post(RequestBody body) {
    return method(HttpMethod.POST, body);
  }

  RequestBuilder delete(RequestBody body) {
    return method(HttpMethod.DELETE, body);
  }

  RequestBuilder put(RequestBody body) {
    return method(HttpMethod.PUT, body);
  }

  RequestBuilder patch(RequestBody body) {
    return method(HttpMethod.PATCH, body);
  }

  RequestBuilder method(String method, RequestBody body) {
    assert(method != null && method.isNotEmpty);
    if (body != null && !HttpMethod.permitsRequestBody(method)) {
      throw new AssertionError('method $method must not have a request body.');
    }
    if (body == null && HttpMethod.requiresRequestBody(method)) {
      throw new AssertionError('method $method must have a request body.');
    }
    _method = method;
    _body = body;
    return this;
  }

  Request build() {
    assert(_url != null);
    return new Request._(this);
  }
}
