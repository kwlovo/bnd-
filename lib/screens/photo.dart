import 'dart:typed_data';

import 'package:flutter/cupertino.dart'
    show CupertinoActionSheet, CupertinoActionSheetAction, showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/imaging.dart';
import 'crop_page.dart';
import '../main.dart';
import '../ui.dart';

void _say(BuildContext context, String s) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }
}

/// 問用戶「拍照／從相簿選」（可加「移除相片」），返回 camera / gallery / remove，取消是 null。
Future<String?> _askSource(BuildContext context, {bool remove = false}) =>
    showCupertinoModalPopup<String>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(c, 'camera'),
            child: const Text('拍照'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(c, 'gallery'),
            child: const Text('從相簿選'),
          ),
          if (remove)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(c, 'crop'),
              child: const Text('裁剪現有相片'),
            ),
          if (remove)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(c, 'remove'),
              child: const Text('移除相片'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(c),
          child: const Text('取消'),
        ),
      ),
    );

Future<Uint8List?> _grab(String src, {required bool raw}) async {
  final x = await ImagePicker().pickImage(
    source: src == 'camera' ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 90,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  return raw ? bytes : shrinkPhoto(bytes);
}

/// 打開裁剪畫面，返回裁好並縮小的相片；取消返回 null。
Future<Uint8List?> cropOne(BuildContext context, Uint8List bytes) async {
  final out = await Navigator.push<List<Uint8List>>(
    context,
    MaterialPageRoute(builder: (_) => CropPage(bytes, count: 1, single: true)),
  );
  return out == null || out.isEmpty ? null : out.first;
}

/// 拍照或從相簿選一張。[raw] 為 true 時保留大圖（切圖用）；
/// 否則先讓用戶裁剪，再縮小到適合儲存。
Future<Uint8List?> pickPhoto(BuildContext context,
    {bool raw = false, String? sourceGiven}) async {
  final src = sourceGiven ?? await _askSource(context);
  if (src == null) return null;
  Uint8List? big;
  try {
    big = await _grab(src, raw: true);
  } catch (_) {
    if (context.mounted) _say(context, '讀不到這張相片');
    return null;
  }
  if (big == null || raw || !context.mounted) return big;
  return cropOne(context, big);
}

/// 為一件已存在的周邊拍照、從相簿選相片，或移除相片。
Future<void> pickItemPhoto(BuildContext context, String itemId) async {
  final has = store.photos[itemId];
  final act = await _askSource(context, remove: has != null);
  if (act == null || !context.mounted) return;
  String? err;
  if (act == 'remove') {
    err = await store.setPhoto(itemId, null);
  } else if (act == 'crop') {
    // 裁剪現有的相片。
    final b = await cropOne(context, has!);
    if (b == null) return;
    err = await store.setPhoto(itemId, b);
  } else {
    final b = await pickPhoto(context, sourceGiven: act);
    if (b == null) return;
    err = await store.setPhoto(itemId, b);
  }
  if (err != null && context.mounted) _say(context, err);
}

/// 表單裡的小相片格：未存檔前先放著的相片。點一下選相片，再點可以換。
class PhotoSlot extends StatelessWidget {
  const PhotoSlot({super.key, required this.bytes, required this.onPicked, this.size = 56, this.label});
  final Uint8List? bytes;
  final ValueChanged<Uint8List> onPicked;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: cAccentTint,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final b = await pickPhoto(context);
              if (b != null) onPicked(b);
            },
            child: SizedBox(
              width: size,
              height: size,
              child: bytes == null
                  ? const Icon(Icons.add_a_photo_outlined, size: 20)
                  : Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
        ),
        if (label != null)
          SizedBox(
            width: size + 8,
            child: Text(label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: cSub)),
          ),
      ]);
}

/// 周邊詳情頁最上面的相片格：有相片顯示相片，沒有就顯示「加相片」。點一下可換或移除。
class PhotoBox extends StatelessWidget {
  const PhotoBox(this.itemId, {super.key});
  final String itemId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final p = store.photos[itemId];
          return Material(
            color: p == null ? cAccentTint : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: cLine),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => pickItemPhoto(context, itemId),
              child: p == null
                  ? const SizedBox(
                      height: 84,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo_outlined),
                        SizedBox(width: 8),
                        Text('加相片',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: cAccent)),
                      ]),
                    )
                  : SizedBox(
                      height: 240,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.memory(p, fit: BoxFit.contain, gaplessPlayback: true),
                        const Positioned(
                          right: 10,
                          bottom: 8,
                          child: Text('點一下換相片',
                              style: TextStyle(fontSize: 12, color: cSub)),
                        ),
                      ]),
                    ),
            ),
          );
        },
      );
}
