import 'dart:async';

import 'package:fake_okhttp/okhttp3/call.dart';
import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/response.dart';

abstract class Interceptor {
  Future<Response> intercept(Chain chain);
}

abstract class Chain {
  Request request();

  Call call();

  Future<Response> proceed(Request request);
}
