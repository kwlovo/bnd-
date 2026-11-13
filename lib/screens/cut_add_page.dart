import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'crop_page.dart';
import 'item_form.dart' show today;

class _Cut {
  _Cut(this.photo, this.member);
  final Uint8List photo;
  String member;
  final name = TextEditingController();
}

/// 大圖切開入庫：先選一張大圖切成多份，再逐份填名字，一次加進庫存。
Future<void> startCutAdd(BuildContext context) async {
  final cut = await cropMany(context, count: 6);
  if (cut == null || cut.isEmpty || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => CutAddPage(cut)));
}

class CutAddPage extends StatefulWidget {
  const CutAddPage(this.photos, {super.key});
  final List<Uint8List> photos;
  @override
  State<CutAddPage> createState() => _CutAddPageState();
}

class _CutAddPageState extends State<CutAddPage> {
  late final rows = [for (final p in widget.photos) _Cut(p, store.members.first)];
  final total = TextEditingController();
  final seriesName = TextEditingController();
  String category = '小卡';

  void _save() {
    if (rows.isEmpty) return;
    final cents = parseCents(total.text);
    final now = DateTime.now().millisecondsSinceEpoch;
    final b = Batch(
      id: store.newId(),
      name: '${today().substring(5).replaceAll('-', '/')} 入手',
      type: rows.length == 1 ? BatchType.single : BatchType.bundle,
      date: today(),
      totalMinor: cents,
    );
    final sn = seriesName.text.trim();
    final s = sn.isEmpty ? null : store.seriesNamed(sn);
    final items = <Item>[];
    for (var k = 0; k < rows.length; k++) {
      final r = rows[k];
      final typed = r.name.text.trim();
      final slot = s == null ? -1 : s.members.indexOf(r.member);
      items.add(Item(
        id: store.newId(),
        name: typed.isEmpty ? '${r.member} $category' : typed,
        member: r.member,
        category: category,
        batchId: b.id,
        seriesId: slot >= 0 ? s!.id : null,
        slot: slot >= 0 ? slot : null,
        source: sn,
        createdAt: now + k,
      ));
    }
    store.addBatchWithItems(b, items);
    for (var k = 0; k < rows.length; k++) {
      store.setPhoto(items[k].id, rows[k].photo);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cents = parseCents(total.text);
    return Scaffold(
      appBar: AppBar(title: Text('切好 ${rows.length} 份：填名字')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const Text('每一份填名字、選成員。切到空白或不要的，按右邊的 × 拿走。',
            style: TextStyle(fontSize: 13, color: cSub)),
        const SizedBox(height: 8),
        for (var k = 0; k < rows.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card2(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(rows[k].photo,
                      width: 64, height: 84, fit: BoxFit.cover, gaplessPlayback: true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(children: [
                    TextField(
                      controller: rows[k].name,
                      decoration: InputDecoration(hintText: '第 ${k + 1} 份的名字'),
                    ),
                    PickField(
                      value: rows[k].member,
                      plain: true,
                      fontSize: 13,
                      label: '成員',
                      options: store.members,
                      onChanged: (v) => setState(() => rows[k].member = v),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: '不要這一份',
                  onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(k)),
                  icon: const Icon(Icons.close),
                ),
              ]),
            ),
          ),
        const FieldLabel('類別（這批都是同一類）'),
        PickField(
          value: category,
          options: kCategories,
          onChanged: (v) => setState(() => category = v),
        ),
        const FieldLabel('系列名（可不填；填了卡名會是「系列名 1–6」，不用上面的名字）'),
        TextField(controller: seriesName),
        const FieldLabel('這批總價（HK\$，不記得就留空）'),
        TextField(
          controller: total,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text(
          cents == null
              ? '留空會標為「成本不明」，之後可以補。'
              : '平均分 ${rows.length} 件，每件成本 HK\$ ${fmt(allocateEven(cents, rows.length).first)}。',
          style: const TextStyle(fontSize: 12, color: cSub),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('加入 ${rows.length} 件到庫存'),
        ),
      ]),
    );
  }
}
