import 'dart:convert';

import 'package:fake_http/okhttp3/media_type.dart';

class EncodingUtil {
  static Encoding encoding(
    MediaType contentType, [
    Encoding defaultValue,
  ]) {
    Encoding encoding;
    if (contentType != null && contentType.charset() != null) {
      encoding = Encoding.getByName(contentType.charset());
    }
    if (encoding == null) {
      encoding = defaultValue ?? utf8;
    }
    return encoding;
  }
}
