import 'dart:async';
import 'dart:io';

import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/internal/http/http_method.dart';
import 'package:fake_http/okhttp3/internal/http/real_interceptor_chain.dart';
import 'package:fake_http/okhttp3/internal/http/real_response_body.dart';
import 'package:fake_http/okhttp3/internal/http_extension.dart';
import 'package:fake_http/okhttp3/okhttp_client.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';

class CallServerInterceptor implements Interceptor {
  final OkHttpClient _client;

  CallServerInterceptor(OkHttpClient client) : _client = client;

  @override
  Future<Response> intercept(Chain chain) async {
    RealInterceptorChain realChain = chain as RealInterceptorChain;
    HttpClient httpClient = realChain.httpClient();
    Request request = chain.request();

    int sentRequestMillis = DateTime.now().millisecondsSinceEpoch;

    HttpClientRequest ioRequest =
        await httpClient.openUrl(request.method(), request.url().uri());
    ioRequest
      ..followRedirects = _client.followRedirects()
      ..maxRedirects = 5
      ..contentLength =
          request.body() != null ? request.body().contentLength() : -1
      ..persistentConnection =
          request.header(HttpHeaders.connectionHeader) == null ||
              request.header(HttpHeaders.connectionHeader).toLowerCase() ==
                  'keep-alive';
    for (int i = 0, size = request.headers().size(); i < size; i++) {
      ioRequest.headers
          .add(request.headers().nameAt(i), request.headers().valueAt(i));
    }

    if (HttpMethod.permitsRequestBody(request.method()) &&
        request.body() != null) {
      await request.body().writeTo(ioRequest);
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

    String contentType = response.header(HttpHeaders.contentTypeHeader);
    response = response
        .newBuilder()
        .body(RealResponseBody(contentType,
            HttpHeadersExtension.contentLength(response), ioResponse))
        .build();

    if ((response.code() == HttpStatus.noContent ||
            response.code() == HttpStatus.resetContent) &&
        response.body() != null &&
        response.body().contentLength() > 0) {
      throw Exception(
          'HTTP ${response.code()} had non-zero Content-Length: ${response.body().contentLength()}');
    }
    return response;
  }
}
