import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'crop_page.dart';
import 'photo.dart';

class _Row {
  _Row(this.member);
  String member;
  String status = '待售';
  Uint8List? photo;
  final cost = TextEditingController();
}

/// 舊卡快速入庫：不用填價錢，先放進庫存，想起來再補。
class OldCardsPage extends StatefulWidget {
  const OldCardsPage({super.key});
  @override
  State<OldCardsPage> createState() => _OldCardsPageState();
}

class _OldCardsPageState extends State<OldCardsPage> {
  final rows = <_Row>[];
  final total = TextEditingController();
  final seriesName = TextEditingController();
  String category = '小卡';
  String mode = 'unknown'; // unknown | approx | each
  bool inLedger = false;

  @override
  void initState() {
    super.initState();
    rows.add(_Row(store.members.first));
  }

  void _save() {
    if (rows.isEmpty) return;
    int? totalCents;
    if (mode == 'approx') {
      totalCents = parseCents(total.text);
      if (totalCents == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('請填大概總價，或改選其他方式')));
        return;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final b = Batch(
      id: store.newId(),
      name: '舊卡',
      type: BatchType.old,
      date: '',
      totalMinor: totalCents,
      approx: mode == 'approx',
      inLedger: inLedger,
    );
    var k = 0;
    final sn = seriesName.text.trim();
    final s = sn.isEmpty ? null : store.seriesNamed(sn);
    final items = <Item>[];
    for (final r in rows) {
      final slot = s == null ? -1 : s.members.indexOf(r.member);
      items.add(Item(
        id: store.newId(),
        name: '${r.member} $category',
        member: r.member,
        category: category,
        status: r.status,
        batchId: b.id,
        seriesId: slot >= 0 ? s!.id : null,
        slot: slot >= 0 ? slot : null,
        source: sn,
        manualCents: mode == 'each' ? parseCents(r.cost.text) : null,
        createdAt: now + k++,
      ));
    }
    store.addBatchWithItems(b, items);
    for (var n = 0; n < rows.length; n++) {
      final p = rows[n].photo;
      if (p != null) store.setPhoto(items[n].id, p);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cents = parseCents(total.text);
    return Scaffold(
      appBar: AppBar(title: const Text('舊卡快速入庫')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const Text('以前收的卡不用記得價錢，先放進庫存，想起來再補。',
            style: TextStyle(fontSize: 13, color: cSub)),
        const FieldLabel('類別（這批都是同一類）'),
        PickField(
          value: category,
          options: kCategories,
          onChanged: (v) => setState(() => category = v),
        ),
        const FieldLabel('系列名（可不填；填了卡名會是「系列名 1–6」）'),
        TextField(
          controller: seriesName,
          decoration: const InputDecoration(hintText: '例如：19.99 隨機小卡'),
        ),
        const FieldLabel('這批的成本'),
        Card2(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: RadioGroup<String>(
            groupValue: mode,
            onChanged: (v) => setState(() => mode = v!),
            child: Column(children: [
              const RadioListTile(value: 'unknown', title: Text('全部忘記了，標為「成本不明」')),
              const RadioListTile(value: 'approx', title: Text('記得大概總價')),
              if (mode == 'approx')
                Padding(
                  padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
                  child: Row(children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: total,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(prefixText: 'HK\$ '),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cents == null || rows.isEmpty
                            ? '平均分到每張'
                            : '每張 ≈ HK\$ ${fmt(allocateEven(cents, rows.length).first)}',
                        style: const TextStyle(fontSize: 13, color: cSub),
                      ),
                    ),
                  ]),
                ),
              const RadioListTile(
                  value: 'each', title: Text('逐張填（記得的填，不記得的留空）')),
            ]),
          ),
        ),
        CheckboxListTile(
          value: !inLedger,
          onChanged: (v) => setState(() => inLedger = !(v ?? true)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('不記入記帳（舊卡不影響本月收支）'),
        ),
        for (var k = 0; k < rows.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card2(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                SizedBox(width: 24, child: Text('${k + 1}', textAlign: TextAlign.center)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: PhotoSlot(
                    bytes: rows[k].photo,
                    size: 44,
                    onPicked: (b) => setState(() => rows[k].photo = b),
                  ),
                ),
                Expanded(
                  child: PickField(
                    value: rows[k].member,
                    plain: true,
                    options: {...store.members, rows[k].member}.toList(),
                    onChanged: (v) => setState(() => rows[k].member = v),
                  ),
                ),
                if (mode == 'each')
                  SizedBox(
                    width: 76,
                    child: TextField(
                      controller: rows[k].cost,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'HK\$'),
                    ),
                  ),
                IconButton(
                  tooltip: '移除這張',
                  onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(k)),
                  icon: const Icon(Icons.close),
                ),
              ]),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => rows.add(_Row(rows.last.member))),
          icon: const Icon(Icons.add),
          label: const Text('加一張'),
        ),
        if (rows.length > 1)
          TextButton.icon(
            onPressed: () async {
              final cut = await cropMany(context,
                  count: rows.length, labels: [for (final r in rows) r.member]);
              if (cut == null) return;
              setState(() {
                for (var n = 0; n < rows.length && n < cut.length; n++) {
                  rows[n].photo = cut[n];
                }
              });
            },
            icon: const Icon(Icons.grid_on),
            label: const Text('一張大圖切開，按順序放進去'),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('加入 ${rows.length} 張到庫存'),
        ),
      ]),
    );
  }
}
