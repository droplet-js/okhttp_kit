import 'dart:io';

import 'package:fake_http/okhttp3/cache_control.dart';
import 'package:fake_http/okhttp3/headers.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response_body.dart';

class Response {
  final Request _request;
  final int _code;
  final String _message;
  final Headers _headers;
  final ResponseBody _body;
  final Response _networkResponse;
  final Response _cacheResponse;
  final Response _priorResponse;
  final int _sentRequestAtMillis;
  final int _receivedResponseAtMillis;

  CacheControl _cacheControl;

  Response._(ResponseBuilder builder)
      : _request = builder._request,
        _code = builder._code,
        _message = builder._message,
        _headers = builder._headers.build(),
        _body = builder._body,
        _networkResponse = builder._networkResponse,
        _cacheResponse = builder._cacheResponse,
        _priorResponse = builder._priorResponse,
        _sentRequestAtMillis = builder._sentRequestAtMillis,
        _receivedResponseAtMillis = builder._receivedResponseAtMillis;

  Request request() {
    return _request;
  }

  int code() {
    return _code;
  }

  bool isSuccessful() {
    return _code >= HttpStatus.ok && _code < HttpStatus.multipleChoices;
  }

  String message() {
    return _message;
  }

  String header(String name) {
    return _headers.value(name);
  }

  Headers headers() {
    return _headers;
  }

  ResponseBody body() {
    return _body;
  }

  Response networkResponse() {
    return _networkResponse;
  }

  Response cacheResponse() {
    return _cacheResponse;
  }

  Response priorResponse() {
    return _priorResponse;
  }

  CacheControl cacheControl() {
    if (_cacheControl == null) {
      _cacheControl = CacheControl.parse(_headers);
    }
    return _cacheControl;
  }

  int sentRequestAtMillis() {
    return _sentRequestAtMillis;
  }

  int receivedResponseAtMillis() {
    return _receivedResponseAtMillis;
  }

  ResponseBuilder newBuilder() {
    return new ResponseBuilder._(this);
  }
}

class ResponseBuilder {
  Request _request;
  int _code = -1;
  String _message;
  HeadersBuilder _headers;
  ResponseBody _body;
  Response _networkResponse;
  Response _cacheResponse;
  Response _priorResponse;
  int _sentRequestAtMillis = 0;
  int _receivedResponseAtMillis = 0;

  ResponseBuilder() : _headers = new HeadersBuilder();

  ResponseBuilder._(Response response)
      : _request = response._request,
        _code = response._code,
        _message = response._message,
        _headers = response._headers.newBuilder(),
        _body = response._body,
        _networkResponse = response._networkResponse,
        _cacheResponse = response._cacheResponse,
        _priorResponse = response._priorResponse,
        _sentRequestAtMillis = response._sentRequestAtMillis,
        _receivedResponseAtMillis = response._receivedResponseAtMillis;

  ResponseBuilder request(Request value) {
    _request = value;
    return this;
  }

  ResponseBuilder code(int value) {
    _code = value;
    return this;
  }

  ResponseBuilder message(String value) {
    _message = value;
    return this;
  }

  ResponseBuilder header(String name, String value) {
    _headers.set(name, value);
    return this;
  }

  ResponseBuilder addHeader(String name, String value) {
    _headers.add(name, value);
    return this;
  }

  ResponseBuilder removeHeader(String name) {
    _headers.removeAll(name);
    return this;
  }

  ResponseBuilder headers(Headers value) {
    _headers = value.newBuilder();
    return this;
  }

  ResponseBuilder body(ResponseBody value) {
    _body = value;
    return this;
  }

  ResponseBuilder networkResponse(Response value) {
    _networkResponse = value;
    return this;
  }

  ResponseBuilder cacheResponse(Response value) {
    _cacheResponse = value;
    return this;
  }

  ResponseBuilder priorResponse(Response value) {
    _priorResponse = value;
    return this;
  }

  ResponseBuilder sentRequestAtMillis(int value) {
    _sentRequestAtMillis = value;
    return this;
  }

  ResponseBuilder receivedResponseAtMillis(int value) {
    _receivedResponseAtMillis = value;
    return this;
  }

  Response build() {
    assert(_request != null);
    if (_code < 0) {
      throw new AssertionError('code < 0: $_code');
    }
    assert(_message != null);
    return new Response._(this);
  }
}
