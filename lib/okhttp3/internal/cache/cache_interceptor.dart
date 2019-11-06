import 'dart:async';
import 'dart:io';

import 'package:okhttp_kit/okhttp3/cache.dart';
import 'package:okhttp_kit/okhttp3/chain.dart';
import 'package:okhttp_kit/okhttp3/headers.dart';
import 'package:okhttp_kit/okhttp3/interceptor.dart';
import 'package:okhttp_kit/okhttp3/internal/cache/cache_strategy.dart';
import 'package:okhttp_kit/okhttp3/internal/http/http_method.dart';
import 'package:okhttp_kit/okhttp3/internal/http_extension.dart';
import 'package:okhttp_kit/okhttp3/internal/util.dart';
import 'package:okhttp_kit/okhttp3/request.dart';
import 'package:okhttp_kit/okhttp3/response.dart';
import 'package:okhttp_kit/okhttp3/response_body.dart';

class CacheInterceptor implements Interceptor {
  CacheInterceptor(
    Cache cache,
  ) : _cache = cache;

  final Cache _cache;

  @override
  Future<Response> intercept(Chain chain) async {
    Response cacheCandidate =
        _cache != null ? await _cache.get(chain.request()) : null;

    int now = DateTime.now().millisecondsSinceEpoch;

    CacheStrategy strategy =
        CacheStrategyFactory(now, chain.request(), cacheCandidate).get();
    Request networkRequest = strategy.networkRequest;
    Response cacheResponse = strategy.cacheResponse;

    if (_cache != null) {
      await _cache.trackResponse(strategy);
    }

    // If we're forbidden from using the network and the cache is insufficient, fail.
    if (networkRequest == null && cacheResponse == null) {
      return ResponseBuilder()
          .request(chain.request())
          .code(HttpStatus.gatewayTimeout)
          .message("Unsatisfiable Request (only-if-cached)")
          .body(Util.emptyResponse)
          .sentRequestAtMillis(-1)
          .receivedResponseAtMillis(DateTime.now().millisecondsSinceEpoch)
          .build();
    }

    // If we don't need the network, we're done.
    if (networkRequest == null) {
      return cacheResponse
          .newBuilder()
          .cacheResponse(_stripBody(cacheResponse))
          .build();
    }

    Response networkResponse = await chain.proceed(networkRequest);

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

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
        await _cache.trackConditionalCacheHit();
        await _cache.update(cacheResponse, response);
        return response;
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

  Future<Response> _cacheWritingResponse(
      CacheRequest cacheRequest, Response response) async {
    if (cacheRequest == null) {
      return response;
    }
    EventSink<List<int>> cacheSink =
        cacheRequest.body(); // 用作 EventSink，不然 StreamTransformer close 会报错
    if (cacheSink == null) {
      return response;
    }

    Stream<List<int>> cacheWritingSource =
        StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        sink.add(data);
        cacheSink.add(data);
      },
      handleError:
          (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
        sink.addError(error, stackTrace);
        cacheSink.addError(error, stackTrace);
      },
      handleDone: (EventSink<List<int>> sink) {
        sink.close();
        cacheSink.close();
      },
    ).bind(response.body().source());

    return response
        .newBuilder()
        .body(ResponseBody.streamBody(response.body().contentType(),
            response.body().contentLength(), cacheWritingSource))
        .build();
  }

  static Response _stripBody(Response response) {
    return response != null && response.body() != null
        ? response.newBuilder().body(null).build()
        : response;
  }

  /// Combines cached headers with a network headers as defined by RFC 7234, 4.3.4.
  static Headers _combine(Headers cachedHeaders, Headers networkHeaders) {
    HeadersBuilder result = HeadersBuilder();

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
}
