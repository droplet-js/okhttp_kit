import 'dart:async';
import 'dart:io';

import 'package:fake_http/okhttp3/cache_control.dart';
import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/internal/http/http_method.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';

/// 网络层拦截器
/// 优化缓存
///
/// https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Caching_FAQ
class OptimizedResponseInterceptor implements Interceptor {
  final int _maxAgeSeconds;

  OptimizedResponseInterceptor({int maxAgeSeconds: 3})
      : _maxAgeSeconds = maxAgeSeconds;

  @override
  Future<Response> intercept(Chain chain) async {
    Request originalRequest = chain.request();
    Response originalResponse = await chain.proceed(originalRequest);
    if (!HttpMethod.invalidatesCache(originalRequest.method())) {
      if (originalResponse.isSuccessful()) {
        if (originalResponse.header(HttpHeaders.lastModifiedHeader) == null &&
            originalResponse.header(HttpHeaders.etagHeader) == null &&
            originalResponse.header(HttpHeaders.expiresHeader) == null &&
            originalResponse.header(HttpHeaders.ageHeader) == null) {
          // 智能添加缓存信息
          bool shouldOptimizedCache = false;
          if (originalResponse.header(HttpHeaders.cacheControlHeader) == null &&
              originalResponse.header(HttpHeaders.pragmaHeader) == null) {
            shouldOptimizedCache = true;
          } else {
            CacheControl cacheControl = originalResponse.cacheControl();
            shouldOptimizedCache =
                cacheControl.noCache() || cacheControl.noStore();
          }
          if (shouldOptimizedCache) {
            return originalResponse
                .newBuilder()
                .removeHeader(HttpHeaders.pragmaHeader)
                .header(
                    HttpHeaders.cacheControlHeader,
                    new CacheControlBuilder()
                        .maxAge(new Duration(seconds: _maxAgeSeconds))
                        .build()
                        .toString())
                .build();
          }
        }
      }
    }
    return originalResponse;
  }
}
