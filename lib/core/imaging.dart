import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// 把相片檔解開成可以畫的圖。
Future<ui.Image> decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

/// 取圖的一部分（不給就是整張），縮到最長邊不超過 [maxSide]，壓成 JPEG。
Future<Uint8List> jpegFrom(ui.Image im,
    {ui.Rect? src, int maxSide = 600, int quality = 72}) async {
  src ??= ui.Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
  final k = min(1.0, maxSide / max(src.width, src.height));
  final w = max(1, (src.width * k).round());
  final h = max(1, (src.height * k).round());
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  // 底色用白，透明圖也不會變黑。
  c.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  c.drawImageRect(im, src, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium);
  final out = await rec.endRecording().toImage(w, h);
  final data = (await out.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  out.dispose();
  final pic = img.Image.fromBytes(
      width: w, height: h, bytes: data.buffer, numChannels: 4);
  return img.encodeJpg(pic, quality: quality);
}

/// 把任何相片檔縮小壓成 JPEG。
Future<Uint8List> shrinkPhoto(Uint8List bytes) async {
  final im = await decodeImage(bytes);
  final out = await jpegFrom(im);
  im.dispose();
  return out;
}

const _sigSide = 12;

/// 相片的「樣子特徵」：縮成 12×12 的顏色格，再把亮度拉平，用來比較兩張圖像不像。
Future<Float32List> signatureOf(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes,
      targetWidth: _sigSide, targetHeight: _sigSide, allowUpscaling: true);
  final im = (await codec.getNextFrame()).image;
  final d = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  im.dispose();
  final n = _sigSide * _sigSide;
  final v = Float32List(n * 3);
  var mean = 0.0;
  for (var p = 0; p < n; p++) {
    for (var ch = 0; ch < 3; ch++) {
      final x = d.getUint8(p * 4 + ch).toDouble();
      v[p * 3 + ch] = x;
      mean += x;
    }
  }
  mean /= v.length;
  var sd = 0.0;
  for (final x in v) {
    sd += (x - mean) * (x - mean);
  }
  sd = sqrt(sd / v.length);
  if (sd < 1) sd = 1;
  for (var k = 0; k < v.length; k++) {
    v[k] = (v[k] - mean) / sd;
  }
  return v;
}

/// 兩張圖的相似度，0–1，越大越像。
double similarity(Float32List a, Float32List b) {
  var dot = 0.0;
  for (var k = 0; k < a.length; k++) {
    dot += a[k] * b[k];
  }
  // 兩邊都已標準化，dot / n 就是相關係數（−1 到 1）。
  return ((dot / a.length) + 1) / 2;
}
