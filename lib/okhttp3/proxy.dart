import 'dart:async';

typedef String Proxy(Uri url);

typedef FutureOr<Proxy> ProxySelector();
