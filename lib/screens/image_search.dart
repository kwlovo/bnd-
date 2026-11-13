import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/imaging.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'inventory.dart';
import 'item_edit.dart';
import 'photo.dart';

/// 算過的相片特徵先記住（id → 相片大小和特徵），不用每次重算。
final _sigs = <String, (int, Float32List)>{};

/// 以圖搜尋：拍一張或選一張圖，列出庫存裡相片最像的周邊。
class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key});
  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  Uint8List? query;
  List<(Item, double)>? hits;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    if (store.photos.isEmpty) return;
    final b = await pickPhoto(context);
    if (b == null || !mounted) return;
    setState(() {
      query = b;
      busy = true;
    });
    final out = <(Item, double)>[];
    try {
      final q = await signatureOf(b);
      for (final i in store.items) {
        final p = store.photos[i.id];
        if (p == null) continue;
        var s = _sigs[i.id];
        if (s == null || s.$1 != p.length) {
          s = _sigs[i.id] = (p.length, await signatureOf(p));
        }
        out.add((i, similarity(q, s.$2)));
      }
    } catch (_) {
      // 讀不到的相片略過。
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    if (mounted) {
      setState(() {
        hits = out.take(20).toList();
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = hits;
    return Scaffold(
      appBar: AppBar(title: const Text('用圖片找')),
      body: store.photos.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('庫存裡還沒有任何周邊加了相片，所以沒有東西可以比對。先為周邊加相片。',
                    style: TextStyle(color: cSub)),
              ),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Row(children: [
                if (query != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(query!, width: 72, height: 72, fit: BoxFit.cover),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    query == null
                        ? '拍一張或選一張圖，會列出庫存裡相片最像的周邊。'
                        : '只會比對已加相片的周邊（${store.photos.length} 件），最像的排最前。',
                    style: const TextStyle(fontSize: 13, color: cSub),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : _pick,
                  child: Text(query == null ? '選圖' : '換一張'),
                ),
              ]),
              const SizedBox(height: 12),
              if (busy) const Center(child: CircularProgressIndicator()),
              if (h != null && !busy)
                for (final (i, score) in h) ...[
                  Row(children: [
                    Expanded(
                      child: ItemTile(i,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ItemEditPage(i.id)))),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text('${(score * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: cAccent)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                ],
            ]),
    );
  }
}
