import 'dart:async';
import 'dart:io';

import 'package:fake_http/okhttp3/cache.dart';
import 'package:fake_http/okhttp3/headers.dart';
import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/internal/cache/cache_strategy.dart';
import 'package:fake_http/okhttp3/internal/http/http_method.dart';
import 'package:fake_http/okhttp3/internal/http/real_response_body.dart';
import 'package:fake_http/okhttp3/internal/http_extension.dart';
import 'package:fake_http/okhttp3/internal/util.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';

class CacheInterceptor implements Interceptor {
  final Cache _cache;

  CacheInterceptor(Cache cache) : _cache = cache;

  @override
  Future<Response> intercept(Chain chain) async {
    Response cacheCandidate =
        _cache != null ? await _cache.get(chain.request()) : null;

    int now = new DateTime.now().millisecondsSinceEpoch;

    CacheStrategy strategy =
        new CacheStrategyFactory(now, chain.request(), cacheCandidate).get();
    Request networkRequest = strategy.networkRequest;
    Response cacheResponse = strategy.cacheResponse;

    if (_cache != null) {
      await _cache.trackResponse(strategy);
    }

    if (cacheCandidate != null && cacheResponse == null) {
      Util.closeQuietly(cacheCandidate
          .body()); // The cache candidate wasn't applicable. Close it.
    }

    // If we're forbidden from using the network and the cache is insufficient, fail.
    if (networkRequest == null && cacheResponse == null) {
      return new ResponseBuilder()
          .request(chain.request())
          .code(HttpStatus.gatewayTimeout)
          .message("Unsatisfiable Request (only-if-cached)")
          .body(Util.EMPTY_RESPONSE)
          .sentRequestAtMillis(-1)
          .receivedResponseAtMillis(new DateTime.now().millisecondsSinceEpoch)
          .build();
    }

    // If we don't need the network, we're done.
    if (networkRequest == null) {
      return cacheResponse
          .newBuilder()
          .cacheResponse(_stripBody(cacheResponse))
          .build();
    }

    Response networkResponse;
    try {
      networkResponse = await chain.proceed(networkRequest);
    } finally {
      // If we're crashing on I/O or otherwise, don't leak the cache body.
      if (networkResponse == null && cacheCandidate != null) {
        Util.closeQuietly(cacheCandidate.body());
      }
    }

    // If we have a cache response too, then we're doing a conditional get.
    if (cacheResponse != null) {
      if (networkResponse.code() == HttpStatus.notModified) {
        Response response = cacheResponse
            .newBuilder()
            .headers(
                _combine(cacheResponse.headers(), networkResponse.headers()))
            .sentRequestAtMillis(networkResponse.sentRequestAtMillis())
            .receivedResponseAtMillis(
                networkResponse.receivedResponseAtMillis())
            .cacheResponse(_stripBody(cacheResponse))
            .networkResponse(_stripBody(networkResponse))
            .build();
        Util.closeQuietly(networkResponse.body());

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
        await _cache.trackConditionalCacheHit();
        await _cache.update(cacheResponse, response);
        return response;
      } else {
        Util.closeQuietly(cacheResponse.body());
      }
    }

    Response response = networkResponse
        .newBuilder()
        .cacheResponse(_stripBody(cacheResponse))
        .networkResponse(_stripBody(networkResponse))
        .build();

    if (_cache != null) {
      if (HttpHeadersExtension.hasBody(response) &&
          CacheStrategy.isCacheable(response, networkRequest)) {
        // Offer this request to the cache.
        CacheRequest cacheRequest = await _cache.put(response);
        return _cacheWritingResponse(cacheRequest, response);
      }

      if (HttpMethod.invalidatesCache(networkRequest.method())) {
        try {
          await _cache.remove(networkRequest);
        } catch (e) {
          // The cache cannot be written.
        }
      }
    }

    return response;
  }

  static Response _stripBody(Response response) {
    return response != null && response.body() != null
        ? response.newBuilder().body(null).build()
        : response;
  }

  /// Combines cached headers with a network headers as defined by RFC 7234, 4.3.4.
  static Headers _combine(Headers cachedHeaders, Headers networkHeaders) {
    HeadersBuilder result = new HeadersBuilder();

    for (int i = 0, size = cachedHeaders.size(); i < size; i++) {
      String name = cachedHeaders.nameAt(i);
      String value = cachedHeaders.valueAt(i);
      if (name == HttpHeaders.warningHeader && value.startsWith('1')) {
        continue; // Drop 100-level freshness warnings.
      }
      if (_isContentSpecificHeader(name) ||
          !_isEndToEnd(name) ||
          networkHeaders.value(name) == null) {
        result.addLenient(name, value);
      }
    }

    for (int i = 0, size = networkHeaders.size(); i < size; i++) {
      String name = networkHeaders.nameAt(i);
      if (!_isContentSpecificHeader(name) && _isEndToEnd(name)) {
        result.addLenient(name, networkHeaders.valueAt(i));
      }
    }

    return result.build();
  }

  static bool _isContentSpecificHeader(String name) {
    return name == HttpHeaders.contentLengthHeader ||
        name == HttpHeaders.contentEncodingHeader ||
        name == HttpHeaders.contentTypeHeader;
  }

  static bool _isEndToEnd(String name) {
    return name != HttpHeaders.connectionHeader &&
        name != 'keep-alive' &&
        name != HttpHeaders.proxyAuthenticateHeader &&
        name != HttpHeaders.proxyAuthorizationHeader &&
        name != HttpHeaders.teHeader &&
        name != HttpHeaders.trailerHeader &&
        name != HttpHeaders.transferEncodingHeader &&
        name != HttpHeaders.upgradeHeader;
  }

  Future<Response> _cacheWritingResponse(
      CacheRequest cacheRequest, Response response) async {
    if (cacheRequest == null) {
      return response;
    }
    EventSink<List<int>> cacheBody =
        cacheRequest.body(); // 用作 EventSink，不然 StreamTransformer close 会报错
    if (cacheBody == null) {
      return response;
    }

    Stream<List<int>> source = response.body().source();

    StreamTransformer<List<int>, List<int>> streamTransformer =
        new StreamTransformer.fromHandlers(handleData:
            (List<int> data, EventSink<List<int>> sink) {
      sink.add(data);
      cacheBody.add(data);
    }, handleError:
            (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
      sink.addError(error, stackTrace);
      cacheBody.addError(error, stackTrace);
      cacheRequest.abort();
    }, handleDone: (EventSink<List<int>> sink) {
      sink.close();
      cacheBody.close();
      cacheRequest.commit();
    });

    Stream<List<int>> cacheWritingSource = source.transform(streamTransformer);

    String contentType = response.header(HttpHeaders.contentTypeHeader);
    int contentLength = response.body().contentLength();
    return response
        .newBuilder()
        .body(new RealResponseBody(
            contentType, contentLength, cacheWritingSource))
        .build();
  }
}
