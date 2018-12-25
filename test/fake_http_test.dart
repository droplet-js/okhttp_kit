import 'package:test/test.dart';

import 'package:fake_http/fake_http.dart';

void main() {
  FileSystem fileSystem = new LocalFileSystem();

  print(
      '${fileSystem.currentDirectory.path} - ${fileSystem.systemTempDirectory.path}');

  Directory directory = fileSystem.currentDirectory
      .childDirectory('build')
      .childDirectory('cache');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  OkHttpClient client = new OkHttpClientBuilder()
      .cache(new Cache(DiskCache.create(() => Future.value(directory))))
      .cookieJar(PersistentCookieJar.persistent(CookiePersistor.MEMORY))
      .addInterceptor(new UserAgentInterceptor(() => Future.value('xxx')))
      .addInterceptor(new OptimizedCacheInterceptor(() => Future.value(true)))
      .addNetworkInterceptor(new OptimizedResponseInterceptor())
      .addNetworkInterceptor(
          new HttpLoggingInterceptor(level: LoggerLevel.BODY))
      .addNetworkInterceptor(new ProgressRequestInterceptor((String url,
          String method, int progressBytes, int totalBytes, bool isDone) {
        print(
            'progress request - $method $url $progressBytes/$totalBytes done:$isDone');
      }))
      .addNetworkInterceptor(new ProgressResponseInterceptor((String url,
          String method, int progressBytes, int totalBytes, bool isDone) {
        print(
            'progress response - $method $url $progressBytes/$totalBytes done:$isDone');
      }))
      .build();

  test('smoke test - http get', () async {
    print('${new DateTime.now().toLocal()}');
    HttpUrl url = HttpUrl.parse('https://www.baidu.com/');
    Request request = new RequestBuilder().url(url).get().build();
    await client.newCall(request).enqueue().then((Response response) async {
      print('resp: ${response.code()} - ${response.message()} - ${(await response.body().string())}');
    }).catchError((error) {
      print('error: $error');
    });
    print('${new DateTime.now().toLocal()}');
  });

  test('smoke test - http get json', () async {
    print('${new DateTime.now().toLocal()}');
    HttpUrl url =
        HttpUrl.parse('https://www.apiopen.top/satinApi?type=1&page=1');
    Request request = new RequestBuilder().url(url).get().build();
    await client.newCall(request).enqueue().then((Response response) async {
      print(
          'resp: ${response.code()} - ${response.message()} - ${(await response.body().string())}');
    }).catchError((error) {
      print('error: $error');
    });
    print('${new DateTime.now().toLocal()}');
  });

  test('smoke test - http post', () async {
    print('${new DateTime.now().toLocal()}');
    HttpUrl url = HttpUrl.parse('http://fanyi.baidu.com/v2transapi');
    RequestBody body = new FormBodyBuilder()
        .add('from', 'zh')
        .add('to', 'en')
        .add('query', '奇数')
        .add('simple_means_flag', '3')
        .add('sign', '763725.1000572')
        .add('token', 'ace5889a5474fc144c730ce9e95878a8')
        .build();
    Request request = new RequestBuilder().url(url).header(HttpHeaders.refererHeader, 'http://fanyi.baidu.com/').post(body).build();
    await client.newCall(request).enqueue().then((Response response) async {
      print('resp: ${response.code()} - ${response.message()} - ${await response.body().string()}');
    }).catchError((error) {
      print('error: $error');
    });
    print('${new DateTime.now().toLocal()}');
  });
}
