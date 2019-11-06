import 'package:okhttp_kit/okhttp3/chain.dart';
import 'package:okhttp_kit/okhttp3/response.dart';

abstract class Interceptor {
  Future<Response> intercept(Chain chain);
}
