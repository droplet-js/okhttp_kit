import 'dart:async';
import 'dart:io';

import 'package:fake_okhttp/okhttp3/chain.dart';
import 'package:fake_okhttp/okhttp3/interceptor.dart';
import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/response.dart';

/// 应用层拦截器
class UserAgentInterceptor implements Interceptor {
  UserAgentInterceptor(
      FutureOr<String> userAgent(),
  )   : assert(userAgent != null),
        _userAgent = userAgent;

  final FutureOr<String> Function() _userAgent;

  @override
  Future<Response> intercept(Chain chain) async {
    Request originalRequest = chain.request();
    String userAgent = originalRequest.header(HttpHeaders.userAgentHeader);
    if (userAgent != null) {
      return await chain.proceed(originalRequest);
    }
    Response response = await chain.proceed(originalRequest
        .newBuilder()
        .header(HttpHeaders.userAgentHeader, await _userAgent())
        .build());
    return response.newBuilder().request(originalRequest).build();
  }
}
