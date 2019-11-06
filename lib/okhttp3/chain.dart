import 'package:okhttp_kit/okhttp3/interceptor.dart';
import 'package:okhttp_kit/okhttp3/request.dart';
import 'package:okhttp_kit/okhttp3/response.dart';

abstract class Chain {
  Request request();

  Future<Response> proceed(Request request);
}

class RealInterceptorChain implements Chain {
  RealInterceptorChain(
    List<Interceptor> interceptors,
    int index,
    Request request,
  )   : _interceptors = interceptors,
        _index = index,
        _request = request;

  final List<Interceptor> _interceptors;
  final int _index;
  final Request _request;

  @override
  Request request() {
    return _request;
  }

  @override
  Future<Response> proceed(Request request) {
    if (_index >= _interceptors.length) {
      throw AssertionError();
    }
    RealInterceptorChain next =
        RealInterceptorChain(_interceptors, _index + 1, request);
    Interceptor interceptor = _interceptors[_index];
    return interceptor.intercept(next);
  }
}
