import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_http/okhttp3/headers.dart';
import 'package:fake_http/okhttp3/http_url.dart';
import 'package:fake_http/okhttp3/internal/cache/cache_strategy.dart';
import 'package:fake_http/okhttp3/internal/http/http_method.dart';
import 'package:fake_http/okhttp3/internal/http_extension.dart';
import 'package:fake_http/okhttp3/internal/util.dart';
import 'package:fake_http/okhttp3/io/closeable.dart';
import 'package:fake_http/okhttp3/media_type.dart';
import 'package:fake_http/okhttp3/request.dart';
import 'package:fake_http/okhttp3/response.dart';
import 'package:fake_http/okhttp3/response_body.dart';
import 'package:quiver/async.dart';

class Cache {
  static const int VERSION = 201105;
  static const int ENTRY_META_DATA = 0;
  static const int ENTRY_BODY = 1;
  static const int ENTRY_COUNT = 2;

  static final RegExp LEGAL_KEY_PATTERN = RegExp('[a-z0-9_-]{1,120}');

  final RawCache _cache;
  final KeyExtractor _keyExtractor;
  int _networkCount = 0;
  int _hitCount = 0;
  int _requestCount = 0;

  Cache(
    RawCache cache, [
    KeyExtractor keyExtractor,
  ])  : assert(cache != null),
        _cache = cache,
        _keyExtractor = keyExtractor ?? _defaultKeyExtractor;

  int networkCount() {
    return _networkCount;
  }

  int hitCount() {
    return _hitCount;
  }

  int requestCount() {
    return _requestCount;
  }

  String _key(HttpUrl url) {
    String key = _keyExtractor(url);
    if (key == null || key.isEmpty) {
      throw AssertionError('key is null or empty');
    }
    if (LEGAL_KEY_PATTERN.stringMatch(key) != key) {
      throw AssertionError(
          'keys must match regex [a-z0-9_-]{1,120}: \"$key\"');
    }
    return key;
  }

  Future<Response> get(Request request, [Encoding encoding]) async {
    String key = _key(request.url());
    Snapshot snapshot;
    _Entry entry;
    try {
      snapshot = await _cache.get(key);
      if (snapshot == null) {
        return null;
      }
    } catch (e) {
      // Give up because the cache cannot be read.
      return null;
    }

    try {
      entry = await _Entry.sourceEntry(
          snapshot.getSource(ENTRY_META_DATA), encoding ?? utf8);
    } catch (e) {
      Util.closeQuietly(snapshot);
      return null;
    }

    Response response = entry.response(snapshot);

    if (!entry.matches(request, response)) {
      Util.closeQuietly(response.body());
      return null;
    }

    return response;
  }

  Future<CacheRequest> put(Response response, [Encoding encoding]) async {
    String requestMethod = response.request().method();
    if (HttpMethod.invalidatesCache(response.request().method())) {
      try {
        await remove(response.request());
      } catch (e) {
        // The cache cannot be written.
      }
      return null;
    }
    if (requestMethod != HttpMethod.GET) {
      // Don't cache non-GET responses. We're technically allowed to cache
      // HEAD requests and some POST requests, but the complexity of doing
      // so is high and the benefit is low.
      return null;
    }

    if (HttpHeadersExtension.hasVaryAll(response.headers())) {
      return null;
    }

    _Entry entry = _Entry.responseEntry(response);
    Editor editor;
    try {
      editor = await _cache.edit(_key(response.request().url()));
      if (editor == null) {
        return null;
      }
      await entry.writeTo(editor, encoding ?? utf8);
      return CacheRequest(editor, encoding ?? utf8);
    } catch (e) {
      await _abortQuietly(editor);
      return null;
    }
  }

  Future<bool> remove(Request request) {
    return _cache.remove(_key(request.url()));
  }

  Future<void> update(Response cached, Response network,
      {Encoding encoding: utf8}) async {
    _Entry entry = _Entry.responseEntry(network);
    _CacheResponseBody body = cached.body() as _CacheResponseBody;
    Snapshot snapshot = body.snapshot();
    Editor editor;
    try {
      editor = await _cache.edit(snapshot.key(), snapshot.sequenceNumber());
      if (editor != null) {
        await entry.writeTo(editor, encoding);
        editor.commit();
      }
    } catch (e) {
      await _abortQuietly(editor);
    }
  }

  Future<void> _abortQuietly(Editor editor) async {
    // Give up because the cache cannot be written.
    try {
      if (editor != null) {
        editor.abort();
      }
    } catch (e) {}
  }

