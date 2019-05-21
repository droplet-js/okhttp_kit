import 'dart:io';

import 'package:fake_okhttp/okhttp3/headers.dart';
import 'package:fake_okhttp/okhttp3/internal/http_extension.dart';
import 'package:fake_okhttp/okhttp3/lang/integer.dart';

class CacheControl {
  CacheControl._(
    bool noCache,
    bool noStore,
    int maxAgeSeconds,
    int sMaxAgeSeconds,
    bool isPrivate,
    bool isPublic,
    bool mustRevalidate,
    int maxStaleSeconds,
    int minFreshSeconds,
    bool onlyIfCached,
    bool noTransform,
    bool immutable,
  )   : _noCache = noCache,
        _noStore = noStore,
        _maxAgeSeconds = maxAgeSeconds,
        _sMaxAgeSeconds = sMaxAgeSeconds,
        _isPrivate = isPrivate,
        _isPublic = isPublic,
        _mustRevalidate = mustRevalidate,
        _maxStaleSeconds = maxStaleSeconds,
        _minFreshSeconds = minFreshSeconds,
        _onlyIfCached = onlyIfCached,
        _noTransform = noTransform,
        _immutable = immutable;

  CacheControl._fromBuilder(
    CacheControlBuilder builder,
  )   : _noCache = builder._noCache,
        _noStore = builder._noStore,
        _maxAgeSeconds = builder._maxAgeSeconds,
        _sMaxAgeSeconds = -1,
        _isPrivate = false,
        _isPublic = false,
        _mustRevalidate = false,
        _maxStaleSeconds = builder._maxStaleSeconds,
        _minFreshSeconds = builder._minFreshSeconds,
        _onlyIfCached = builder._onlyIfCached,
        _noTransform = builder._noTransform,
        _immutable = builder._immutable;

  static final CacheControl FORCE_NETWORK =
      CacheControlBuilder().noCache().build();
  static final CacheControl FORCE_CACHE = CacheControlBuilder()
      .onlyIfCached()
      .maxStale(Duration(seconds: Integer.MAX_VALUE))
      .build();

  static const String _PARAMS_NO_CACHE = 'no-cache';
  static const String _PARAMS_NO_STORE = 'no-store';
  static const String _PARAMS_MAX_AGE = 'max-age';
  static const String _PARAMS_S_MAXAGE = 's-maxage';
  static const String _PARAMS_PRIVATE = 'private';
  static const String _PARAMS_PUBLIC = 'public';
  static const String _PARAMS_MUST_REVALIDATE = 'must-revalidate';
  static const String _PARAMS_MAX_STALE = 'max-stale';
  static const String _PARAMS_MIN_FRESH = 'min-fresh';
  static const String _PARAMS_ONLY_IF_CACHED = 'only-if-cached';
  static const String _PARAMS_NO_TRANSFORM = 'no-transform';
  static const String _PARAMS_IMMUTABLE = 'immutable';

  final bool _noCache;
  final bool _noStore;
  final int _maxAgeSeconds;
  final int _sMaxAgeSeconds;
  final bool _isPrivate;
  final bool _isPublic;
  final bool _mustRevalidate;
  final int _maxStaleSeconds;
  final int _minFreshSeconds;
  final bool _onlyIfCached;
  final bool _noTransform;
  final bool _immutable;

  bool noCache() {
    return _noCache;
  }

  bool noStore() {
    return _noStore;
  }

  int maxAgeSeconds() {
    return _maxAgeSeconds;
  }

  int sMaxAgeSeconds() {
    return _sMaxAgeSeconds;
  }

  bool isPrivate() {
    return _isPrivate;
  }

  bool isPublic() {
    return _isPublic;
  }

  bool mustRevalidate() {
    return _mustRevalidate;
  }

  int maxStaleSeconds() {
    return _maxStaleSeconds;
  }

  int minFreshSeconds() {
    return _minFreshSeconds;
  }

  bool onlyIfCached() {
    return _onlyIfCached;
  }

  bool noTransform() {
    return _noTransform;
  }

  bool immutable() {
    return _immutable;
  }

  @override
  String toString() {
    return _headerValue();
  }

  String _headerValue() {
    StringBuffer result = StringBuffer();
    if (_noCache) {
      result.write('$_PARAMS_NO_CACHE, ');
    }
    if (_noStore) {
      result.write('$_PARAMS_NO_STORE, ');
    }
    if (_maxAgeSeconds >= 0) {
      result.write('$_PARAMS_MAX_AGE=$_maxAgeSeconds, ');
    }
    if (_sMaxAgeSeconds >= 0) {
      result.write('$_PARAMS_S_MAXAGE=$_sMaxAgeSeconds, ');
    }
    if (_isPrivate) {
      result.write('$_PARAMS_PRIVATE, ');
    }
    if (_isPublic) {
      result.write('$_PARAMS_PUBLIC, ');
    }
    if (_mustRevalidate) {
      result.write('$_PARAMS_MUST_REVALIDATE, ');
    }
    if (_maxStaleSeconds >= 0) {
      result.write('$_PARAMS_MAX_STALE=$_maxStaleSeconds, ');
    }
    if (_minFreshSeconds >= 0) {
      result.write('$_PARAMS_MIN_FRESH=$_minFreshSeconds, ');
    }
    if (_onlyIfCached) {
      result.write('$_PARAMS_ONLY_IF_CACHED, ');
    }
    if (_noTransform) {
      result.write('$_PARAMS_NO_TRANSFORM, ');
    }
    if (_immutable) {
      result.write('$_PARAMS_IMMUTABLE}, ');
    }
    return result.isNotEmpty
        ? result.toString().substring(0, result.length - 2)
        : '';
  }

