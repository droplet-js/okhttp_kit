import 'dart:async';
import 'dart:io';

import 'package:fake_okhttp/okhttp3/chain.dart';
import 'package:fake_okhttp/okhttp3/interceptor.dart';
import 'package:fake_okhttp/okhttp3/internal/http/http_method.dart';
import 'package:fake_okhttp/okhttp3/internal/http_extension.dart';
import 'package:fake_okhttp/okhttp3/media_type.dart';
import 'package:fake_okhttp/okhttp3/okhttp_client.dart';
import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/response.dart';
import 'package:fake_okhttp/okhttp3/response_body.dart';

class CallServerInterceptor implements Interceptor {
  CallServerInterceptor(
    OkHttpClient client,
  ) : _client = client;

  final OkHttpClient _client;

  @override
  Future<Response> intercept(Chain chain) async {
    HttpClient httpClient = _client.securityContext() != null
        ? HttpClient(context: _client.securityContext())
        : HttpClient();
    httpClient.autoUncompress = true;
    httpClient.idleTimeout = _client.idleTimeout();
    httpClient.connectionTimeout = _client.connectionTimeout();

    if (_client.proxy() != null) {
      httpClient.findProxy = _client.proxy();
    } else if (_client.proxySelector() != null) {
      httpClient.findProxy = await _client.proxySelector().select();
    }

    Request request = chain.request();

    int sentRequestMillis = DateTime.now().millisecondsSinceEpoch;

    HttpClientRequest ioRequest =
        await httpClient.openUrl(request.method(), request.url().uri());
    ioRequest
      ..followRedirects = _client.followRedirects()
      ..maxRedirects = _client.maxRedirects()
      ..contentLength = request.body()?.contentLength() ?? -1
      ..persistentConnection =
          request.header(HttpHeaders.connectionHeader)?.toLowerCase() ==
              'keep-alive';
    for (int i = 0, size = request.headers().size(); i < size; i++) {
      ioRequest.headers
          .add(request.headers().nameAt(i), request.headers().valueAt(i));
    }
    if (HttpMethod.permitsRequestBody(request.method()) &&
        request.body() != null) {
      await ioRequest.addStream(request.body().source());
    }

    HttpClientResponse ioResponse = await ioRequest.close();

    ResponseBuilder responseBuilder = ResponseBuilder();
    responseBuilder.code(ioResponse.statusCode);
    responseBuilder.message(ioResponse.reasonPhrase);

    if (ioResponse.headers != null) {
      ioResponse.headers.forEach((String name, List<String> values) {
        values.forEach((String value) {
          responseBuilder.addHeader(name, value);
        });
      });
    }

    Response response = responseBuilder
        .request(request)
        .sentRequestAtMillis(sentRequestMillis)
        .receivedResponseAtMillis(DateTime.now().millisecondsSinceEpoch)
        .build();

    // 绑定 HttpClient 生命周期
    Stream<List<int>> source =
        StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleDone: (EventSink<List<int>> sink) {
      sink.close();
      httpClient.close(force: false); // keep alive
    }).bind(ioResponse);

    String contentType = response.header(HttpHeaders.contentTypeHeader);
    response = response
        .newBuilder()
        .body(ResponseBody.streamBody(
            contentType != null ? MediaType.parse(contentType) : null,
            HttpHeadersExtension.contentLength(response),
            source))
        .build();

    if ((response.code() == HttpStatus.noContent ||
            response.code() == HttpStatus.resetContent) &&
        response.body() != null &&
        response.body().contentLength() > 0) {
      throw HttpException(
        'HTTP ${response.code()} had non-zero Content-Length: ${response.body().contentLength()}',
        uri: request.url().uri(),
      );
    }
    return response;
  }
}
