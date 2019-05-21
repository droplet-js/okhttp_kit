import 'dart:async';

import 'package:fake_okhttp/okhttp3/request.dart';
import 'package:fake_okhttp/okhttp3/response.dart';

abstract class Call {
  Request request();

  Future<Response> enqueue();

  void cancel();

  bool isCanceled();
}

abstract class Factory {
  Call newCall(Request request);
}
