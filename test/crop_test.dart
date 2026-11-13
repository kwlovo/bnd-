import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:merch_app/screens/crop_page.dart';

void main() {
  testWidgets('拖右下角縮小藍框，裁出來的圖變小', (tester) async {
    final src = img.encodePng(img.Image(width: 400, height: 400));
    List<Uint8List>? out;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async {
            out = await Navigator.push<List<Uint8List>>(c,
                MaterialPageRoute(builder: (_) => CropPage(src, count: 1, single: true)));
          },
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    for (var k = 0; k < 50 && find.text('完成').evaluate().isEmpty; k++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('完成'), findsOneWidget);
    await tester.pumpAndSettle();

    final box = tester.getRect(find.byType(RawImage));
    // 從右下角往左上拖到一半。
    await tester.dragFrom(box.bottomRight - const Offset(2, 2),
        Offset(-box.width / 2, -box.height / 2));
    await tester.pump();

    await tester.tap(find.text('完成'));
    for (var k = 0; k < 50 && out == null; k++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(out, isNotNull);
    final res = img.decodeJpg(out!.first)!;
    expect(res.width, inInclusiveRange(180, 220));
    expect(res.height, inInclusiveRange(180, 220));
  });
}
