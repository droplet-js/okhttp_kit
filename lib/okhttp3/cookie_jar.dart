import 'dart:async';
import 'dart:io';

import 'package:fake_http/okhttp3/http_url.dart';

abstract class CookieJar {
  static const CookieJar NO_COOKIES = _NoCookieJar();

  Future<void> saveFromResponse(HttpUrl url, List<Cookie> cookies);

  Future<List<Cookie>> loadForRequest(HttpUrl url);
}

class _NoCookieJar implements CookieJar {
  const _NoCookieJar();

  @override
  Future<void> saveFromResponse(HttpUrl url, List<Cookie> cookies) async {}

  @override
  Future<List<Cookie>> loadForRequest(HttpUrl url) async {
    return List<Cookie>.unmodifiable(<Cookie>[]);
  }
}
