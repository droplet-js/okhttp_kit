class HttpMethod {
  HttpMethod._();

  static const String head = 'HEAD';
  static const String get = 'GET';
  static const String post = 'POST';
  static const String put = 'PUT';
  static const String patch = 'PATCH';
  static const String delete = 'DELETE';

  static bool invalidatesCache(String method) {
    return method == post ||
        method == patch ||
        method == put ||
        method == delete;
  }

  static bool requiresRequestBody(String method) {
    return method == post || method == put || method == patch;
  }

  static bool permitsRequestBody(String method) {
    return !(method == get || method == head);
  }
}
