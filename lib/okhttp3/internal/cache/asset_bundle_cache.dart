import 'dart:async';

import 'package:fake_http/okhttp3/cache.dart';
import 'package:flutter/services.dart';

class AssetBundleCache implements RawCache {
  final AssetBundle _bundle;
  final String _package;
  final String _directory;
  final int _valueCount;

  AssetBundleCache._(
    AssetBundle bundle,
    String package,
    String directory,
    int valueCount,
  )   : _bundle = bundle,
        _package = package,
        _directory = directory,
        _valueCount = valueCount;

  @override
  Future<Snapshot> get(String key) {
    _Entry entry = _Entry(_bundle, _package, _directory, _valueCount, key);
    return entry.snapshot();
  }

  @override
  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber,
  ]) async {
    throw UnsupportedError(
        '${this.runtimeType}#edit(key, [expectedSequenceNumber]) is not supported!');
  }

  @override
  Future<bool> remove(String key) async {
    throw UnsupportedError(
        '${this.runtimeType}#remove(key) is not supported!');
  }

  static AssetBundleCache create(
    String directory, [
    AssetBundle bundle,
    String package,
  ]) {
    assert(directory != null && directory.isNotEmpty);
    return AssetBundleCache._(
        bundle, package, directory, Cache.ENTRY_COUNT);
  }
}

class _Entry {
  final AssetBundle _bundle;
  final String _package;
  final String _directory;
  final int _valueCount;
  final String _key;

  _Entry(
    AssetBundle bundle,
    String package,
    String directory,
    int valueCount,
    String key,
  )   : _bundle = bundle,
        _package = package,
        _directory = directory,
        _valueCount = valueCount,
        _key = key;

  Future<Snapshot> snapshot() async {
    List<Stream<List<int>>> sources = [];
    List<int> lengths = [];
    for (int i = 0; i < _valueCount; i++) {
      String keyName = _keyName(_key, i);
      ByteData byteData = await _chosenBundle().load(keyName);
      sources.add(Stream.fromIterable([
        byteData.buffer.asUint8List(),
      ]));
      lengths.add(byteData.lengthInBytes);
    }
    return Snapshot(_key, RawCache.ANY_SEQUENCE_NUMBER, sources, lengths);
  }

  AssetBundle _chosenBundle() {
    return _bundle != null ? _bundle : rootBundle;
  }

  String _keyName(String key, int index) {
    return _package == null
        ? '$_directory/$key.$index'
        : 'packages/$_package/$_directory/$key.$index';
  }
}
