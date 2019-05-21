import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_okhttp/okhttp3/headers.dart';
import 'package:fake_okhttp/okhttp3/internal/http_extension.dart';
import 'package:fake_okhttp/okhttp3/media_type.dart';
import 'package:fake_okhttp/okhttp3/request_body.dart';

class MultipartBody extends RequestBody {
  MultipartBody._(
    String boundary,
    MediaType type,
    List<Part> parts,
  )   : _boundary = boundary,
        _originalType = type,
        _contentType =
            MediaType.parse('${type.toString()}; boundary=$boundary'),
        _parts = parts;

  static final MediaType MIXED = MediaType.parse('multipart/mixed');
  static final MediaType ALTERNATIVE = MediaType.parse('multipart/alternative');
  static final MediaType DIGEST = MediaType.parse('multipart/digest');
  static final MediaType PARALLEL = MediaType.parse('multipart/parallel');
  static final MediaType FORM = MediaType.parse('multipart/form-data');

  static const String _COLONSPACE = ': ';
  static const String _CRLF = '\r\n';
  static const String _DASHDASH = '--';

  final String _boundary;
  final MediaType _originalType;
  final MediaType _contentType;
  final List<Part> _parts;
  int _contentLength = -1;

  MediaType type() {
    return _originalType;
  }

  String boundary() {
    return _boundary;
  }

  int size() {
    return _parts.length;
  }

  List<Part> parts() {
    return _parts;
  }

  @override
  MediaType contentType() {
    return _contentType;
  }

  @override
  int contentLength() {
    if (_contentLength != -1) {
      return _contentLength;
    }

    List<int> readAscii(String source) {
      return utf8.encode(source);
    }

    List<int> readUtf8(String source) {
      return utf8.encode(source);
    }

    int length = 0;

    for (int p = 0, partCount = _parts.length; p < partCount; p++) {
      Part part = _parts[p];
      Headers headers = part.headers();
      RequestBody body = part.body();

      length += readAscii(_DASHDASH).length;
      length += readAscii(_boundary).length;
      length += readAscii(_CRLF).length;

      if (headers != null) {
        for (int h = 0, headerCount = headers.size(); h < headerCount; h++) {
          length += readUtf8(headers.nameAt(h)).length;
          length += readAscii(_COLONSPACE).length;
          length += readUtf8(headers.valueAt(h)).length;
          length += readAscii(_CRLF).length;
        }
      }

      MediaType contentType = body.contentType();
      if (contentType != null) {
        length += readUtf8(HttpHeaders.contentTypeHeader).length;
        length += readAscii(_COLONSPACE).length;
        length += readUtf8(contentType.toString()).length;
        length += readAscii(_CRLF).length;
      }

      int contentLength = body.contentLength();
      if (contentLength != -1) {
        length += readUtf8(HttpHeaders.contentLengthHeader).length;
        length += readAscii(_COLONSPACE).length;
        length += readUtf8('$contentLength').length;
        length += readAscii(_CRLF).length;
      } else {
        return -1;
      }

      length += readAscii(_CRLF).length;

      length += contentLength;

      length += readAscii(_CRLF).length;
    }

    length += readAscii(_DASHDASH).length;
    length += readAscii(_boundary).length;
    length += readAscii(_DASHDASH).length;
    length += readAscii(_CRLF).length;

    _contentLength = length;
    return _contentLength;
  }

