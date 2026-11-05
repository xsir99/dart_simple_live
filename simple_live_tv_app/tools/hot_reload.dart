import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

void main(List<String> args) async {
  final uri = args.isNotEmpty
      ? args.first
      : _findVmServiceUriFromLog('tools/flutter_run.log');
  if (uri == null || uri.isEmpty) {
    stderr.writeln('找不到 VM Service URI，请传入或检查 tools/flutter_run.log');
    exit(1);
  }

  VmService? service;
  try {
    final wsUri = '${uri.trim().replaceFirst('http://', 'ws://')}ws';
    service = await vmServiceConnectUri(wsUri);
    final vm = await service.getVM();
    final isolates = vm.isolates;
    if (isolates == null || isolates.isEmpty) {
      stderr.writeln('没有可用的 isolate');
      exit(1);
    }
    final isolateId = isolates.first.id!;
    final report = await service.reloadSources(isolateId);
    if (report.success == true) {
      stdout.writeln('Hot reload 成功');
    } else {
      stdout.writeln('Hot reload 完成');
    }
    await service.dispose();
  } catch (e) {
    stderr.writeln('Hot reload 失败: $e');
    exit(1);
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
