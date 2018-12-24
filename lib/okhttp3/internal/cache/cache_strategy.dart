import 'dart:io';
import 'dart:math' as Math;

import 'package:fake_http/okhttp3/cache_control.dart';
import 'package:fake_http/okhttp3/headers.dart';
import 'package:fake_http/okhttp3/internal/http_extension.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';

class CacheStrategy {
  final Request networkRequest;
  final Response cacheResponse;

  CacheStrategy._(
    this.networkRequest,
    this.cacheResponse,
  );

  static bool isCacheable(Response response, Request request) {
    // Always go to network for uncacheable response codes (RFC 7231 section 6.1),
    // This implementation doesn't support caching partial content.
    switch (response.code()) {
      case HttpStatus.ok:
      case HttpStatus.nonAuthoritativeInformation:
      case HttpStatus.noContent:
      case HttpStatus.multipleChoices:
      case HttpStatus.movedPermanently:
      case HttpStatus.notFound:
      case HttpStatus.methodNotAllowed:
      case HttpStatus.gone:
      case HttpStatus.requestUriTooLong:
      case HttpStatus.notImplemented:
      case HttpStatusExtension.permanentRedirect:
        // These codes can be cached unless headers forbid it.
        break;
      case HttpStatus.movedTemporarily:
      case HttpStatus.temporaryRedirect:
        // These codes can only be cached with the right response headers.
        // http://tools.ietf.org/html/rfc7234#section-3
        // s-maxage is not checked because OkHttp is a private cache that should ignore s-maxage.
        if (response.header(HttpHeaders.expiresHeader) != null ||
            response.cacheControl().maxAgeSeconds() != -1 ||
            response.cacheControl().isPublic() ||
            response.cacheControl().isPrivate()) {
          break;
        }
        return false;
      default:
        // All other codes cannot be cached.
        return false;
    }
    // A 'no-store' directive on request or response prevents the response from being cached.
    return !response.cacheControl().noStore() &&
        !request.cacheControl().noStore();
  }
}

class CacheStrategyFactory {
  final int nowMillis;
  final Request request;
  final Response cacheResponse;

  DateTime _servedDate;
  String _servedDateString;

  DateTime _lastModified;
  String _lastModifiedString;

  DateTime _expires;

  int _sentRequestMillis;

  int _receivedResponseMillis;

  String _etag;

  int _ageSeconds = -1;

  CacheStrategyFactory(
    this.nowMillis,
    this.request,
    this.cacheResponse,
  ) {
    if (cacheResponse != null) {
      _sentRequestMillis = cacheResponse.sentRequestAtMillis();
      _receivedResponseMillis = cacheResponse.receivedResponseAtMillis();
      Headers headers = cacheResponse.headers();
      for (int i = 0, size = headers.size(); i < size; i++) {
        String name = headers.nameAt(i);
        String value = headers.valueAt(i);
        if (name == HttpHeaders.dateHeader) {
          _servedDate = HttpDate.parse(value);
          _servedDateString = value;
        } else if (name == HttpHeaders.expiresHeader) {
          _expires = HttpDate.parse(value);
        } else if (name == HttpHeaders.lastModifiedHeader) {
          _lastModified = HttpDate.parse(value);
          _lastModifiedString = value;
        } else if (name == HttpHeaders.etagHeader) {
          _etag = value;
        } else if (name == HttpHeaders.ageHeader) {
          _ageSeconds = value != null ? int.parse(value) : -1;
        }
      }
    }
  }

  CacheStrategy get() {
    CacheStrategy candidate = _getCandidate();
    if (candidate.networkRequest != null &&
        request.cacheControl().onlyIfCached()) {
      return new CacheStrategy._(null, null);
    }
    return candidate;
  }

