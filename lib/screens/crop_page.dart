import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior;
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
  const CropPage(this.raw,
      {super.key, required this.count, this.labels, this.single = false});
  final Uint8List raw;

  /// true：只裁剪一張（不分格），用於單張相片。
  final bool single;

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

  /// 正在拖的部分：tl/tr/bl/br 四角、l/r/t/b 四邊、move 整個框；null 沒在拖。
  String? _drag;

  /// 手指按下的地方是框的哪一部分。
  String? _hit(Offset p, Size sz) {
    final rc = Rect.fromLTRB(
        l * sz.width, t * sz.height, (1 - r) * sz.width, (1 - b) * sz.height);
    const near = 30.0;
    bool close(Offset a) => (a - p).distance < near;
    if (close(rc.topLeft)) return 'tl';
    if (close(rc.topRight)) return 'tr';
    if (close(rc.bottomLeft)) return 'bl';
    if (close(rc.bottomRight)) return 'br';
    final inY = p.dy > rc.top - near && p.dy < rc.bottom + near;
    final inX = p.dx > rc.left - near && p.dx < rc.right + near;
    if (inY && (p.dx - rc.left).abs() < 20) return 'l';
    if (inY && (p.dx - rc.right).abs() < 20) return 'r';
    if (inX && (p.dy - rc.top).abs() < 20) return 't';
    if (inX && (p.dy - rc.bottom).abs() < 20) return 'b';
    if (rc.contains(p)) return 'move';
    return null;
  }

  /// 拖動時改四邊的位置。框最少保留圖的 8%。
  void _move(Offset d, Size sz) {
    final k = _drag;
    if (k == null) return;
    var dx = d.dx / sz.width, dy = d.dy / sz.height;
    const m = 0.08;
    setState(() {
      if (k == 'move') {
        dx = dx.clamp(-l, r);
        dy = dy.clamp(-t, b);
        l += dx;
        r -= dx;
        t += dy;
        b -= dy;
        return;
      }
      if (k.contains('l')) l = (l + dx).clamp(0.0, 1 - r - m);
      if (k.contains('r')) r = (r - dx).clamp(0.0, 1 - l - m);
      if (k.contains('t')) t = (t + dy).clamp(0.0, 1 - b - m);
      if (k.contains('b')) b = (b - dy).clamp(0.0, 1 - t - m);
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final image = im;
    final n = rows * cols;
    return Scaffold(
      appBar: AppBar(title: Text(widget.single ? '裁剪相片' : '大圖切開')),
      body: image == null
          ? const Center(child: CircularProgressIndicator())
          // 頁面不捲動，手指在相片上拖動只會調整藍框。
          : ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
              Text(
                  widget.single
                      ? '用手指拖藍框的四角或四邊調大小，拖框中間可以移動。藍框裡面就是保留的部分，不用裁就直接按「完成」。'
                      : '用手指拖藍框的四角或四邊，拖框中間可以移動，調到每一格剛好框住一張卡。編號就是切出來的順序。',
                  style: const TextStyle(fontSize: 13, color: cSub)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * (widget.single ? 0.62 : 0.5)),
                child: AspectRatio(
                  aspectRatio: image.width / image.height,
                  child: LayoutBuilder(builder: (context, box) {
                    final sz = box.biggest;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // 用手指按下的位置判斷拖哪裡，不是移動一段距離之後的位置。
                      dragStartBehavior: DragStartBehavior.down,
                      onPanStart: (d) => _drag = _hit(d.localPosition, sz),
                      onPanUpdate: (d) => _move(d.delta, sz),
                      onPanEnd: (_) => _drag = null,
                      child: Stack(fit: StackFit.expand, children: [
                        RawImage(image: image, fit: BoxFit.fill),
                        CustomPaint(
                          painter: _Grid(
                            [for (var k = 0; k < n; k++) _cell(k, 1, 1)],
                            widget.labels,
                            numbered: !widget.single,
                          ),
                        ),
                      ]),
                    );
                  }),
                ),
              ),
              if (!widget.single)
              Wrap(spacing: 12, children: [
                _stepper('橫排', cols, (v) => cols = v),
                _stepper('直排', rows, (v) => rows = v),
              ]),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => l = r = t = b = 0),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重設成整張'),
                ),
              ),
              const SizedBox(height: 4),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: busy ? null : _cut,
                child: Text(busy
                    ? '處理中…'
                    : widget.single
                        ? '完成'
                        : '切成 $n 張'),
              ),
            ]),
    );
  }
}

class _Grid extends CustomPainter {
  _Grid(this.cells, this.labels, {this.numbered = true});

  /// 格子上要不要寫編號（單張裁剪不用）。
  final bool numbered;

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
    // 四角的把手，提示可以用手指拖。
    final handle = Paint()..color = cAccent;
    const hs = 14.0;
    for (final c in [keep.topLeft, keep.topRight, keep.bottomLeft, keep.bottomRight]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: hs, height: hs), const Radius.circular(3)),
          handle);
    }
    for (var k = 0; k < cells.length; k++) {
      final c = cells[k];
      final rc = Rect.fromLTWH(c.left * size.width, c.top * size.height,
          c.width * size.width, c.height * size.height);
      canvas.drawRect(rc, line);
      if (!numbered) continue;
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
