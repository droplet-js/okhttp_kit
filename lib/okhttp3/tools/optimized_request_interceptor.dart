import 'dart:async';
import 'dart:io';

import 'package:fake_http/okhttp3/cache_control.dart';
import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/internal/http/http_method.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';
import 'package:flutter/foundation.dart';

/// 应用层拦截器
///
/// 有缓存情况下，如果无网络/请求失败，就使用缓存
class OptimizedRequestInterceptor implements Interceptor {
  AsyncValueGetter<bool> _connectivity;

  OptimizedRequestInterceptor(AsyncValueGetter<bool> connectivity)
      : assert(connectivity != null),
        _connectivity = connectivity;

  @override
  Future<Response> intercept(Chain chain) async {
    Request originalRequest = chain.request();
    if (!HttpMethod.invalidatesCache(originalRequest.method())) {
      // 强刷
      if (originalRequest.cacheControl().toString() ==
          CacheControl.FORCE_NETWORK.toString()) {
        Request originalFixedRequest = originalRequest
            .newBuilder()
            .removeHeader(HttpHeaders.cacheControlHeader)
            .removeHeader(HttpHeaders.pragmaHeader)
            .cacheControl(CacheControl.FORCE_NETWORK)
            .build();
        return await chain.proceed(originalFixedRequest);
      }
      if (originalRequest.cacheControl().toString() ==
          CacheControl.FORCE_CACHE.toString()) {
        Request originalFixedRequest = originalRequest
            .newBuilder()
            .removeHeader(HttpHeaders.cacheControlHeader)
            .removeHeader(HttpHeaders.pragmaHeader)
            .removeHeader(HttpHeaders.ifNoneMatchHeader)
            .removeHeader(HttpHeaders.ifModifiedSinceHeader)
            .cacheControl(CacheControl.FORCE_CACHE)
            .build();
        return await chain.proceed(originalFixedRequest);
      }
      Response response;
      // 非强刷
      try {
        response = await chain.proceed(originalRequest);
        // 用户手动调时间，让当前时间小于缓存创建时间，这时候缓存不会过期
        if (response.receivedResponseAtMillis() >
            new DateTime.now().millisecondsSinceEpoch) {
          originalRequest = originalRequest
              .newBuilder()
              .removeHeader(HttpHeaders.cacheControlHeader)
              .removeHeader(HttpHeaders.pragmaHeader)
              .cacheControl(CacheControl.FORCE_NETWORK)
              .build();
          response = await chain.proceed(originalRequest);
        }
      } on SocketException catch (e) {
        if (await shouldUseCacheIfWeakConnect(originalRequest)) {
          Request forceCacheRequest = originalRequest
              .newBuilder()
              .removeHeader(HttpHeaders.cacheControlHeader)
              .removeHeader(HttpHeaders.pragmaHeader)
              .removeHeader(HttpHeaders.ifNoneMatchHeader)
              .removeHeader(HttpHeaders.ifModifiedSinceHeader)
              .cacheControl(CacheControl.FORCE_CACHE)
              .build();
          return await chain.proceed(forceCacheRequest);
        } else {
          rethrow;
        }
      } on IOException catch (e) {
        // 判断是否需要强制调用缓存
        if (await shouldUseCacheIfThrowError(originalRequest, e)) {
          Request forceCacheRequest = originalRequest
              .newBuilder()
              .removeHeader(HttpHeaders.cacheControlHeader)
              .removeHeader(HttpHeaders.pragmaHeader)
              .removeHeader(HttpHeaders.ifNoneMatchHeader)
              .removeHeader(HttpHeaders.ifModifiedSinceHeader)
              .cacheControl(CacheControl.FORCE_CACHE)
              .build();
          return await chain.proceed(forceCacheRequest);
        } else {
          rethrow;
        }
      }
      if (response.code() == HttpStatus.internalServerError) {
        // 判断是否需要强制调用缓存
        if (await shouldUseCacheIfServerError(originalRequest)) {
          Request forceCacheRequest = originalRequest
              .newBuilder()
              .removeHeader(HttpHeaders.cacheControlHeader)
              .removeHeader(HttpHeaders.pragmaHeader)
              .removeHeader(HttpHeaders.ifNoneMatchHeader)
              .removeHeader(HttpHeaders.ifModifiedSinceHeader)
              .cacheControl(CacheControl.FORCE_CACHE)
              .build();
          response = await chain.proceed(forceCacheRequest);
          return response;
        }
      }
      return response;
    }
    return await chain.proceed(originalRequest);
  }

  Future<bool> shouldUseCacheIfWeakConnect(Request originalRequest) async {
    return true;
  }

  Future<bool> shouldUseCacheIfServerError(Request originalRequest) async {
    return true;
  }

  Future<bool> shouldUseCacheIfThrowError(
      Request originalRequest, Exception e) async {
    return !await _connectivity();
  }
}