  CacheStrategy _getCandidate() {
    // No cached response.
    if (cacheResponse == null) {
      return new CacheStrategy._(request, null);
    }

    // If this response shouldn't have been stored, it should never be used
    // as a response source. This check should be redundant as long as the
    // persistence store is well-behaved and the rules are constant.
    if (!CacheStrategy.isCacheable(cacheResponse, request)) {
      return new CacheStrategy._(request, null);
    }

    CacheControl requestCaching = request.cacheControl();
    if (requestCaching.noCache() || _hasConditions(request)) {
      return new CacheStrategy._(request, null);
    }

    CacheControl responseCaching = cacheResponse.cacheControl();
    if (responseCaching.immutable()) {
      return new CacheStrategy._(null, cacheResponse);
    }

    int ageMillis = _cacheResponseAge();
    int freshMillis = _computeFreshnessLifetime();

    if (requestCaching.maxAgeSeconds() != -1) {
      freshMillis = Math.min(freshMillis,
          new Duration(seconds: requestCaching.maxAgeSeconds()).inMilliseconds);
    }

    int minFreshMillis = 0;
    if (requestCaching.minFreshSeconds() != -1) {
      minFreshMillis = new Duration(seconds: requestCaching.minFreshSeconds())
          .inMilliseconds;
    }

    int maxStaleMillis = 0;
    if (!responseCaching.mustRevalidate() &&
        requestCaching.maxStaleSeconds() != -1) {
      maxStaleMillis = new Duration(seconds: requestCaching.maxStaleSeconds())
          .inMilliseconds;
    }

    if (!responseCaching.noCache() &&
        ageMillis + minFreshMillis < freshMillis + maxStaleMillis) {
      ResponseBuilder builder = cacheResponse.newBuilder();
      if (ageMillis + minFreshMillis >= freshMillis) {
        builder.addHeader(HttpHeaders.warningHeader,
            "110 HttpURLConnection \"Response is stale\"");
      }
      int oneDayMillis = new Duration(days: 1).inMilliseconds;
      if (ageMillis > oneDayMillis && _isFreshnessLifetimeHeuristic()) {
        builder.addHeader(HttpHeaders.warningHeader,
            "113 HttpURLConnection \"Heuristic expiration\"");
      }
      return new CacheStrategy._(null, builder.build());
    }

    // Find a condition to add to the request. If the condition is satisfied, the response body
    // will not be transmitted.
    String conditionName;
    String conditionValue;
    if (_etag != null) {
      conditionName = HttpHeaders.ifNoneMatchHeader;
      conditionValue = _etag;
    } else if (_lastModified != null) {
      conditionName = HttpHeaders.ifModifiedSinceHeader;
      conditionValue = _lastModifiedString;
    } else if (_servedDate != null) {
      conditionName = HttpHeaders.ifModifiedSinceHeader;
      conditionValue = _servedDateString;
    } else {
      return new CacheStrategy._(
          request, null); // No condition! Make a regular request.
    }

    HeadersBuilder conditionalRequestHeaders = request.headers().newBuilder();
    conditionalRequestHeaders.addLenient(conditionName, conditionValue);

    Request conditionalRequest =
        request.newBuilder().headers(conditionalRequestHeaders.build()).build();
    return new CacheStrategy._(conditionalRequest, cacheResponse);
  }

  int _computeFreshnessLifetime() {
    CacheControl responseCaching = cacheResponse.cacheControl();
    if (responseCaching.maxAgeSeconds() != -1) {
      return new Duration(seconds: responseCaching.maxAgeSeconds())
          .inMilliseconds;
    } else if (_expires != null) {
      int servedMillis = _servedDate != null
          ? _servedDate.millisecondsSinceEpoch
          : _receivedResponseMillis;
      int delta = _expires.millisecondsSinceEpoch - servedMillis;
      return delta > 0 ? delta : 0;
    } else if (_lastModified != null &&
        cacheResponse.request().url().query() == null) {
      // As recommended by the HTTP RFC and implemented in Firefox, the
      // max age of a document should be defaulted to 10% of the
      // document's age at the time it was served. Default expiration
      // dates aren't used for URIs containing a query.
      int servedMillis = _servedDate != null
          ? _servedDate.millisecondsSinceEpoch
          : _sentRequestMillis;
      int delta = servedMillis - _lastModified.millisecondsSinceEpoch;
      return delta > 0 ? (delta ~/ 10) : 0;
    }
    return 0;
  }

  int _cacheResponseAge() {
    int apparentReceivedAge = _servedDate != null
        ? Math.max(
            0, _receivedResponseMillis - _servedDate.millisecondsSinceEpoch)
        : 0;
    int receivedAge = _ageSeconds != -1
        ? Math.max(apparentReceivedAge,
            new Duration(seconds: _ageSeconds).inMilliseconds)
        : apparentReceivedAge;
    int responseDuration = _receivedResponseMillis - _sentRequestMillis;
    int residentDuration = nowMillis - _receivedResponseMillis;
    return receivedAge + responseDuration + residentDuration;
  }

  bool _isFreshnessLifetimeHeuristic() {
    return cacheResponse.cacheControl().maxAgeSeconds() == -1 &&
        _expires == null;
  }

  static bool _hasConditions(Request request) {
    return request.header(HttpHeaders.ifModifiedSinceHeader) != null ||
        request.header(HttpHeaders.ifNoneMatchHeader) != null;
  }
}
