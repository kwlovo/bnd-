import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'crop_page.dart';
import 'photo.dart';

String today() => DateTime.now().toIso8601String().substring(0, 10);

/// 新增時的一件：哪位成員的第幾件，連自己的價錢、品相和相片。
class _Piece {
  _Piece(this.member, this.n);
  final String member;

  /// 同一位成員的第幾件（0 開始）。
  final int n;
  final price = TextEditingController();
  final condition = TextEditingController();
  Uint8List? photo;

  String get key => '$member#$n';
}

/// 新買的：一次可選多位成員，每位可以有幾件，共用同一個入手批次。
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

  /// 每位成員有幾件（沒有就是 1）。
  final qty = <String, int>{};

  /// 已建立過的每一件，換數量時保留已填的價錢、品相和相片。
  final _pieces = <String, _Piece>{};

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

  /// true：每件分開填價錢（例如娃娃，每隻品相和價錢都不同）；false：總價平均分。
  bool each = false;

  /// 現在要建立的每一件，按成員年紀順序。
  List<_Piece> get pieces => [
        for (final m in store.members.where(picked.contains))
          for (var n = 0; n < (qty[m] ?? 1); n++)
            _pieces.putIfAbsent('$m#$n', () => _Piece(m, n)),
      ];

  int get count => pieces.length;

  void _say(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  void _save() {
    final list = pieces;
    if (list.isEmpty) {
      _say('請至少選一位成員');
      return;
    }
    final forgot = costMode == '忘記了';
    final rate = store.rates[currency] ?? 1;
    int? cents;
    List<int>? eachMinor;
    if (!forgot && each) {
      final ps = [for (final p in list) parseCents(p.price.text)];
      if (ps.any((x) => x == null)) {
        _say('每件都要填價錢；不記得的話選「忘記了」');
        return;
      }
      eachMinor = [for (final x in ps) x!];
      cents = eachMinor.fold<int>(0, (a, x) => a + x);
    } else if (!forgot) {
      cents = parseCents(total.text);
      if (cents == null) {
        _say('請填總價，或選「忘記了」');
        return;
      }
    }
    final ship = overseas ? (parseCents(intl.text) ?? 0) : 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final b = Batch(
      id: store.newId(),
      name: batchName.text.trim().isEmpty
          ? '${today().substring(5).replaceAll('-', '/')} 入手'
          : batchName.text.trim(),
      type: list.length == 1 ? BatchType.single : BatchType.bundle,
      date: today(),
      platform: overseas ? overseasPlatform : platform.text.trim(),
      totalMinor: cents,
      currency: currency,
      rate: rate,
      approx: costMode == '大概',
      method: eachMinor == null ? AllocMethod.even : AllocMethod.manual,
      overseas: overseas,
      intlShip: ship,
      arrived: !overseas || arrived,
      intlPaid: overseas && intlPaid,
    );

    // 逐件填價錢：每件成本 = 自己的價錢（換成 HKD）＋平分的國際運費，
    // 合計和批次總成本剛好對上（四捨五入的差額放在最後一件）。
    List<int>? eachHkd;
    if (eachMinor != null) {
      final shipShare = allocateEven(ship, list.length);
      eachHkd = [
        for (var k = 0; k < list.length; k++) toHkd(eachMinor[k], rate) + shipShare[k],
      ];
      final diff = b.totalHkd! - eachHkd.fold<int>(0, (a, x) => a + x);
      eachHkd[eachHkd.length - 1] += diff;
    }

    // 有填系列名時，每位成員的第一件歸入該系列，名字顯示為「系列名 + 年紀順序編號」。
    final sn = seriesName.text.trim();
    final s = sn.isEmpty ? null : store.seriesNamed(sn);
    final items = <Item>[];
    for (var k = 0; k < list.length; k++) {
      final p = list[k];
      final slot = s == null || p.n > 0 ? -1 : s.members.indexOf(p.member);
      final cond = p.condition.text.trim();
      items.add(Item(
        id: store.newId(),
        name: '${p.member} ${name.text.trim()}'.trim(),
        member: p.member,
        category: category,
        status: status,
        batchId: b.id,
        seriesId: slot >= 0 ? s!.id : null,
        slot: slot >= 0 ? slot : null,
        source: sn,
        note: cond.isEmpty ? '' : '品相：$cond',
        manualCents: eachHkd?[k],
        createdAt: now + k,
      ));
    }
    store.addBatchWithItems(b, items);
    for (var k = 0; k < list.length; k++) {
      final ph = list[k].photo;
      if (ph != null) store.setPhoto(items[k].id, ph);
    }
    Navigator.pop(context);
  }

  Widget _qtyRow(String m) {
    final n = qty[m] ?? 1;
    return Row(children: [
      Expanded(child: Text(m, style: const TextStyle(fontSize: 14))),
      IconButton(
        tooltip: '$m 減少',
        onPressed: n <= 1 ? null : () => setState(() => qty[m] = n - 1),
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(
        width: 28,
        child: Text('$n',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      IconButton(
        tooltip: '$m 增加',
        onPressed: () => setState(() => qty[m] = n + 1),
        icon: const Icon(Icons.add_circle_outline),
      ),
    ]);
  }

  Widget _pieceRow(_Piece p, bool showPrice) {
    final many = (qty[p.member] ?? 1) > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card2(
        padding: const EdgeInsets.all(8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PhotoSlot(
            bytes: p.photo,
            size: 52,
            onPicked: (b) => setState(() => p.photo = b),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(many ? '${p.member} 第 ${p.n + 1} 件' : p.member,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (showPrice) ...[
                const SizedBox(height: 6),
                Row(children: [
                  SizedBox(
                    width: 104,
                    child: TextField(
                      controller: p.price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(hintText: '價錢', prefixText: '$currency '),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: p.condition,
                      decoration: const InputDecoration(hintText: '品相（可不填）'),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = pieces;
    final rate = store.rates[currency] ?? 1;
    final ship = overseas ? (parseCents(intl.text) ?? 0) : 0;
    String hint;
    if (costMode == '忘記了') {
      hint = '會標為「成本不明」，之後想起來可以補。';
    } else if (each) {
      final sum = list.fold<int>(0, (a, p) => a + (parseCents(p.price.text) ?? 0));
      hint = '每件用自己的價錢${ship > 0 ? '，國際運費平均分到每件' : ''}。'
          '合計 $currency ${fmt(sum)}。';
    } else {
      final cents = parseCents(total.text);
      if (cents == null || count == 0) {
        hint = '填總價後，會自動平均分到每一件。每件價錢不同的話，選上面的「每件分開填」。';
      } else {
        final e = allocateEven(toHkd(cents, rate) + ship, count).first;
        hint = '平均分 $count 件，每件成本 ${costMode == '大概' ? '≈ ' : ''}HK\$ ${fmt(e)}。';
      }
    }
    final showPrice = each && costMode != '忘記了';
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
        const FieldLabel('成員（可多選）'),
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
          const FieldLabel('每位幾件（有複數就加）'),
          Card2(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
            child: Column(children: [
              for (final m in store.members.where(picked.contains)) _qtyRow(m),
            ]),
          ),
          FieldLabel(showPrice ? '每一件：相片、價錢、品相' : '相片（可不加，之後也可以補）'),
          for (final p in list) _pieceRow(p, showPrice),
          if (list.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final cut = await cropMany(context, count: list.length, labels: [
                    for (final p in list)
                      (qty[p.member] ?? 1) > 1 ? '${p.member}${p.n + 1}' : p.member,
                  ]);
                  if (cut == null) return;
                  setState(() {
                    for (var k = 0; k < list.length && k < cut.length; k++) {
                      list[k].photo = cut[k];
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
        FieldLabel(overseas ? '物品價格（不含國際運費）' : '價錢'),
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
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('總價平均分')),
              ButtonSegment(value: true, label: Text('每件分開填')),
            ],
            selected: {each},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => each = s.first),
          ),
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
            if (!each)
              Expanded(
                child: TextField(
                  controller: total,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '總價'),
                  onChanged: (_) => setState(() {}),
                ),
              )
            else
              const Expanded(
                child: Text('在上面每一件填自己的價錢',
                    style: TextStyle(fontSize: 13, color: cSub)),
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