  Future<void> trackConditionalCacheHit() async {
    _networkCount++;
  }

  Future<void> trackResponse(CacheStrategy cacheStrategy) async {
    _requestCount++;

    if (cacheStrategy.networkRequest != null) {
      // If this is a conditional request, we'll increment hitCount if/when it hits.
      _networkCount++;
    } else if (cacheStrategy.cacheResponse != null) {
      // This response uses the cache and not the network. That's a cache hit.
      _hitCount++;
    }
  }
}

class CacheRequest {
  final Editor _editor;
  final Encoding _encoding;

  CacheRequest(Editor editor, Encoding encoding)
      : _editor = editor,
        _encoding = encoding;

  StreamSink<List<int>> body() {
    return _editor.newSink(Cache.ENTRY_BODY, _encoding);
  }

  void abort() {
    try {
      _editor.abort();
    } catch (e) {}
  }

  void commit() {
    _editor.commit();
  }
}

abstract class Editor {
  StreamSink<List<int>> newSink(int index, Encoding encoding);

  Stream<List<int>> newSource(int index, Encoding encoding);

  void commit();

  void abort();

  void detach();
}

abstract class RawCache {
  static const int ANY_SEQUENCE_NUMBER = -1;

  Future<Snapshot> get(String key);

  Future<Editor> edit(String key,
      [int expectedSequenceNumber]);

  Future<bool> remove(String key);
}

typedef String KeyExtractor(HttpUrl url);

String _defaultKeyExtractor(HttpUrl url) =>
    hex.encode(md5.convert(utf8.encode(url.toString())).bytes);

class Snapshot implements Closeable {
  final String _key;
  final int _sequenceNumber;
  final List<Stream<List<int>>> _sources;
  final List<int> _lengths;

  Snapshot(
    String key,
    int sequenceNumber,
    List<Stream<List<int>>> sources,
    List<int> lengths,
  )   : _key = key,
        _sequenceNumber = sequenceNumber,
        _sources = sources,
        _lengths = lengths;

  String key() {
    return _key;
  }

  int sequenceNumber() {
    return _sequenceNumber;
  }

  Stream<List<int>> getSource(int index) {
    return _sources[index];
  }

  int getLength(int index) {
    return _lengths[index];
  }

  @override
  void close() {}
}

class _Entry {
  static const String _SENT_MILLIS = 'OkHttp-Sent-Millis';
  static const String _RECEIVED_MILLIS = 'OkHttp-Received-Millis';

  final String _url;
  final String _requestMethod;
  final Headers _varyHeaders;
  final int _code;
  final String _message;
  final Headers _responseHeaders;
  final int _sentRequestMillis;
  final int _receivedResponseMillis;

  _Entry(
    String url,
    String requestMethod,
    Headers varyHeaders,
    int code,
    String message,
    Headers responseHeaders,
    int sentRequestMillis,
    int receivedResponseMillis,
  )   : _url = url,
        _requestMethod = requestMethod,
        _varyHeaders = varyHeaders,
        _code = code,
        _message = message,
        _responseHeaders = responseHeaders,
        _sentRequestMillis = sentRequestMillis,
        _receivedResponseMillis = receivedResponseMillis;

  Future<void> writeTo(Editor editor, Encoding encoding) async {
    assert(encoding != null);
    StringBuffer builder = StringBuffer();
    builder.writeln(_url);
    builder.writeln(_requestMethod);
    builder.writeln(_varyHeaders.size().toString());
    for (int i = 0, size = _varyHeaders.size(); i < size; i++) {
      builder.writeln('${_varyHeaders.nameAt(i)}: ${_varyHeaders.valueAt(i)}');
    }
    builder.writeln('$_code $_message');
    Headers responseHeaders = _responseHeaders
        .newBuilder()
        .set(_SENT_MILLIS, _sentRequestMillis.toString())
        .set(_RECEIVED_MILLIS, _receivedResponseMillis.toString())
        .build();
    builder.writeln(responseHeaders.size().toString());
    for (int i = 0, size = responseHeaders.size(); i < size; i++) {
      builder.writeln(
          '${responseHeaders.nameAt(i)}: ${responseHeaders.valueAt(i)}');
    }
    List<int> bytes = encoding.encode(builder.toString());

    EventSink<List<int>> sink =
        editor.newSink(Cache.ENTRY_META_DATA, encoding); // 用作 EventSink
    try {
      sink.add(bytes);
    } catch (e) {
      editor.abort();
    } finally {
      sink.close();
    }
  }

