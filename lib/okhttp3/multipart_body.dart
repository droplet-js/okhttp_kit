import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_okhttp/okhttp3/headers.dart';
import 'package:fake_okhttp/okhttp3/internal/http_extension.dart';
import 'package:fake_okhttp/okhttp3/internal/util.dart';
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

  static final MediaType mixed = MediaType.parse('multipart/mixed');
  static final MediaType alternative = MediaType.parse('multipart/alternative');
  static final MediaType digest = MediaType.parse('multipart/digest');
  static final MediaType parallel = MediaType.parse('multipart/parallel');
  static final MediaType form = MediaType.parse('multipart/form-data');

  static const String _colonSpace = ': ';
  static const String _crlf = '\r\n';
  static const String _dashDash = '--';

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

      length += readAscii(_dashDash).length;
      length += readAscii(_boundary).length;
      length += readAscii(_crlf).length;

      if (headers != null) {
        for (int h = 0, headerCount = headers.size(); h < headerCount; h++) {
          length += readUtf8(headers.nameAt(h)).length;
          length += readAscii(_colonSpace).length;
          length += readUtf8(headers.valueAt(h)).length;
          length += readAscii(_crlf).length;
        }
      }

      MediaType contentType = body.contentType();
      if (contentType != null) {
        length += readUtf8(HttpHeaders.contentTypeHeader).length;
        length += readAscii(_colonSpace).length;
        length += readUtf8(contentType.toString()).length;
        length += readAscii(_crlf).length;
      }

      int contentLength = body.contentLength();
      if (contentLength != -1) {
        length += readUtf8(HttpHeaders.contentLengthHeader).length;
        length += readAscii(_colonSpace).length;
        length += readUtf8('$contentLength').length;
        length += readAscii(_crlf).length;
      } else {
        return -1;
      }

      length += readAscii(_crlf).length;

      length += contentLength;

      length += readAscii(_crlf).length;
    }

    length += readAscii(_dashDash).length;
    length += readAscii(_boundary).length;
    length += readAscii(_dashDash).length;
    length += readAscii(_crlf).length;

    _contentLength = length;
    return _contentLength;
  }

  @override
  Stream<List<int>> source() {
    StreamController<List<int>> controller =
        StreamController<List<int>>(sync: true);

    void writeAscii(String string) {
      controller.add(utf8.encode(string));
    }

    void writeUtf8(String source) {
      controller.add(utf8.encode(source));
    }

    for (int p = 0, partCount = _parts.length; p < partCount; p++) {
      Part part = _parts[p];
      Headers headers = part.headers();
      RequestBody body = part.body();

      writeAscii(_dashDash);
      writeAscii(_boundary);
      writeAscii(_crlf);

      if (headers != null) {
        for (int h = 0, headerCount = headers.size(); h < headerCount; h++) {
          writeUtf8(headers.nameAt(h));
          writeAscii(_colonSpace);
          writeUtf8(headers.valueAt(h));
          writeAscii(_crlf);
        }
      }

      MediaType contentType = body.contentType();
      if (contentType != null) {
        writeUtf8(HttpHeaders.contentTypeHeader);
        writeAscii(_colonSpace);
        writeUtf8(contentType.toString());
        writeAscii(_crlf);
      }

      int contentLength = body.contentLength();
      if (contentLength != -1) {
        writeUtf8(HttpHeaders.contentLengthHeader);
        writeAscii(_colonSpace);
        writeUtf8('$contentLength');
        writeAscii(_crlf);
      }

      writeAscii(_crlf);

      controller.addStream(body.source(), cancelOnError: true);

      writeAscii(_crlf);
    }

    writeAscii(_dashDash);
    writeAscii(_boundary);
    writeAscii(_dashDash);
    writeAscii(_crlf);

    return controller.stream;
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
  ) : _boundary = boundary ?? Util.boundaryString();

  final String _boundary;
  MediaType _type = MultipartBody.mixed;
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
