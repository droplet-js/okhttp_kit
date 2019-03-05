class HttpMethod {
  HttpMethod._();

  static const String HEAD = 'HEAD';
  static const String GET = 'GET';
  static const String POST = 'POST';
  static const String PUT = 'PUT';
  static const String PATCH = 'PATCH';
  static const String DELETE = 'DELETE';

  static bool invalidatesCache(String method) {
    return method == POST ||
        method == PATCH ||
        method == PUT ||
        method == DELETE;
  }

  static bool requiresRequestBody(String method) {
    return method == POST || method == PUT || method == PATCH;
  }

  static bool permitsRequestBody(String method) {
    return !(method == GET || method == HEAD);
  }
}
