import 'dart:async';
import 'dart:io';

abstract class Authenticator {
  static const Authenticator NONE = _NoneAuthenticator();

  Future<bool> authenticate(
      HttpClient client, Uri url, String scheme, String realm);
}

class _NoneAuthenticator implements Authenticator {
  const _NoneAuthenticator();

  @override
  Future<bool> authenticate(
      HttpClient client, Uri url, String scheme, String realm) {
    return Future.value(false);
  }
}

abstract class ProxyAuthenticator {
  static const ProxyAuthenticator NONE = _NoneProxyAuthenticator();

  Future<bool> authenticate(
      HttpClient client, String host, int port, String scheme, String realm);
}

class _NoneProxyAuthenticator implements ProxyAuthenticator {
  const _NoneProxyAuthenticator();

  @override
  Future<bool> authenticate(
      HttpClient client, String host, int port, String scheme, String realm) {
    return Future.value(false);
  }
}
