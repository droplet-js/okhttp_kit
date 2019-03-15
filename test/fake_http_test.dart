import 'package:fake_http/fake_http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FileSystem fileSystem = MemoryFileSystem();// const LocalFileSystem();

  print(
      '${fileSystem.currentDirectory.path} - ${fileSystem.systemTempDirectory.path}');

  Directory directory = fileSystem.currentDirectory
      .childDirectory('build')
      .childDirectory('cache');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  OkHttpClient client = OkHttpClientBuilder()
      .cache(Cache(DiskCache.create(() => Future<Directory>.value(directory))))
      .cookieJar(PersistentCookieJar.memory())
      .addInterceptor(UserAgentInterceptor(() => Future<String>.value('xxx')))
      .addInterceptor(OptimizedRequestInterceptor(() => Future<bool>.value(true)))
      .addNetworkInterceptor(OptimizedResponseInterceptor())
      .addNetworkInterceptor(
          HttpLoggingInterceptor(level: LoggerLevel.BODY))
      .addNetworkInterceptor(ProgressRequestInterceptor((String url,
          String method, int progressBytes, int totalBytes, bool isDone) {
        print(
            'progress request - $method $url $progressBytes/$totalBytes done:$isDone');
      }))
      .addNetworkInterceptor(ProgressResponseInterceptor((String url,
          String method, int progressBytes, int totalBytes, bool isDone) {
        print(
            'progress response - $method $url $progressBytes/$totalBytes done:$isDone');
      }))
      .build();

  test('smoke test - http get', () async {
    print('${DateTime.now().toLocal()}');
    HttpUrl url = HttpUrl.parse('https://www.baidu.com/');
    Request request = RequestBuilder().url(url).get().build();
    await client.newCall(request).enqueue().then((Response response) async {
      print('resp: ${response.code()} - ${response.message()} - ${(await response.body().string())}');
    }).catchError((dynamic error) {
      print('error: $error');
    });
    print('${DateTime.now().toLocal()}');
  });

  test('smoke test - http get json', () async {
    print('${DateTime.now().toLocal()}');
    HttpUrl url =
        HttpUrl.parse('https://www.apiopen.top/satinApi?type=1&page=1');
    Request request = RequestBuilder().url(url).get().build();
    await client.newCall(request).enqueue().then((Response response) async {
      print(
          'resp: ${response.code()} - ${response.message()} - ${(await response.body().string())}');
    }).catchError((dynamic error) {
      print('error: $error');
    });
    print('${DateTime.now().toLocal()}');
  });

  test('smoke test - http post', () async {
    print('${DateTime.now().toLocal()}');
    HttpUrl url = HttpUrl.parse('http://fanyi.baidu.com/v2transapi');
    RequestBody body = FormBodyBuilder()
        .add('from', 'zh')
        .add('to', 'en')
        .add('query', '奇数')
        .add('simple_means_flag', '3')
        .add('sign', '763725.1000572')
        .add('token', 'ace5889a5474fc144c730ce9e95878a8')
        .build();
    Request request = RequestBuilder().url(url).header(HttpHeaders.refererHeader, 'http://fanyi.baidu.com/').post(body).build();
    await client.newCall(request).enqueue().then((Response response) async {
      print('resp: ${response.code()} - ${response.message()} - ${await response.body().string()}');
    }).catchError((dynamic error) {
      print('error: $error');
    });
    print('${DateTime.now().toLocal()}');
  });

  test('smoke test - cache', () async {
    directory.listSync().forEach((FileSystemEntity entity) {
      print('xxx - ${entity.path} - ${entity.basename} - ${entity
          .statSync()
          .size}');
    });
  });
}
