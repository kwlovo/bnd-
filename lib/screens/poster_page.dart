import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/imaging.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';

/// 出物圖：勾選要出的周邊、填價錢，生成一張可以直接發出去的圖。
class PosterPage extends StatefulWidget {
  const PosterPage({super.key});
  @override
  State<PosterPage> createState() => _PosterPageState();
}

class _PosterPageState extends State<PosterPage> {
  final title = TextEditingController(text: '出物');
  final note = TextEditingController(text: '平郵 +\$4 · 可易寄取／面交');
  final sel = <String>[]; // 勾選的周邊，按勾選順序排
  final prices = <String, TextEditingController>{};
  String member = '全部';
  String cols = '3';
  bool busy = false;

  Future<void> _make() async {
    setState(() => busy = true);
    try {
      final png = await renderPoster(
        title: title.text.trim(),
        note: note.text.trim(),
        cols: int.parse(cols),
        entries: [
          for (final id in sel)
            if (store.itemOf(id) case final i?) (i, prices[id]?.text.trim() ?? ''),
        ],
      );
      if (!mounted) return;
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => _PosterPreview(png)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('生成不到圖，請再試一次')));
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = store.items
        .where((i) => i.status != '已售出' && (member == '全部' || i.member == member))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      appBar: AppBar(title: const Text('出物圖')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('圖上的標題'),
                TextField(controller: title),
                const FieldLabel('圖底的說明（郵寄方式等，可留空）'),
                TextField(controller: note),
                const FieldLabel('每行幾張'),
                SizedBox(
                  width: 120,
                  child: PickField(
                    value: cols,
                    options: const ['2', '3', '4'],
                    onChanged: (v) => setState(() => cols = v),
                  ),
                ),
                const FieldLabel('勾選要出的周邊，價錢可不填'),
              ]),
            ),
            ChipRow(
              options: ['全部', ...store.members],
              value: member,
              onChanged: (v) => setState(() => member = v),
            ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('沒有未出的周邊。', style: TextStyle(color: cSub)),
              ),
            for (final i in list)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card2(
                  padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
                  onTap: () => setState(() {
                    if (!sel.remove(i.id)) sel.add(i.id);
                  }),
                  child: Row(children: [
                    Checkbox(
                      value: sel.contains(i.id),
                      onChanged: (_) => setState(() {
                        if (!sel.remove(i.id)) sel.add(i.id);
                      }),
                    ),
                    ItemThumb(i.member, i.category, size: 44, photo: store.photos[i.id]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(store.titleOf(i),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    if (sel.contains(i.id))
                      SizedBox(
                        width: 92,
                        child: TextField(
                          controller: prices.putIfAbsent(i.id, TextEditingController.new),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(prefixText: '\$ ', hintText: '價錢'),
                        ),
                      ),
                  ]),
                ),
              ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: sel.isEmpty || busy ? null : _make,
              child: Text(busy ? '生成中…' : '生成出物圖（${sel.length} 件）'),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PosterPreview extends StatelessWidget {
  const _PosterPreview(this.png);
  final Uint8List png;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('出物圖')),
        body: Column(children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(png),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  try {
                    await SharePlus.instance.share(ShareParams(
                      files: [
                        XFile.fromData(png, mimeType: 'image/png', name: 'merch-poster.png'),
                      ],
                      fileNameOverrides: const ['merch-poster.png'],
                    ));
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('分享不到，請截圖儲存')));
                    }
                  }
                },
                icon: const Icon(Icons.ios_share, color: Colors.white),
                label: const Text('儲存／分享'),
              ),
            ),
          ),
        ]),
      );
}

TextPainter _text(String s, double size, Color color, double maxWidth,
        {bool bold = false, int maxLines = 1, TextAlign align = TextAlign.left}) =>
    TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
            fontSize: size,
            height: 1.25,
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(minWidth: maxWidth, maxWidth: maxWidth);

/// 畫出物圖，返回 PNG。寬 1080，高度按件數而定。
Future<Uint8List> renderPoster({
  required String title,
  required String note,
  required int cols,
  required List<(Item, String)> entries,
}) async {
  const w = 1080.0, pad = 36.0, gap = 20.0, headH = 140.0;
  final tileW = (w - pad * 2 - gap * (cols - 1)) / cols;
  final photoH = tileW * 4 / 3;
  final nameSize = cols == 2 ? 32.0 : (cols == 3 ? 26.0 : 22.0);
  final priceSize = nameSize + 8;
  final textH = nameSize * 1.25 * 2 + priceSize * 1.25 + 28;
  final tileH = photoH + textH;
  final rows = (entries.length / cols).ceil();
  final footH = note.isEmpty ? 0.0 : 90.0;
  final h = headH + pad + rows * tileH + (rows - 1) * gap + pad + footH;

  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, w, 100000), Paint()..color = cBg);
  c.drawRect(const Rect.fromLTWH(0, 0, w, headH), Paint()..color = cNavy);
  final tt = _text(title.isEmpty ? '出物' : title, 56, Colors.white, w - pad * 2, bold: true);
  tt.paint(c, Offset(pad, (headH - tt.height) / 2));

  for (var k = 0; k < entries.length; k++) {
    final (item, price) = entries[k];
    final x = pad + (k % cols) * (tileW + gap);
    final y = headH + pad + (k ~/ cols) * (tileH + gap);
    final tile = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, tileW, tileH), const Radius.circular(20));
    c.drawRRect(tile, Paint()..color = Colors.white);
    c.drawRRect(
        tile,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = cLine);
    final box = Rect.fromLTWH(x + 10, y + 10, tileW - 20, photoH - 10);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(box, const Radius.circular(14)));
    final bytes = store.photos[item.id];
    if (bytes != null) {
      final im = await decodeImage(bytes);
      // 填滿格子，多出的部分置中裁掉。
      final ia = im.width / im.height, ba = box.width / box.height;
      final sw = ia > ba ? im.height * ba : im.width.toDouble();
      final sh = ia > ba ? im.height.toDouble() : im.width / ba;
      c.drawImageRect(
          im,
          Rect.fromLTWH((im.width - sw) / 2, (im.height - sh) / 2, sw, sh),
          box,
          Paint()..filterQuality = FilterQuality.medium);
      im.dispose();
    } else {
      c.drawRect(box, Paint()..color = const Color(0xFFDCE5FB));
      final ph = _text(item.member, nameSize, const Color(0xFF2A3A5E), box.width,
          bold: true, align: TextAlign.center);
      ph.paint(c, Offset(box.left, box.center.dy - ph.height / 2));
    }
    c.restore();
    final name = _text(store.titleOf(item), nameSize, cInk, tileW - 28, maxLines: 2);
    name.paint(c, Offset(x + 14, y + photoH + 10));
    if (price.isNotEmpty) {
      final p = _text('HK\$ $price', priceSize, cAccent, tileW - 28, bold: true);
      p.paint(c, Offset(x + 14, y + tileH - p.height - 12));
    }
  }
  if (note.isNotEmpty) {
    final n = _text(note, 30, cSub, w - pad * 2, maxLines: 2);
    n.paint(c, Offset(pad, h - footH - pad / 2 + (footH - n.height) / 2));
  }
  final img = await rec.endRecording().toImage(w.round(), h.round());
  final data = (await img.toByteData(format: ui.ImageByteFormat.png))!;
  img.dispose();
  return data.buffer.asUint8List();
}
