import 'dart:convert';

import 'package:fake_http/okhttp3/media_type.dart';

class EncodingUtil {
  EncodingUtil._();

  static Encoding encoding(
    MediaType contentType, [
    Encoding defaultValue = utf8,
  ]) {
    Encoding encoding;
    if (contentType != null && contentType.charset() != null) {
      encoding = Encoding.getByName(contentType.charset());
    }
    if (encoding == null) {
      encoding = defaultValue;
    }
    return encoding;
  }
}
