import 'dart:io';

class MediaType {
  MediaType(
    String primaryType,
    String subType, [
    String charset,
    Map<String, String> parameters,
  ]) : _contentType = ContentType(
          primaryType,
          subType,
          charset: charset,
          parameters: parameters,
        );

  MediaType._(
    ContentType contentType,
  ) : _contentType = contentType;

  static final MediaType TEXT = MediaType._(ContentType.text);
  static final MediaType HTML = MediaType._(ContentType.html);
  static final MediaType JSON = MediaType._(ContentType.json);
  static final MediaType BINARY = MediaType._(ContentType.binary);

  final ContentType _contentType;

  String type() {
    return _contentType.primaryType;
  }

  String subtype() {
    return _contentType.subType;
  }

  String mimeType() {
    return _contentType.mimeType;
  }

  String charset() {
    return _contentType.charset;
  }

  @override
  String toString() {
    if (_contentType.charset != null) {
      return '${_contentType.mimeType}; charset=${_contentType.charset}';
    }
    return _contentType.mimeType;
  }

  @override
  int get hashCode {
    return toString().hashCode;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MediaType &&
        runtimeType == other.runtimeType &&
        toString() == other.toString();
  }

  static MediaType parse(String value) {
    ContentType contentType = ContentType.parse(value);
    return MediaType._(contentType);
  }
}
