import 'package:fake_okhttp/okhttp3/chain.dart';
import 'package:fake_okhttp/okhttp3/response.dart';

abstract class Interceptor {
  Future<Response> intercept(Chain chain);
}
