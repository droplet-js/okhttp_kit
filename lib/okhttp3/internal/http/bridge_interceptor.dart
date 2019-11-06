import 'dart:async';
import 'dart:io';

import 'package:okhttp_kit/okhttp3/chain.dart';
import 'package:okhttp_kit/okhttp3/cookie_jar.dart';
import 'package:okhttp_kit/okhttp3/headers.dart';
import 'package:okhttp_kit/okhttp3/interceptor.dart';
import 'package:okhttp_kit/okhttp3/internal/http_extension.dart';
import 'package:okhttp_kit/okhttp3/internal/util.dart';
import 'package:okhttp_kit/okhttp3/internal/version.dart';
import 'package:okhttp_kit/okhttp3/media_type.dart';
import 'package:okhttp_kit/okhttp3/request.dart';
import 'package:okhttp_kit/okhttp3/request_body.dart';
import 'package:okhttp_kit/okhttp3/response.dart';

class BridgeInterceptor implements Interceptor {
  BridgeInterceptor(
    CookieJar cookieJar,
  ) : _cookieJar = cookieJar;

  final CookieJar _cookieJar;

  @override
  Future<Response> intercept(Chain chain) async {
    Request userRequest = chain.request();
    RequestBuilder requestBuilder = userRequest.newBuilder();

    RequestBody body = userRequest.body();
    if (body != null) {
      MediaType contentType = body.contentType();
      if (contentType != null) {
        requestBuilder.header(
            HttpHeaders.contentTypeHeader, contentType.toString());
      }
      int contentLength = body.contentLength();
      if (contentLength != -1) {
        requestBuilder.header(
            HttpHeaders.contentLengthHeader, contentLength.toString());
        requestBuilder.removeHeader(HttpHeaders.transferEncodingHeader);
      } else {
        requestBuilder.header(HttpHeaders.transferEncodingHeader, 'chunked');
        requestBuilder.removeHeader(HttpHeaders.contentLengthHeader);
      }
    }

    if (userRequest.header(HttpHeaders.hostHeader) == null) {
      requestBuilder.header(
          HttpHeaders.hostHeader, Util.hostHeader(userRequest.url(), false));
    }

    if (userRequest.header(HttpHeaders.connectionHeader) == null) {
      requestBuilder.header(HttpHeaders.connectionHeader, 'keep-alive');
    }

    // If we add an "Accept-Encoding: gzip" header field we're responsible for also decompressing
    // the transfer stream.
    bool transparentGzip = false;
    if (userRequest.header(HttpHeaders.acceptEncodingHeader) == null &&
        userRequest.header(HttpHeaders.rangeHeader) == null) {
      transparentGzip = true;
      requestBuilder.header(HttpHeaders.acceptEncodingHeader, 'gzip');
    }

    List<Cookie> cookies = await _cookieJar.loadForRequest(userRequest.url());
    if (cookies.isNotEmpty) {
      requestBuilder.header(HttpHeaders.cookieHeader, _cookieHeader(cookies));
    }

    if (userRequest.header(HttpHeaders.userAgentHeader) == null) {
      requestBuilder.header(HttpHeaders.userAgentHeader, Version.userAgent());
    }

    Response networkResponse = await chain.proceed(requestBuilder.build());

    await HttpHeadersExtension.receiveHeaders(
        _cookieJar, userRequest.url(), networkResponse.headers());

    ResponseBuilder responseBuilder =
        networkResponse.newBuilder().request(userRequest);
    if (transparentGzip &&
        (networkResponse.header(HttpHeaders.contentEncodingHeader) != null &&
            networkResponse
                    .header(HttpHeaders.contentEncodingHeader)
                    .toLowerCase() ==
                'gzip') &&
        HttpHeadersExtension.hasBody(networkResponse)) {
      // Gzip
      Headers strippedHeaders = networkResponse
          .headers()
          .newBuilder()
          .removeAll(HttpHeaders.contentEncodingHeader)
          .removeAll(HttpHeaders.contentLengthHeader)
          .build();
      responseBuilder.headers(strippedHeaders);
    }
    return responseBuilder.build();
  }

  String _cookieHeader(List<Cookie> cookies) {
    return cookies.map((Cookie cookie) {
      return '${cookie.name}=${cookie.value}';
    }).join('; ');
  }
}
