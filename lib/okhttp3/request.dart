import 'dart:io';

import 'package:okhttp_kit/okhttp3/cache_control.dart';
import 'package:okhttp_kit/okhttp3/headers.dart';
import 'package:okhttp_kit/okhttp3/http_url.dart';
import 'package:okhttp_kit/okhttp3/internal/http/http_method.dart';
import 'package:okhttp_kit/okhttp3/request_body.dart';

class Request {
  Request._(
    RequestBuilder builder,
  )   : _url = builder._url,
        _method = builder._method,
        _headers = builder._headers.build(),
        _body = builder._body;

  final HttpUrl _url;
  final String _method;
  final Headers _headers;
  final RequestBody _body;

  CacheControl _cacheControl;

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
    return RequestBuilder._(this);
  }
}

class RequestBuilder {
  RequestBuilder()
      : _method = HttpMethod.get,
        _headers = HeadersBuilder();

  RequestBuilder._(
    Request request,
  )   : _url = request._url,
        _method = request._method,
        _headers = request._headers.newBuilder(),
        _body = request._body;

  HttpUrl _url;
  String _method;
  HeadersBuilder _headers;
  RequestBody _body;

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
    String value = cacheControl?.toString() ?? '';
    if (value.isEmpty) {
      return removeHeader(HttpHeaders.cacheControlHeader);
    }
    return header(HttpHeaders.cacheControlHeader, value);
  }

  RequestBuilder get() {
    return method(HttpMethod.get, null);
  }

  RequestBuilder head() {
    return method(HttpMethod.head, null);
  }

  RequestBuilder post(RequestBody body) {
    return method(HttpMethod.post, body);
  }

  RequestBuilder delete(RequestBody body) {
    return method(HttpMethod.delete, body);
  }

  RequestBuilder put(RequestBody body) {
    return method(HttpMethod.put, body);
  }

  RequestBuilder patch(RequestBody body) {
    return method(HttpMethod.patch, body);
  }

  RequestBuilder method(String method, RequestBody body) {
    assert(method != null && method.isNotEmpty);
    if (body != null && !HttpMethod.permitsRequestBody(method)) {
      throw AssertionError('method $method must not have a request body.');
    }
    if (body == null && HttpMethod.requiresRequestBody(method)) {
      throw AssertionError('method $method must have a request body.');
    }
    _method = method;
    _body = body;
    return this;
  }

  Request build() {
    assert(_url != null);
    return Request._(this);
  }
}