  Response response(Snapshot snapshot) {
    String contentTypeString =
        _responseHeaders.value(HttpHeaders.contentTypeHeader);
    MediaType contentType =
        contentTypeString != null ? MediaType.parse(contentTypeString) : null;
    String contentLengthString =
        _responseHeaders.value(HttpHeaders.contentLengthHeader);
    int contentLength =
        contentLengthString != null ? int.parse(contentLengthString) : -1;
    Request cacheRequest = RequestBuilder()
        .url(HttpUrl.parse(_url))
        .method(_requestMethod, null)
        .headers(_varyHeaders)
        .build();
    return ResponseBuilder()
        .request(cacheRequest)
        .code(_code)
        .message(_message)
        .headers(_responseHeaders)
        .body(_CacheResponseBody(contentType, contentLength, snapshot))
        .sentRequestAtMillis(_sentRequestMillis)
        .receivedResponseAtMillis(_receivedResponseMillis)
        .build();
  }

  bool matches(Request request, Response response) {
    return _url == request.url().toString() &&
        _requestMethod == request.method() &&
        HttpHeadersExtension.varyMatches(response, _varyHeaders, request);
  }

  static Future<_Entry> sourceEntry(
    Stream<List<int>> source,
    Encoding encoding,
  ) async {
    assert(encoding != null);
    StreamBuffer<int> sink = StreamBuffer();
    await sink.addStream(source);

    List<String> lines = await sink.read(sink.buffered).then((List<int> bytes) {
      return encoding.decode(bytes);
    }).then(const LineSplitter().convert);

    int cursor = 0;
    String url = lines[cursor++];
    String requestMethod = lines[cursor++];
    HeadersBuilder varyHeadersBuilder = HeadersBuilder();
    int varyRequestHeaderLineCount = int.parse(lines[cursor++]);
    for (int i = 0; i < varyRequestHeaderLineCount; i++) {
      varyHeadersBuilder.addLenientLine(lines[cursor++]);
    }
    Headers varyHeaders = varyHeadersBuilder.build();

    String statusLine = lines[cursor++];
    if (statusLine == null || statusLine.length < 3) {
      throw Exception('Unexpected status line: $statusLine');
    }
    int code = int.parse(statusLine.substring(0, 3));
    String message = statusLine.substring(3).replaceFirst(' ', '');

    HeadersBuilder responseHeadersBuilder = HeadersBuilder();
    int responseHeaderLineCount = int.parse(lines[cursor++]);
    for (int i = 0; i < responseHeaderLineCount; i++) {
      responseHeadersBuilder.addLenientLine(lines[cursor++]);
    }
    Headers responseHeaders = responseHeadersBuilder.build();

    String sendRequestMillisString = responseHeaders.value(_SENT_MILLIS);
    String receivedResponseMillisString =
        responseHeaders.value(_RECEIVED_MILLIS);

    responseHeaders = responseHeaders
        .newBuilder()
        .removeAll(_SENT_MILLIS)
        .removeAll(_RECEIVED_MILLIS)
        .build();

    int sentRequestMillis = sendRequestMillisString != null
        ? int.parse(sendRequestMillisString)
        : 0;
    int receivedResponseMillis = receivedResponseMillisString != null
        ? int.parse(receivedResponseMillisString)
        : 0;

    return _Entry(url, requestMethod, varyHeaders, code, message,
        responseHeaders, sentRequestMillis, receivedResponseMillis);
  }

  static _Entry responseEntry(Response response) {
    String url = response.request().url().toString();
    Headers varyHeaders = HttpHeadersExtension.varyHeaders(response);
    String requestMethod = response.request().method();
    int code = response.code();
    String message = response.message();
    Headers responseHeaders = response.headers();
    int sentRequestMillis = response.sentRequestAtMillis();
    int receivedResponseMillis = response.receivedResponseAtMillis();
    return _Entry(url, requestMethod, varyHeaders, code, message,
        responseHeaders, sentRequestMillis, receivedResponseMillis);
  }
}

class _CacheResponseBody extends ResponseBody {
  final MediaType _contentType;
  final int _contentLength;
  final Snapshot _snapshot;

  _CacheResponseBody(
    MediaType contentType,
    int contentLength,
    Snapshot snapshot,
  )   : _contentType = contentType,
        _contentLength = contentLength,
        _snapshot = snapshot;

  @override
  MediaType contentType() {
    return _contentType;
  }

  @override
  int contentLength() {
    return _contentLength;
  }

  Snapshot snapshot() {
    return _snapshot;
  }

  @override
  Stream<List<int>> source() {
    return _snapshot.getSource(Cache.ENTRY_BODY);
  }

  @override
  void close() {}
}
