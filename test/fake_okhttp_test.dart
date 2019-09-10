import 'dart:io';

import 'package:fake_okhttp/okhttp3/cache.dart';
import 'package:fake_okhttp/okhttp3/form_body.dart';
import 'package:fake_okhttp/okhttp3/http_url.dart';
import 'package:fake_okhttp/okhttp3/internal/cache/disk_cache.dart';
import 'package:fake_okhttp/okhttp3/okhttp_client.dart';
import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/request_body.dart';
import 'package:fake_okhttp/okhttp3/response.dart';
import 'package:fake_okhttp/okhttp3/tools/curl_interceptor.dart';
import 'package:fake_okhttp/okhttp3/tools/http_logging_interceptor.dart';
import 'package:fake_okhttp/okhttp3/tools/optimized_request_interceptor.dart';
import 'package:fake_okhttp/okhttp3/tools/persistent_cookie_jar.dart';
import 'package:fake_okhttp/okhttp3/tools/progress_interceptor.dart';
import 'package:fake_okhttp/okhttp3/tools/user_agent_interceptor.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  Directory directory = Directory(path.join(Directory.current.path, 'build', 'cache'));
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  OkHttpClient client = OkHttpClientBuilder()
      .cookieJar(PersistentCookieJar.memory())
      .cache(Cache(DiskCache.create(() => directory)))
      .proxy((Uri url) {
        print('Proxy Url: $url');
        return HttpClient.findProxyFromEnvironment(url);
      })
      .addInterceptor(UserAgentInterceptor(() => 'xxx'))
      .addInterceptor(OptimizedRequestInterceptor(() => true))
//      .addNetworkInterceptor(OptimizedResponseInterceptor())
      .addNetworkInterceptor(CurlInterceptor(true, (String name) {
        return name != HttpHeaders.connectionHeader &&
            name != HttpHeaders.acceptEncodingHeader;
      }))
      .addNetworkInterceptor(HttpLoggingInterceptor(LoggingLevel.headers))
      .addNetworkInterceptor(ProgressRequestInterceptor((HttpUrl url,
          String method, int progressBytes, int totalBytes, bool isDone) {
        print(
            'progress request - $method $url $progressBytes/$totalBytes done:$isDone');
      }))
      .addNetworkInterceptor(ProgressResponseInterceptor((HttpUrl url,
          String method, int progressBytes, int totalBytes, bool isDone) {
        print(
            'progress response - $method $url $progressBytes/$totalBytes done:$isDone');
      }))
      .build();

  test('pub.dev', () async {
    Request request =
        RequestBuilder().get().url(HttpUrl.parse('https://pub.dev/')).build();
    Response response = await client.newCall(request).enqueue();
    print(
        '${response.code()} - ${response.message()} - ${response.cacheControl()}');
  });

  test('baidu.com', () async {
    Request request = RequestBuilder()
        .get()
        .url(HttpUrl.parse('https://www.baidu.com/'))
        .build();
    Response response = await client.newCall(request).enqueue();
    print(
        '${response.code()} - ${response.message()} - ${response.cacheControl()}');
  });

  test('taobao.com', () async {
    Request request = RequestBuilder()
        .get()
        .url(HttpUrl.parse('https://www.taobao.com/'))
        .build();
    Response response = await client.newCall(request).enqueue();
    print(
        '${response.code()} - ${response.message()} - ${response.cacheControl()} - ${(await response.body().bytes()).length}');
  });

  test('fanyi.baidu.com', () async {
    HttpUrl url = HttpUrl.parse('http://fanyi.baidu.com/v2transapi');
    RequestBody body = FormBodyBuilder()
        .add('from', 'zh')
        .add('to', 'en')
        .add('query', '奇数')
        .add('simple_means_flag', '3')
        .add('sign', '763725.1000572')
        .add('token', 'ace5889a5474fc144c730ce9e95878a8')
        .build();
    Request request = RequestBuilder()
        .url(url)
        .header(HttpHeaders.refererHeader, 'http://fanyi.baidu.com/')
        .post(body)
        .build();
    Response response = await client.newCall(request).enqueue();
    print(
        '${response.code()} - ${response.message()} - ${response.cacheControl()} - ${(await response.body().bytes()).length}');
  });
}
