import 'dart:async';
import 'dart:io';

import 'package:fake_okhttp/okhttp3/cache_control.dart';
import 'package:fake_okhttp/okhttp3/chain.dart';
import 'package:fake_okhttp/okhttp3/foundation/basic_types.dart';
import 'package:fake_okhttp/okhttp3/interceptor.dart';
import 'package:fake_okhttp/okhttp3/internal/http/http_method.dart';
import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/response.dart';

/// 应用层拦截器
///
/// 有缓存情况下，如果无网络/请求失败，就使用缓存
class OptimizedRequestInterceptor implements Interceptor {
  OptimizedRequestInterceptor(
      AsyncValueGetter<bool> connectivity,
  )   : assert(connectivity != null),
        _connectivity = connectivity;

  final AsyncValueGetter<bool> _connectivity;

  @override
  Future<Response> intercept(Chain chain) async {
    Request originalRequest = chain.request();
    if (!HttpMethod.invalidatesCache(originalRequest.method())) {
      // 强刷
      if (originalRequest.cacheControl().toString() ==
          CacheControl.forceNetwork.toString()) {
        Request originalFixedRequest = originalRequest
            .newBuilder()
            .removeHeader(HttpHeaders.cacheControlHeader)
            .removeHeader(HttpHeaders.pragmaHeader)
            .cacheControl(CacheControl.forceNetwork)
            .build();
        return await chain.proceed(originalFixedRequest);
      }
      if (originalRequest.cacheControl().toString() ==
          CacheControl.forceCache.toString()) {
        Request originalFixedRequest = originalRequest
            .newBuilder()
            .removeHeader(HttpHeaders.cacheControlHeader)
            .removeHeader(HttpHeaders.pragmaHeader)
            .removeHeader(HttpHeaders.ifNoneMatchHeader)
            .removeHeader(HttpHeaders.ifModifiedSinceHeader)
            .cacheControl(CacheControl.forceCache)
            .build();
        return await chain.proceed(originalFixedRequest);
      }
      Response response;
      // 非强刷
      try {
        response = await chain.proceed(originalRequest);
        // 用户手动调时间，让当前时间小于缓存创建时间，这时候缓存不会过期
        if (response.receivedResponseAtMillis() >
            DateTime.now().millisecondsSinceEpoch) {
          originalRequest = originalRequest
              .newBuilder()
              .removeHeader(HttpHeaders.cacheControlHeader)
              .removeHeader(HttpHeaders.pragmaHeader)
              .cacheControl(CacheControl.forceNetwork)
              .build();
          response = await chain.proceed(originalRequest);
        }
      } on SocketException catch (e) {
        if (await shouldUseCacheIfWeakConnect(originalRequest, e)) {
          Request forceCacheRequest = originalRequest
              .newBuilder()
              .removeHeader(HttpHeaders.cacheControlHeader)
              .removeHeader(HttpHeaders.pragmaHeader)
              .removeHeader(HttpHeaders.ifNoneMatchHeader)
              .removeHeader(HttpHeaders.ifModifiedSinceHeader)
              .cacheControl(CacheControl.forceCache)
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
              .cacheControl(CacheControl.forceCache)
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
              .cacheControl(CacheControl.forceCache)
              .build();
          response = await chain.proceed(forceCacheRequest);
          return response;
        }
      }
      return response;
    }
    return await chain.proceed(originalRequest);
  }

  Future<bool> shouldUseCacheIfWeakConnect(
      Request originalRequest, Exception e) async {
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
