import 'dart:async';
import 'dart:io';

import 'package:charcode/ascii.dart' as Ascii;
import 'package:fake_http/okhttp3/cookie_jar.dart';
import 'package:fake_http/okhttp3/headers.dart';
import 'package:fake_http/okhttp3/http_url.dart';
import 'package:fake_http/okhttp3/internal/http/http_method.dart';
import 'package:fake_http/okhttp3/internal/util.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';

class HttpHeadersExtension {
  HttpHeadersExtension._();

  static const String contentDispositionHeader = 'content-disposition';

  static int skipUntil(String input, int pos, String characters) {
    for (; pos < input.length; pos++) {
      if (characters.indexOf(input[pos]) != -1) {
        break;
      }
    }
    return pos;
  }

  static int skipWhitespace(String input, int pos) {
    for (; pos < input.length; pos++) {
      String c = input[pos];
      if (c != ' ' && c != '\t') {
        break;
      }
    }
    return pos;
  }

  static Future<void> receiveHeaders(
      CookieJar cookieJar, HttpUrl url, Headers headers) async {
    if (cookieJar == CookieJar.NO_COOKIES) {
      return;
    }
    List<Cookie> cookies = CookieExtension.parseAllCookies(url, headers);
    if (cookies.isEmpty) {
      return;
    }
    await cookieJar.saveFromResponse(url, cookies);
  }

  static bool hasBody(Response response) {
    // HEAD requests never yield a body regardless of the response headers.
    if (response.request().method() == HttpMethod.HEAD) {
      return false;
    }

    int responseCode = response.code();
    if ((responseCode < HttpStatus.continue_ ||
            responseCode >= HttpStatus.ok) &&
        responseCode != HttpStatus.noContent &&
        responseCode != HttpStatus.notModified) {
      return true;
    }

    // If the Content-Length or Transfer-Encoding headers disagree with the response code, the
    // response is malformed. For best compatibility, we honor the headers.
    if (contentLength(response) != -1 ||
        (response.header(HttpHeaders.transferEncodingHeader) != null &&
            response.header(HttpHeaders.transferEncodingHeader).toLowerCase() ==
                'chunked')) {
      return true;
    }

    return false;
  }

  static int contentLength(Response response) {
    String contentLength = response.header(HttpHeaders.contentLengthHeader);
    return contentLength != null ? int.parse(contentLength) : -1;
  }

  static bool varyMatches(
      Response cachedResponse, Headers cachedVaryHeaders, Request newRequest) {
    Set<String> fields = varyFields(cachedResponse.headers());
    for (String field in fields) {
      List<String> cachedVaryHeaderValues = cachedVaryHeaders.values(field);
      List<String> newRequestHeaderValues = newRequest.headers().values(field);
      if (cachedVaryHeaderValues.length != newRequestHeaderValues.length) {
        return false;
      }
      for (String cachedVaryHeaderValue in cachedVaryHeaderValues) {
        if (newRequestHeaderValues.indexOf(cachedVaryHeaderValue) == -1) {
          return false;
        }
      }
    }
    return true;
  }

  static Headers varyHeaders(Response response) {
    // Use the request headers sent over the network, since that's what the
    // response varies on. Otherwise OkHttp-supplied headers like
    // "Accept-Encoding: gzip" may be lost.
    Headers requestHeaders = response.networkResponse().request().headers();
    Headers responseHeaders = response.headers();
    return _varyHeaders(requestHeaders, responseHeaders);
  }

  static Headers _varyHeaders(Headers requestHeaders, Headers responseHeaders) {
    Set<String> fields = varyFields(responseHeaders);
    if (fields.isEmpty) {
      return HeadersBuilder().build();
    }

    HeadersBuilder result = HeadersBuilder();
    for (int i = 0, size = requestHeaders.size(); i < size; i++) {
      String name = requestHeaders.nameAt(i);
      if (fields.contains(name)) {
        result.add(name, requestHeaders.valueAt(i));
      }
    }
    return result.build();
  }

  static bool hasVaryAll(Headers responseHeaders) {
    return varyFields(responseHeaders).contains("*");
  }

  static Set<String> varyFields(Headers responseHeaders) {
    Set<String> result = Set();
    for (int i = 0, size = responseHeaders.size(); i < size; i++) {
      if (HttpHeaders.varyHeader != responseHeaders.nameAt(i)) {
        continue;
      }
      String value = responseHeaders.valueAt(i);
      for (String varyField in value.split(",")) {
        result.add(varyField.trim());
      }
    }
    return result;
  }
}

class CookieExtension {
  CookieExtension._();

  static List<Cookie> parseAllCookies(HttpUrl url, Headers headers) {
    List<Cookie> cookies = [];
    List<String> cookieStrings = headers.values(HttpHeaders.setCookieHeader);
    cookieStrings.forEach((String value) {
      Cookie cookie = Cookie.fromSetCookieValue(value);
      if (cookie.domain == null || domainMatch(url.host(), cookie.domain)) {
        cookies.add(cookie);
      }
    });
    return List.unmodifiable(cookies);
  }

  static bool domainMatch(String urlHost, String domain) {
    if (urlHost == domain) {
      return true;
    }
    if (urlHost.endsWith(domain) &&
        urlHost.codeUnitAt(urlHost.length - domain.length - 1) == Ascii.$dot &&
        !Util.verifyAsIpAddress(urlHost)) {
      return true; // As in 'example.com' matching 'www.example.com'.
    }
    return false;
  }
}

class HttpStatusExtension {
  static const int permanentRedirect = 308;
}
