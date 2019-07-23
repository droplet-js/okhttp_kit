import 'dart:async';

typedef String Proxy(Uri url);

abstract class ProxySelector {
  FutureOr<Proxy> select();
}
