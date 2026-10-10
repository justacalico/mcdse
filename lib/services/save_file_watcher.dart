import 'dart:async';
import 'dart:io';

class SaveFileWatcher {
  SaveFileWatcher({this.debounce = const Duration(milliseconds: 400)});

  final Duration debounce;
  StreamSubscription<FileSystemEvent>? _sub;
  Timer? _timer;
  DateTime? _selfWriteStamp;

  void watch(String path, void Function(String path) onChanged) {
    dispose();
    _sub = File(path).watch().listen((event) {
      if (event.type != FileSystemEvent.modify) return;
      _timer?.cancel();
      _timer = Timer(debounce, () {
        final stamp = _selfWriteStamp;
        if (stamp != null &&
            !File(path).lastModifiedSync().isAfter(stamp)) {
          return;
        }
        onChanged(path);
      });
    }, onError: (_) {});
  }

  void markSelfWrite(String path) {
    try {
      _selfWriteStamp = File(path).lastModifiedSync();
    } catch (_) {}
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
    _selfWriteStamp = null;
  }
}
