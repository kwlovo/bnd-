import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'crop_page.dart';
import 'photo.dart';

String today() => DateTime.now().toIso8601String().substring(0, 10);

/// 新買的：一次可選多位成員，每位各建一件，共用同一個入手批次。
class ItemFormPage extends StatefulWidget {
  const ItemFormPage({super.key});
  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final name = TextEditingController(text: '小卡');
  final seriesName = TextEditingController();
  final batchName = TextEditingController();
  final platform = TextEditingController();
  final total = TextEditingController();
  final picked = <String>{};

  /// 每位成員那一件的相片（未儲存前先放著）。
  final photos = <String, Uint8List>{};
  /// 外網切卡：平台只有 Mercari／閃電市場，另補國際運費，並記到貨了沒有。
  bool overseas = false;
  String overseasPlatform = 'Mercari';
  final intl = TextEditingController();
  bool arrived = false;
  bool intlPaid = false;
  String category = '小卡';
  String status = '待售';
  String costMode = '記得';
  String currency = 'HKD';

  int get count => picked.length;

  void _save() {
    if (picked.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請至少選一位成員')));
      return;
    }
    final cents = costMode == '忘記了' ? null : parseCents(total.text);
    if (costMode != '忘記了' && cents == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請填總價，或選「忘記了」')));
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final b = Batch(
      id: store.newId(),
      name: batchName.text.trim().isEmpty
          ? '${today().substring(5).replaceAll('-', '/')} 入手'
          : batchName.text.trim(),
      type: count == 1 ? BatchType.single : BatchType.bundle,
      date: today(),
      platform: overseas ? overseasPlatform : platform.text.trim(),
      totalMinor: cents,
      currency: currency,
      rate: store.rates[currency] ?? 1,
      approx: costMode == '大概',
      overseas: overseas,
      intlShip: overseas ? (parseCents(intl.text) ?? 0) : 0,
      arrived: !overseas || arrived,
      intlPaid: overseas && intlPaid,
    );
    var k = 0;
    // 有填系列名時，卡會歸入該系列，名字顯示為「系列名 + 年紀順序編號」。
    final sn = seriesName.text.trim();
    final s = sn.isEmpty ? null : store.seriesNamed(sn);
    final items = <Item>[];
    for (final m in store.members.where(picked.contains)) {
      final slot = s == null ? -1 : s.members.indexOf(m);
      items.add(Item(
        id: store.newId(),
        name: '$m ${name.text.trim()}'.trim(),
        member: m,
        category: category,
        status: status,
        batchId: b.id,
        seriesId: slot >= 0 ? s!.id : null,
        slot: slot >= 0 ? slot : null,
        source: sn,
        createdAt: now + k++,
      ));
    }
    store.addBatchWithItems(b, items);
    for (final i in items) {
      final p = photos[i.member];
      if (p != null) store.setPhoto(i.id, p);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cents = parseCents(total.text);
    final rate = store.rates[currency] ?? 1;
    String hint;
    if (costMode == '忘記了') {
      hint = '會標為「成本不明」，之後想起來可以補。';
    } else if (cents == null || count == 0) {
      hint = '填總價後，會自動平均分到每一件；之後可在批次裡改成按參考價比例。';
    } else {
      final ship = overseas ? (parseCents(intl.text) ?? 0) : 0;
      final each = allocateEven(toHkd(cents, rate) + ship, count).first;
      hint = '平均分 $count 件，每件成本 ${costMode == '大概' ? '≈ ' : ''}HK\$ ${fmt(each)}。';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('新增周邊')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('一般')),
            ButtonSegment(value: true, label: Text('外網切卡')),
          ],
          selected: {overseas},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => overseas = s.first),
        ),
        if (overseas) ...[
          const FieldLabel('到貨了沒有'),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('未到貨'),
              selected: !arrived,
              showCheckmark: false,
              onSelected: (_) => setState(() => arrived = false),
            ),
            ChoiceChip(
              label: const Text('已到貨'),
              selected: arrived,
              showCheckmark: false,
              onSelected: (_) => setState(() => arrived = true),
            ),
          ]),
          const Text('未到貨的會在庫存標出來，到貨後點進去標為已到貨。',
              style: TextStyle(fontSize: 12, color: cSub)),
        ],
        const FieldLabel('名稱（沒有系列名時用，會自動加上成員名）'),
        TextField(controller: name),
        const FieldLabel('系列名（可不填；填了卡名會是「系列名 1–6」，按成員年紀順序）'),
        TextField(
          controller: seriesName,
          decoration: const InputDecoration(hintText: '例如：19.99 隨機小卡'),
        ),
        const FieldLabel('成員（可多選，每位各建一件）'),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final m in store.members)
            FilterChip(
              label: Text(m),
              selected: picked.contains(m),
              onSelected: (on) =>
                  setState(() => on ? picked.add(m) : picked.remove(m)),
            ),
        ]),
        if (picked.isNotEmpty) ...[
          const FieldLabel('相片（可不加，之後也可以補）'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in store.members.where(picked.contains))
              PhotoSlot(
                bytes: photos[m],
                label: m,
                onPicked: (b) => setState(() => photos[m] = b),
              ),
          ]),
          if (picked.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final who = store.members.where(picked.contains).toList();
                  final cut = await cropMany(context, count: who.length, labels: who);
                  if (cut == null) return;
                  setState(() {
                    for (var k = 0; k < who.length && k < cut.length; k++) {
                      photos[who[k]] = cut[k];
                    }
                  });
                },
                icon: const Icon(Icons.grid_on),
                label: const Text('一張大圖切開，按順序放進去'),
              ),
            ),
        ],
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('類別'),
              PickField(
                value: category,
                options: kCategories,
                onChanged: (v) => setState(() => category = v),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('狀態'),
              PickField(
                value: status,
                options: kStatuses.where((s) => s != '已售出').toList(),
                onChanged: (v) => setState(() => status = v),
              ),
            ]),
          ),
        ]),
        const FieldLabel('這批的名稱（可不填）'),
        TextField(
          controller: batchName,
          decoration: const InputDecoration(hintText: '例如：11/8 小紅書盤收'),
        ),
        if (overseas) ...[
          const FieldLabel('平台'),
          PickField(
            value: overseasPlatform,
            options: const ['Mercari', '閃電市場'],
            onChanged: (v) => setState(() => overseasPlatform = v),
          ),
        ] else ...[
          const FieldLabel('來源平台（可不填）'),
          TextField(controller: platform),
        ],
        FieldLabel(overseas ? '物品價格（不含國際運費）' : '這批總價'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '記得', label: Text('記得')),
            ButtonSegment(value: '大概', label: Text('大概')),
            ButtonSegment(value: '忘記了', label: Text('忘記了')),
          ],
          selected: {costMode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => costMode = s.first),
        ),
        if (costMode != '忘記了') ...[
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 110,
              child: PickField(
                value: currency,
                options: store.rates.keys.toList(),
                onChanged: (v) => setState(() => currency = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: total,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: '總價'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
        ],
        if (overseas) ...[
          const FieldLabel('國際運費（還不知道就留空，之後在批次裡補）'),
          TextField(
            controller: intl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixText: 'HK\$ '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('運費未補'),
              selected: !intlPaid,
              showCheckmark: false,
              onSelected: (_) => setState(() => intlPaid = false),
            ),
            ChoiceChip(
              label: const Text('運費已補'),
              selected: intlPaid,
              showCheckmark: false,
              onSelected: (_) => setState(() => intlPaid = true),
            ),
          ]),
        ],
        const SizedBox(height: 6),
        Text(hint, style: const TextStyle(fontSize: 12, color: cSub)),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(count == 0 ? '儲存' : '儲存 $count 件'),
        ),
      ]),
    );
  }
}