  static CacheControl parse(Headers headers) {
    bool noCache = false;
    bool noStore = false;
    int maxAgeSeconds = -1;
    int sMaxAgeSeconds = -1;
    bool isPrivate = false;
    bool isPublic = false;
    bool mustRevalidate = false;
    int maxStaleSeconds = -1;
    int minFreshSeconds = -1;
    bool onlyIfCached = false;
    bool noTransform = false;
    bool immutable = false;

    for (int i = 0, size = headers.size(); i < size; i++) {
      String name = headers.nameAt(i);
      String value = headers.valueAt(i);
      if (name == HttpHeaders.cacheControlHeader ||
          name == HttpHeaders.pragmaHeader) {
        int pos = 0;
        while (pos < value.length) {
          int tokenStart = pos;
          pos = HttpHeadersExtension.skipUntil(value, pos, '=,;');
          String directive = value.substring(tokenStart, pos).trim();

          String parameter;
          if (pos == value.length || value[pos] == ',' || value[pos] == ';') {
            pos++; // consume ',' or ';' (if necessary)
            parameter = null;
          } else {
            pos++; // consume '='
            pos = HttpHeadersExtension.skipWhitespace(value, pos);

            // quoted string
            if (pos < value.length && value[pos] == '\"') {
              pos++; // consume '"' open quote
              int parameterStart = pos;
              pos = HttpHeadersExtension.skipUntil(value, pos, '\"');
              parameter = value.substring(parameterStart, pos);
              pos++; // consume '"' close quote (if necessary)

              // unquoted string
            } else {
              int parameterStart = pos;
              pos = HttpHeadersExtension.skipUntil(value, pos, ',;');
              parameter = value.substring(parameterStart, pos).trim();
            }
          }

          if (_PARAMS_NO_CACHE == directive.toLowerCase()) {
            noCache = true;
          } else if (_PARAMS_NO_STORE == directive.toLowerCase()) {
            noStore = true;
          } else if (_PARAMS_MAX_AGE == directive.toLowerCase()) {
            maxAgeSeconds = parameter != null ? int.parse(parameter) : -1;
          } else if (_PARAMS_S_MAXAGE == directive.toLowerCase()) {
            sMaxAgeSeconds = parameter != null ? int.parse(parameter) : -1;
          } else if (_PARAMS_PRIVATE == directive.toLowerCase()) {
            isPrivate = true;
          } else if (_PARAMS_PUBLIC == directive.toLowerCase()) {
            isPublic = true;
          } else if (_PARAMS_MUST_REVALIDATE == directive.toLowerCase()) {
            mustRevalidate = true;
          } else if (_PARAMS_MAX_STALE == directive.toLowerCase()) {
            maxStaleSeconds =
                parameter != null ? int.parse(parameter) : Integer.MAX_VALUE;
          } else if (_PARAMS_MIN_FRESH == directive.toLowerCase()) {
            minFreshSeconds = parameter != null ? int.parse(parameter) : -1;
          } else if (_PARAMS_ONLY_IF_CACHED == directive.toLowerCase()) {
            onlyIfCached = true;
          } else if (_PARAMS_NO_TRANSFORM == directive.toLowerCase()) {
            noTransform = true;
          } else if (_PARAMS_IMMUTABLE == directive.toLowerCase()) {
            immutable = true;
          }
        }
      }
    }
    return CacheControl._(
      noCache,
      noStore,
      maxAgeSeconds,
      sMaxAgeSeconds,
      isPrivate,
      isPublic,
      mustRevalidate,
      maxStaleSeconds,
      minFreshSeconds,
      onlyIfCached,
      noTransform,
      immutable,
    );
  }
}

class CacheControlBuilder {
  CacheControlBuilder();

  CacheControlBuilder._(
    CacheControl cacheControl,
  )   : _noCache = cacheControl._noCache,
        _noStore = cacheControl._noStore,
        _maxAgeSeconds = cacheControl._maxAgeSeconds,
        _maxStaleSeconds = cacheControl._maxStaleSeconds,
        _minFreshSeconds = cacheControl._minFreshSeconds,
        _onlyIfCached = cacheControl._onlyIfCached,
        _noTransform = cacheControl._noTransform,
        _immutable = cacheControl._immutable;

  bool _noCache = false;
  bool _noStore = false;
  int _maxAgeSeconds = -1;
  int _maxStaleSeconds = -1;
  int _minFreshSeconds = -1;
  bool _onlyIfCached = false;
  bool _noTransform = false;
  bool _immutable = false;

  CacheControlBuilder noCache() {
    _noCache = true;
    return this;
  }

  CacheControlBuilder noStore() {
    _noStore = true;
    return this;
  }

  CacheControlBuilder maxAge(Duration maxAge) {
    assert(maxAge != null);
    _maxAgeSeconds = maxAge.inSeconds;
    return this;
  }

  CacheControlBuilder maxStale(Duration maxStale) {
    assert(maxStale != null);
    _maxStaleSeconds = maxStale.inSeconds;
    return this;
  }

  CacheControlBuilder minFresh(Duration minFresh) {
    assert(minFresh != null);
    _minFreshSeconds = minFresh.inSeconds;
    return this;
  }

  CacheControlBuilder onlyIfCached() {
    _onlyIfCached = true;
    return this;
  }

  CacheControlBuilder noTransform() {
    _noTransform = true;
    return this;
  }

  CacheControlBuilder immutable() {
    _immutable = true;
    return this;
  }

  CacheControl build() {
    return CacheControl._fromBuilder(this);
  }
}
