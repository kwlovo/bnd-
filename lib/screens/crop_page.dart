import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/imaging.dart';
import '../ui.dart';
import 'photo.dart';

/// 一張大圖切成多張卡：選一張拍了很多張卡的圖，調好格線，按順序切開。
/// 返回切好的相片（左到右、上到下）；取消返回 null。
Future<List<Uint8List>?> cropMany(BuildContext context,
    {required int count, List<String>? labels}) async {
  final raw = await pickPhoto(context, raw: true);
  if (raw == null || !context.mounted) return null;
  return Navigator.push<List<Uint8List>>(
    context,
    MaterialPageRoute(builder: (_) => CropPage(raw, count: count, labels: labels)),
  );
}

class CropPage extends StatefulWidget {
  const CropPage(this.raw, {super.key, required this.count, this.labels});
  final Uint8List raw;

  /// 想切出幾張（用來猜預設的格數）。
  final int count;

  /// 每一格是誰（按順序），顯示在格子上方便對。
  final List<String>? labels;

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  ui.Image? im;
  late int cols = widget.count <= 3 ? widget.count : (widget.count == 4 ? 2 : 3);
  late int rows = (widget.count / cols).ceil();
  // 四邊各裁掉多少（佔整張圖的比例）。
  double l = 0, r = 0, t = 0, b = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    decodeImage(widget.raw).then((x) {
      if (mounted) setState(() => im = x);
    });
  }

  /// 第 k 格在原圖上的位置。
  Rect _cell(int k, double w, double h) {
    final x0 = w * l, y0 = h * t;
    final cw = w * (1 - l - r) / cols, ch = h * (1 - t - b) / rows;
    return Rect.fromLTWH(x0 + (k % cols) * cw, y0 + (k ~/ cols) * ch, cw, ch);
  }

  Future<void> _cut() async {
    final image = im!;
    setState(() => busy = true);
    final out = <Uint8List>[];
    for (var k = 0; k < rows * cols; k++) {
      out.add(await jpegFrom(image,
          src: _cell(k, image.width.toDouble(), image.height.toDouble())));
    }
    if (mounted) Navigator.pop(context, out);
  }

  Widget _stepper(String label, int v, ValueChanged<int> set) => Row(children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        IconButton(
          tooltip: '$label 減少',
          onPressed: v <= 1 ? null : () => setState(() => set(v - 1)),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$v', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        IconButton(
          tooltip: '$label 增加',
          onPressed: v >= 10 ? null : () => setState(() => set(v + 1)),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ]);

  Widget _edge(String label, double v, ValueChanged<double> set) => Row(children: [
        SizedBox(width: 28, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: v,
            max: 0.45,
            onChanged: (x) => setState(() => set(x)),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final image = im;
    final n = rows * cols;
    return Scaffold(
      appBar: AppBar(title: const Text('大圖切開')),
      body: image == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              const Text('調到每一格剛好框住一張卡。編號就是切出來的順序。',
                  style: TextStyle(fontSize: 13, color: cSub)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: AspectRatio(
                  aspectRatio: image.width / image.height,
                  child: Stack(fit: StackFit.expand, children: [
                    RawImage(image: image, fit: BoxFit.fill),
                    CustomPaint(
                      painter: _Grid(
                        [for (var k = 0; k < n; k++) _cell(k, 1, 1)],
                        widget.labels,
                      ),
                    ),
                  ]),
                ),
              ),
              Wrap(spacing: 12, children: [
                _stepper('橫排', cols, (v) => cols = v),
                _stepper('直排', rows, (v) => rows = v),
              ]),
              const FieldLabel('四邊裁掉多少'),
              _edge('左', l, (v) => l = v),
              _edge('右', r, (v) => r = v),
              _edge('上', t, (v) => t = v),
              _edge('下', b, (v) => b = v),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: busy ? null : _cut,
                child: Text(busy ? '切圖中…' : '切成 $n 張'),
              ),
            ]),
    );
  }
}

class _Grid extends CustomPainter {
  _Grid(this.cells, this.labels);

  /// 每格的位置（0–1 的比例）。
  final List<Rect> cells;
  final List<String>? labels;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = cAccent;
    final shade = Paint()..color = const Color(0x99FFFFFF);
    if (cells.isEmpty) return;
    // 裁掉的四邊蓋一層白，看得出哪裡不要。
    final keep = Rect.fromLTRB(cells.first.left * size.width, cells.first.top * size.height,
        cells.last.right * size.width, cells.last.bottom * size.height);
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size),
          Path()..addRect(keep)),
      shade,
    );
    for (var k = 0; k < cells.length; k++) {
      final c = cells[k];
      final rc = Rect.fromLTWH(c.left * size.width, c.top * size.height,
          c.width * size.width, c.height * size.height);
      canvas.drawRect(rc, line);
      final who = labels != null && k < labels!.length ? ' ${labels![k]}' : '';
      final tp = TextPainter(
        text: TextSpan(
          text: ' ${k + 1}$who ',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              backgroundColor: cAccent),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: rc.width);
      tp.paint(canvas, rc.topLeft);
    }
  }

  @override
  bool shouldRepaint(_Grid old) => true;
}
