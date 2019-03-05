import 'dart:async';
import 'dart:convert';

import 'package:fake_http/okhttp3/cache.dart';
import 'package:flutter/foundation.dart';
import 'package:file/file.dart';

class DiskCache implements RawCache {
  final AsyncValueGetter<Directory> _directory;
  final int _valueCount;

  DiskCache._(
    AsyncValueGetter<Directory> directory,
    int valueCount,
  )   : _directory = directory,
        _valueCount = valueCount;

  @override
  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber,
  ]) async {
    _Entry entry = _Entry(await _directory(), _valueCount, key);
    return entry.editor();
  }

  @override
  Future<Snapshot> get(String key) async {
    _Entry entry = _Entry(await _directory(), _valueCount, key);
    return entry.snapshot();
  }

  @override
  Future<bool> remove(String key) async {
    _Entry entry = _Entry(await _directory(), _valueCount, key);
    return await entry.remove();
  }

  static DiskCache create(AsyncValueGetter<Directory> directory) {
    assert(directory != null);
    return DiskCache._(directory, Cache.ENTRY_COUNT);
  }
}

class _Entry {
  final String _key;
  final List<File> _cacheFiles;

  _Entry(
    Directory directory,
    int valueCount,
    String key,
  )   : _key = key,
        _cacheFiles = List.generate(valueCount, (int index) {
          return directory.childFile('$key.$index');
        });

  String key() {
    return _key;
  }

  List<File> cacheFiles() {
    return _cacheFiles;
  }

  Editor editor() {
    return _EditorImpl(this);
  }

  Snapshot snapshot() {
    List<Stream<List<int>>> sources = _cacheFiles.map((File cacheFile) {
      return cacheFile.openRead();
    }).toList();
    List<int> lengths = _cacheFiles.map((File cacheFile) {
      return cacheFile.lengthSync();
    }).toList();
    return Snapshot(_key, RawCache.ANY_SEQUENCE_NUMBER, sources, lengths);
  }

  Future<bool> remove() async {
    for (File cacheFile in _cacheFiles) {
      if (cacheFile.existsSync()) {
        cacheFile.deleteSync();
      }
    }
    return true;
  }
}

class _EditorImpl implements Editor {
  final List<File> _cleanFiles;
  final List<File> _dirtyFiles;

  bool _done = false;

  _EditorImpl(_Entry entry)
      : _cleanFiles = entry.cacheFiles(),
        _dirtyFiles = entry.cacheFiles().map((File cacheFile) {
          return cacheFile.parent.childFile(
              '${cacheFile.basename}.${DateTime.now().millisecondsSinceEpoch}');
        }).toList();

  @override
  StreamSink<List<int>> newSink(int index, Encoding encoding) {
    if (_done) {
      throw AssertionError();
    }
    File dirtyFile = _dirtyFiles[index];
    if (dirtyFile.existsSync()) {
      dirtyFile.deleteSync();
    }
    dirtyFile.createSync(recursive: true);
    return dirtyFile.openWrite(mode: FileMode.write, encoding: encoding);
  }

  @override
  Stream<List<int>> newSource(int index, Encoding encoding) {
    if (!_done) {
      throw AssertionError();
    }
    File cleanFile = _cleanFiles[index];
    if (!cleanFile.existsSync()) {
      throw AssertionError('cleanFile is not exists.');
    }
    return cleanFile.openRead();
  }

  @override
  void commit() {
    if (_done) {
      throw AssertionError();
    }
    _complete(true);
    _done = true;
  }

  @override
  void abort() {
    if (_done) {
      throw AssertionError();
    }
    _complete(false);
    _done = true;
  }

  @override
  void detach() {
    for (File dirtyFile in _dirtyFiles) {
      if (dirtyFile.existsSync()) {
        dirtyFile.deleteSync();
      }
    }
  }

  void _complete(bool success) {
    if (success) {
      for (int i = 0; i < _dirtyFiles.length; i++) {
        File dirtyFile = _dirtyFiles[i];
        if (dirtyFile.existsSync()) {
          File cleanFile = _cleanFiles[i];
//          print('${dirtyFile.path} - ${cleanFile.path}');
          if (cleanFile.existsSync()) {
            cleanFile.deleteSync();
          }
          dirtyFile.renameSync(cleanFile.path);
        }
      }
    } else {
      detach();
    }
  }
}
