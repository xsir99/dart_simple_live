import 'dart:async';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:watcher/watcher.dart';

/// 自动热更新工具
/// 
/// 用法：
///   cd simple_live_tv_app && dart run tools/auto_hot_reload.dart
/// 
/// 运行后会监控 lib/ 目录下的 Dart 文件变更，每次保存后自动对 TV 上的
/// debug 会话执行 Hot Reload。按 Ctrl+C 退出。
void main(List<String> args) async {
  final uri = args.isNotEmpty
      ? args.first
      : _findVmServiceUriFromLog('tools/flutter_run.log');
  if (uri == null || uri.isEmpty) {
    stderr.writeln('找不到 VM Service URI，请传入或检查 tools/flutter_run.log');
    stderr.writeln('请先运行：flutter run -d <device> --pid-file tools/flutter_run.pid > tools/flutter_run.log 2>&1');
    exit(1);
  }

  stdout.writeln('VM Service: $uri');
  stdout.writeln('正在监控 lib/ 与 ../simple_live_core/lib/ 变更，保存文件后会自动 Hot Reload...');

  final debouncer = _Debouncer(delay: const Duration(milliseconds: 300));
  // 同时监控 TV App 自身与路径依赖的 simple_live_core
  final watchers = [
    DirectoryWatcher('lib'),
    DirectoryWatcher('../simple_live_core/lib'),
  ];

  final subscriptions = <StreamSubscription<WatchEvent>>[];
  for (final watcher in watchers) {
    subscriptions.add(watcher.events.listen((event) {
      if (!event.path.endsWith('.dart')) return;
      // 忽略 generated 文件与 dart tool 缓存
      if (event.path.contains('.dart_tool') || event.path.contains('.g.dart')) {
        return;
      }
      stdout.writeln('[变更] ${event.path}');
      debouncer.run(() => _hotReload(uri));
    }));
  }

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('退出监控');
    for (final s in subscriptions) {
      await s.cancel();
    }
    exit(0);
  });
}

Future<void> _hotReload(String uri) async {
  VmService? service;
  try {
    final wsUri = '${uri.trim().replaceFirst('http://', 'ws://')}ws';
    service = await vmServiceConnectUri(wsUri);
    final vm = await service.getVM();
    final isolates = vm.isolates;
    if (isolates == null || isolates.isEmpty) {
      stderr.writeln('没有可用的 isolate');
      return;
    }
    final isolateId = isolates.first.id!;
    final report = await service.reloadSources(isolateId);
    if (report.success == true) {
      stdout.writeln('✓ Hot reload 成功 ${DateTime.now()}');
    } else {
      stdout.writeln('⚠ Hot reload 完成（可能有编译错误） ${DateTime.now()}');
    }
    await service.dispose();
  } catch (e) {
    stderr.writeln('Hot reload 失败: $e');
    service?.dispose();
  }
}

String? _findVmServiceUriFromLog(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final lines = file.readAsLinesSync().reversed;
  final re = RegExp(r'A Dart VM Service on .* is available at: (http://\S+)');
  for (final line in lines) {
    final m = re.firstMatch(line);
    if (m != null) return m.group(1);
  }
  return null;
}

class _Debouncer {
  final Duration delay;
  Timer? _timer;

  _Debouncer({required this.delay});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }
}
