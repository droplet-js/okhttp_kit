import 'dart:async';
import 'dart:io';

import 'package:fake_http/okhttp3/interceptor.dart';
import 'package:fake_http/okhttp3/internal/http/real_interceptor_chain.dart';
import 'package:fake_http/okhttp3/internal/http/unrepeatable_request_body.dart';
import 'package:fake_http/okhttp3/internal/http_extension.dart';
import 'package:fake_http/okhttp3/internal/util.dart';
import 'package:fake_http/okhttp3/lang/integer.dart';
import 'package:fake_http/okhttp3/okhttp_client.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';

class RetryAndFollowUpInterceptor implements Interceptor {
  RetryAndFollowUpInterceptor(
    OkHttpClient client,
  ) : _client = client;

  static const int _MAX_FOLLOW_UPS = 20;

  final OkHttpClient _client;

  HttpClient _httpClient;
  bool canceled = false;

  @override
  Future<Response> intercept(Chain chain) async {
    Request request = chain.request();
    RealInterceptorChain realChain = chain as RealInterceptorChain;

    _httpClient = HttpClient();
    _httpClient.idleTimeout = _client.idleTimeout();
    _httpClient.connectionTimeout = _client.connectionTimeout();
    _httpClient.authenticate = (Uri url, String scheme, String realm) {
      return _client
          .authenticator()
          .authenticate(_httpClient, url, scheme, realm);
    };
    _httpClient.authenticateProxy =
        (String host, int port, String scheme, String realm) {
      return _client
          .proxyAuthenticator()
          .authenticate(_httpClient, host, port, scheme, realm);
    };

    int followUpCount = 0;
    Response priorResponse;
    while (true) {
      if (canceled) {
        _httpClient.close(force: true);
        throw Exception('Canceled');
      }

      Response response;
      try {
        response = await realChain.proceedRequest(request, _httpClient);
      } catch (e) {
        _httpClient.close(force: true);
        rethrow;
      }

      /// Attach the prior response if it exists. Such responses never have a body.
      if (priorResponse != null) {
        response = response
            .newBuilder()
            .priorResponse(priorResponse.newBuilder().body(null).build())
            .build();
      }

      Request followUp = _followUpRequest(response);

      if (followUp == null) {
        return response;
      }

      Util.closeQuietly(response.body());

      if (++followUpCount > _MAX_FOLLOW_UPS) {
        _httpClient.close(force: true);
        throw Exception('Too many follow-up requests: $followUpCount');
      }

      if (followUp.body() != null &&
          followUp.body() is UnrepeatableRequestBody) {
        _httpClient.close(force: true);
        throw Exception('Cannot retry streamed HTTP body ${response.code()}');
      }

      request = followUp;
      priorResponse = response;
    }
  }

  Request _followUpRequest(Response userResponse) {
    if (userResponse == null) {
      throw AssertionError();
    }
    final int responseCode = userResponse.code();
//    final String method = userResponse.request().method();
    switch (responseCode) {
      case HttpStatus.proxyAuthenticationRequired:
        // HttpClient 实现
        break;
      case HttpStatus.unauthorized:
        // HttpClient 实现
        break;
      case HttpStatus.temporaryRedirect:
      case HttpStatusExtension.permanentRedirect:
      case HttpStatus.multipleChoices:
      case HttpStatus.movedPermanently:
      case HttpStatus.movedTemporarily:
      case HttpStatus.seeOther:
        // HttpClient 实现
        break;
      case HttpStatus.requestTimeout:
        // 408's are rare in practice, but some servers like HAProxy use this response code. The
        // spec says that we may repeat the request without modifications. Modern browsers also
        // repeat the request (even non-idempotent ones.)
        if (!_client.retryOnConnectionFailure()) {
          // The application layer has directed us not to retry the request.
          return null;
        }

        if (userResponse.request().body() != null &&
            userResponse.request().body() is UnrepeatableRequestBody) {
          return null;
        }

        if (userResponse.priorResponse() != null &&
            userResponse.priorResponse().code() == HttpStatus.requestTimeout) {
          // We attempted to retry and got another timeout. Give up.
          return null;
        }

        if (_retryAfter(userResponse, 0) > 0) {
          return null;
        }

        return userResponse.request();
      case HttpStatus.serviceUnavailable:
        if (userResponse.priorResponse() != null &&
            userResponse.priorResponse().code() ==
                HttpStatus.serviceUnavailable) {
          // We attempted to retry and got another timeout. Give up.
          return null;
        }

        if (_retryAfter(userResponse, Integer.MAX_VALUE) == 0) {
          return userResponse.request();
        }

        return null;
    }
    return null;
  }

  int _retryAfter(Response userResponse, int defaultDelay) {
    String header = userResponse.headers().value(HttpHeaders.retryAfterHeader);

    if (header == null) {
      return defaultDelay;
    }

    // https://tools.ietf.org/html/rfc7231#section-7.1.3
    // currently ignores a HTTP-date, and assumes any non int 0 is a delay
    if (RegExp('\\d+').stringMatch(header) == header) {
      return int.parse(header);
    }

    return Integer.MAX_VALUE;
  }

  void cancel() {
    canceled = true;
    HttpClient httpClient = _httpClient;
    if (httpClient != null) {
      httpClient.close(force: true);
    }
  }

  bool isCanceled() {
    return canceled;
  }
}
