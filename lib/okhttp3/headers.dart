class Headers {
  final List<String> _namesAndValues;

  Headers._(HeadersBuilder builder)
      : _namesAndValues = List.unmodifiable(builder._namesAndValues);

  int size() {
    return _namesAndValues.length ~/ 2;
  }

  String nameAt(int index) {
    return _namesAndValues[index * 2];
  }

  String valueAt(int index) {
    return _namesAndValues[index * 2 + 1];
  }

  Set<String> names() {
    List<String> names = [];
    for (int i = 0; i < _namesAndValues.length; i += 2) {
      names.add(_namesAndValues[i]);
    }
    return new Set.from(names);
  }

  String value(String name) {
    assert(name != null);
    for (int i = _namesAndValues.length - 2; i >= 0; i -= 2) {
      if (name.toLowerCase() == _namesAndValues[i]) {
        return _namesAndValues[i + 1];
      }
    }
    return null;
  }

  List<String> values(String name) {
    assert(name != null);
    List<String> values = [];
    for (int i = 0; i < _namesAndValues.length; i += 2) {
      if (name.toLowerCase() == _namesAndValues[i]) {
        values.add(_namesAndValues[i + 1]);
      }
    }
    return List.unmodifiable(values);
  }

  Map<String, List<String>> toMultimap() {
    Map<String, List<String>> multimap = {};
    for (int i = 0; i < _namesAndValues.length; i += 2) {
      String name = _namesAndValues[i];
      List<String> values = multimap[name];
      if (values == null) {
        values = [];
        multimap.putIfAbsent(name, () => values);
      }
      values.add(_namesAndValues[i + 1]);
    }
    return Map.unmodifiable(multimap);
  }

  HeadersBuilder newBuilder() {
    return new HeadersBuilder._(this);
  }

  static Headers of(Map<String, List<String>> multimap) {
    HeadersBuilder builder = new HeadersBuilder();
    if (multimap != null && multimap.isNotEmpty) {
      multimap.forEach((String name, List<String> values) {
        if (values != null && values.isNotEmpty) {
          values.forEach((String value) {
            builder.add(name, value);
          });
        }
      });
    }
    return builder.build();
  }
}

class HeadersBuilder {
  final List<String> _namesAndValues = [];

  HeadersBuilder();

  HeadersBuilder._(Headers headers) {
    _namesAndValues.addAll(headers._namesAndValues);
  }

  HeadersBuilder add(String name, String value) {
    _checkNameAndValue(name, value);
    addLenient(name, value);
    return this;
  }

  HeadersBuilder addLenient(String name, String value) {
    _namesAndValues.add(name.toLowerCase());
    _namesAndValues.add(value.trim());
    return this;
  }

  HeadersBuilder addLenientLine(String line) {
    int index = line.indexOf(':', 1);
    if (index != -1) {
      return addLenient(line.substring(0, index), line.substring(index + 1));
    } else if (line.startsWith(':')) {
      // Work around empty header names and header names that start with a
      // colon (created by old broken SPDY versions of the response cache).
      return addLenient('', line.substring(1)); // Empty header name.
    } else {
      return addLenient('', line); // No header name.
    }
  }

  HeadersBuilder removeAll(String name) {
    for (int i = 0; i < _namesAndValues.length; i += 2) {
      if (name.toLowerCase() == _namesAndValues[i]) {
        _namesAndValues.removeAt(i); // name
        _namesAndValues.removeAt(i); // value
        i -= 2;
      }
    }
    return this;
  }

  HeadersBuilder set(String name, String value) {
    _checkNameAndValue(name, value);
    removeAll(name);
    addLenient(name, value);
    return this;
  }

  void _checkNameAndValue(String name, String value) {
    assert(name != null && name.isNotEmpty);
    assert(value != null);
  }

  Headers build() {
    return new Headers._(this);
  }
}
