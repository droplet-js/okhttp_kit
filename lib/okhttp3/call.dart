import 'package:fake_okhttp/okhttp3/chain.dart';
import 'package:fake_okhttp/okhttp3/interceptor.dart';
import 'package:fake_okhttp/okhttp3/internal/cache/cache_interceptor.dart';
import 'package:fake_okhttp/okhttp3/internal/http/bridge_interceptor.dart';
import 'package:fake_okhttp/okhttp3/internal/http/call_server_interceptor.dart';
import 'package:fake_okhttp/okhttp3/okhttp_client.dart';
import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/response.dart';

abstract class Call {
  Future<Response> enqueue();
}

class RealCall implements Call {
  RealCall.newRealCall(OkHttpClient client, Request originalRequest)
      : _client = client,
        _originalRequest = originalRequest;

  final OkHttpClient _client;
  final Request _originalRequest;

  @override
  Future<Response> enqueue() {
    List<Interceptor> interceptors = <Interceptor>[];
    interceptors.addAll(_client.interceptors());
    interceptors.add(BridgeInterceptor(_client.cookieJar()));
    interceptors.add(CacheInterceptor(_client.cache()));
    interceptors.addAll(_client.networkInterceptors());
    interceptors.add(CallServerInterceptor(_client));
    Chain chain = RealInterceptorChain(interceptors, 0, _originalRequest);
    return chain.proceed(_originalRequest);
  }
}