  @override
  Future<void> writeTo(StreamSink<List<int>> sink) async {
    void writeAscii(String source) {
      sink.add(ascii.encode(source));
    }

    void writeUtf8(String source) {
      sink.add(utf8.encode(source));
    }

    for (int p = 0, partCount = _parts.length; p < partCount; p++) {
      Part part = _parts[p];
      Headers headers = part.headers();
      RequestBody body = part.body();

      writeAscii(_DASHDASH);
      writeAscii(_boundary);
      writeAscii(_CRLF);

      if (headers != null) {
        for (int h = 0, headerCount = headers.size(); h < headerCount; h++) {
          writeUtf8(headers.nameAt(h));
          writeAscii(_COLONSPACE);
          writeUtf8(headers.valueAt(h));
          writeAscii(_CRLF);
        }
      }

      MediaType contentType = body.contentType();
      if (contentType != null) {
        writeUtf8(HttpHeaders.contentTypeHeader);
        writeAscii(_COLONSPACE);
        writeUtf8(contentType.toString());
        writeAscii(_CRLF);
      }

      int contentLength = body.contentLength();
      if (contentLength != -1) {
        writeUtf8(HttpHeaders.contentLengthHeader);
        writeAscii(_COLONSPACE);
        writeUtf8('$contentLength');
        writeAscii(_CRLF);
      }

      writeAscii(_CRLF);

      await body.writeTo(sink);

      writeAscii(_CRLF);
    }

    writeAscii(_DASHDASH);
    writeAscii(_boundary);
    writeAscii(_DASHDASH);
    writeAscii(_CRLF);
  }
}

class Part {
  Part._(
    Headers headers,
    RequestBody body,
  )   : _headers = headers,
        _body = body;

  final Headers _headers;
  final RequestBody _body;

  Headers headers() {
    return _headers;
  }

  RequestBody body() {
    return _body;
  }

  static Part create(Headers headers, RequestBody body) {
    if (body == null) {
      throw ArgumentError.notNull('body');
    }
    if (headers != null &&
        headers.value(HttpHeaders.contentTypeHeader) != null) {
      throw ArgumentError(
          'Unexpected header: ${HttpHeaders.contentTypeHeader}');
    }
    if (headers != null &&
        headers.value(HttpHeaders.contentLengthHeader) != null) {
      throw ArgumentError(
          'Unexpected header: ${HttpHeaders.contentLengthHeader}');
    }
    return Part._(headers, body);
  }

  static Part createFormData(String name, String filename, RequestBody body) {
    if (name == null) {
      throw ArgumentError.notNull('name');
    }

    String disposition = 'form-data; name="${_browserEncode(name)}"';
    if (filename != null) {
      disposition = '$disposition; filename="${_browserEncode(filename)}"';
    }
    Headers headers = HeadersBuilder()
        .add(HttpHeadersExtension.contentDispositionHeader,
            disposition.toString())
        .build();
    return create(headers, body);
  }

  static String _browserEncode(String value) {
    // http://tools.ietf.org/html/rfc2388 mandates some complex encodings for
    // field names and file names, but in practice user agents seem not to
    // follow this at all. Instead, they URL-encode `\r`, `\n`, and `\r\n` as
    // `\r\n`; URL-encode `"`; and do nothing else (even for `%` or non-ASCII
    // characters). We follow their behavior.
    return value
        .replaceAll(RegExp(r'\r\n|\r|\n'), '%0D%0A')
        .replaceAll('"', '%22');
  }
}

class MultipartBodyBuilder {
  MultipartBodyBuilder(
    String boundary,
  )   : assert(boundary != null && boundary.isNotEmpty),
        _boundary = boundary;

  final String _boundary;
  MediaType _type = MultipartBody.MIXED;
  final List<Part> _parts = <Part>[];

  MultipartBodyBuilder setType(MediaType type) {
    if (type == null) {
      throw ArgumentError.notNull('type');
    }
    if (type.type() != 'multipart') {
      throw ArgumentError('${type.type()} != multipart');
    }
    _type = type;
    return this;
  }

  MultipartBodyBuilder addPart(Headers headers, RequestBody body) {
    return _addPart(Part.create(headers, body));
  }

  MultipartBodyBuilder addFormDataPart(
      String name, String filename, RequestBody body) {
    return _addPart(Part.createFormData(name, filename, body));
  }

  MultipartBodyBuilder _addPart(Part part) {
    if (part == null) {
      throw ArgumentError.notNull('part');
    }
    _parts.add(part);
    return this;
  }

  MultipartBody build() {
    if (_parts.isEmpty) {
      throw ArgumentError('Multipart body must have at least one part.');
    }
    return MultipartBody._(_boundary, _type, List<Part>.unmodifiable(_parts));
  }
}
