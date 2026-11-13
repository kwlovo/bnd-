import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../models2.dart';
import '../ui.dart';
import 'item_form.dart' show today;
import 'pack_picker.dart';

/// 郵費輸入：交收方式、收郵費、實付郵費，連常用金額的快捷按鈕。
class PostageFields extends StatefulWidget {
  const PostageFields({
    super.key,
    required this.ship,
    required this.postIn,
    required this.postOut,
    required this.onShip,
    required this.onChanged,
    this.inLabel = '收買家郵費（HK\$，包郵就留空）',
    this.quick = true,
    this.unit = 'HK\$',
  });

  /// 是否顯示常用金額的快捷按鈕；閒魚、小紅書的郵費不一樣，自己填。
  final bool quick;
  final String unit;
  final String ship;
  final TextEditingController postIn;
  final TextEditingController postOut;
  final ValueChanged<String> onShip;
  final VoidCallback onChanged;
  final String inLabel;

  /// 換交收方式時的預設郵費：順豐到付、面交免郵費。
  static void defaults(String ship, TextEditingController i, TextEditingController o) {
    if (ship == '順豐' || ship == '面交') {
      i.text = '';
      o.text = '';
    } else if (ship == '易寄取') {
      i.text = '10';
      o.text = '10';
    } else {
      i.text = '4';
      o.text = '2.4';
    }
  }

  @override
  State<PostageFields> createState() => _PostageFieldsState();
}

class _PostageFieldsState extends State<PostageFields> {
  /// 順豐預設到付；選了「自己填」才顯示郵費欄。
  late bool sfOwn = widget.postIn.text.isNotEmpty || widget.postOut.text.isNotEmpty;

  @override
  void didUpdateWidget(PostageFields old) {
    super.didUpdateWidget(old);
    if (old.ship != widget.ship) {
      sfOwn = widget.postIn.text.isNotEmpty || widget.postOut.text.isNotEmpty;
    }
  }

  Widget _quick(TextEditingController c, List<String> values, {bool free = false}) =>
      Wrap(spacing: 6, children: [
        for (final v in values)
          ActionChip(
            label: Text('\$$v'),
            onPressed: () {
              c.text = v;
              widget.onChanged();
            },
          ),
        if (free)
          ActionChip(
            label: const Text('包郵'),
            onPressed: () {
              c.text = '';
              widget.onChanged();
            },
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    const num = TextInputType.numberWithOptions(decimal: true);
    final ship = widget.ship;
    final sf = ship == '順豐';
    // 常用金額只適用於平郵和易寄取；順豐和面交沒有固定金額。
    final quick = widget.quick && (ship == '平郵' || ship == '易寄取');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const FieldLabel('交收'),
      Wrap(spacing: 6, children: [
        for (final m in kShipMethods)
          ChoiceChip(
            label: Text(m),
            selected: ship == m,
            showCheckmark: false,
            onSelected: (_) => widget.onShip(m),
          ),
      ]),
      if (sf) ...[
        const FieldLabel('順豐運費'),
        Wrap(spacing: 6, children: [
          ChoiceChip(
            label: const Text('到付'),
            selected: !sfOwn,
            showCheckmark: false,
            onSelected: (_) {
              widget.postIn.text = '';
              widget.postOut.text = '';
              setState(() => sfOwn = false);
              widget.onChanged();
            },
          ),
          ChoiceChip(
            label: const Text('自己填'),
            selected: sfOwn,
            showCheckmark: false,
            onSelected: (_) => setState(() => sfOwn = true),
          ),
        ]),
        if (!sfOwn)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('買家收件時自己付運費，你不用收也不用付。',
                style: TextStyle(fontSize: 12, color: cSub)),
          ),
      ],
      if (!sf || sfOwn) ...[
        FieldLabel(widget.inLabel),
        TextField(
            controller: widget.postIn, keyboardType: num, onChanged: (_) => widget.onChanged()),
        // 易寄取只有 $10 和 $13 兩種郵費。
        if (quick)
          _quick(widget.postIn, ship == '易寄取' ? const ['10', '13'] : const ['4', '5', '8.5'],
              free: true),
        FieldLabel('實付郵費（${widget.unit}）'),
        TextField(
            controller: widget.postOut, keyboardType: num, onChanged: (_) => widget.onChanged()),
        if (quick)
          _quick(widget.postOut,
              ship == '易寄取' ? const ['10', '13'] : const ['2.4', '4.3', '8.5']),
      ],
    ]);
  }
}
/// 記錄成交：一件是單賣，多件就是盤出（一個價，收入分回每件）。
class SalePage extends StatefulWidget {
  const SalePage(this.itemIds,
      {super.key, this.priceCents, this.buyerName, this.currencyCode});

  /// 盤價的幣別；人民幣的盤會先選好閒魚（收人民幣）。
  final String? currencyCode;
  final List<String> itemIds;

  /// 從已存的盤過來時，先填好盤價（HKD 分）和買家。
  final int? priceCents;
  final String? buyerName;
  @override
  State<SalePage> createState() => _SalePageState();
}

class _SalePageState extends State<SalePage> {
  late final List<Item> list = [
    for (final id in widget.itemIds) store.items.firstWhere((i) => i.id == id),
  ];
  final price = TextEditingController();
  final fee = TextEditingController();
  final buyer = TextEditingController();
  final date = TextEditingController(text: today());
  final postIn = TextEditingController(text: '4');
  final postOut = TextEditingController(text: '2.4');
  final uses = <PackUse>[];
  String platform = kPlatforms.first;
  String currency = 'HKD';
  bool feeByMe = false;

  /// 盤出收入怎樣分：'cost' 按成本比例、'even' 平均分、'manual' 自己填。
  String alloc = 'cost';
  final fixedCtl = <String, TextEditingController>{};
  String ship = '平郵';

  double get rate => store.rates[currency] ?? 1;
  bool get bundle => list.length > 1;

  /// 閒魚、小紅書收人民幣，郵費也用人民幣自己填。
  bool get cn => platform == '閒魚' || platform == '小紅書';

  @override
  void initState() {
    super.initState();
    if ((widget.priceCents ?? 0) > 0) price.text = fmt(widget.priceCents!);
    if (widget.buyerName != null) buyer.text = widget.buyerName!;
    if (widget.currencyCode == 'RMB') platform = '閒魚';
    _setPlatform(platform);
  }

  void _setPlatform(String p) {
    platform = p;
    if (cn) {
      currency = 'RMB';
      postIn.text = '';
      postOut.text = '';
    } else {
      currency = 'HKD';
      PostageFields.defaults(ship, postIn, postOut);
    }
  }

  /// 郵費輸入的是成交幣別，存檔時換算成 HKD。
  int _post(TextEditingController c) {
    final v = parseCents(c.text) ?? 0;
    return cn ? toHkd(v, rate) : v;
  }

  List<int?> _fixed() => [
        for (final i in list)
          () {
            final v = parseCents(fixedCtl[i.id]?.text ?? '');
            return v == null ? null : toHkd(v, rate);
          }(),
      ];

  Sale _build() => Sale(
        id: store.newId(),
        itemIds: [for (final i in list) i.id],
        date: date.text.trim(),
        platform: platform,
        priceMinor: parseCents(price.text) ?? 0,
        currency: currency,
        rate: rate,
        feeMinor: parseCents(fee.text) ?? 0,
        feeByMe: feeByMe,
        buyer: buyer.text.trim(),
        ship: ship,
        postIn: _post(postIn),
        postOut: _post(postOut),
        pack: store.packCostOf(uses),
        even: alloc == 'even',
        fixed: bundle && alloc == 'manual' ? _fixed() : null,
        uses: [for (final u in uses) u.toJson()],
      );

  @override
  Widget build(BuildContext context) {
    final s = _build();
    final unknown = list.where((i) => i.costCents == null).length;
    final cost = list.fold<int>(0, (a, i) => a + (i.costCents ?? 0));
    // 成本不明的當成本 0 來算利潤。
    final int? profit = s.receivedHkd - cost;
    const num = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(title: Text(bundle ? '盤出 ${list.length} 件' : '記錄成交')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        Card2(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(
                    child: Text(store.titleOf(i),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  Text(
                    i.costCents == null
                        ? '成本不明'
                        : '成本 ${i.costKind == CostKind.approx ? '≈ ' : ''}HK\$ ${fmt(i.costCents!)}',
                    style: const TextStyle(fontSize: 12, color: cSub),
                  ),
                  if (bundle && alloc == 'manual') ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 88,
                      child: TextField(
                        controller: fixedCtl.putIfAbsent(i.id, TextEditingController.new),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(hintText: '收入 $currency'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ]),
              ),
          ]),
        ),
        const FieldLabel('成交平台'),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final p in kPlatforms)
            ChoiceChip(
              label: Text(p),
              selected: platform == p,
              showCheckmark: false,
              onSelected: (_) => setState(() => _setPlatform(p)),
            ),
        ]),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FieldLabel(bundle ? '盤價（整盤一個價）' : '成交價'),
              TextField(
                controller: price,
                keyboardType: num,
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: PickField(
              value: currency,
              options: store.rates.keys.toList(),
              onChanged: (v) => setState(() => currency = v),
            ),
          ),
        ]),
        if (currency != 'HKD')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('匯率 $rate → HK\$ ${fmt(s.priceHkd)}',
                style: const TextStyle(fontSize: 12, color: cSub)),
          ),
        if (bundle) ...[
          const FieldLabel('收入怎樣分回每一件'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cost', label: Text('按成本比例')),
              ButtonSegment(value: 'even', label: Text('平均分')),
              ButtonSegment(value: 'manual', label: Text('自己填')),
            ],
            selected: {alloc},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => alloc = v.first),
          ),
          if (alloc == 'manual')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                () {
                  final f = _fixed();
                  final diff = s.receivedHkd - f.fold<int>(0, (a, b) => a + (b ?? 0));
                  final blanks = f.where((x) => x == null).length;
                  if (blanks > 0) {
                    return '在上面每件旁邊填收入（$currency）。沒填的 $blanks 件會平分剩下的 HK\$ ${fmt(diff)}。';
                  }
                  return diff == 0 ? '每件收入合計等於盤價。' : '每件收入合計和盤價相差 HK\$ ${fmt(diff)}，請調整。';
                }(),
                style: const TextStyle(fontSize: 12, color: cSub),
              ),
            ),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FieldLabel('手續費（$currency，沒有就留空）'),
              TextField(
                controller: fee,
                keyboardType: num,
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('買家付')),
              ButtonSegment(value: true, label: Text('我付')),
            ],
            selected: {feeByMe},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => feeByMe = v.first),
          ),
        ]),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('買家'),
              TextField(controller: buyer),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('日期'),
              TextField(controller: date),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Card2(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('郵包（和出卡收支分開算）',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            PostageFields(
              ship: ship,
              postIn: postIn,
              postOut: postOut,
              quick: !cn,
              unit: cn ? 'RMB' : 'HK\$',
              inLabel: cn ? '收買家郵費（RMB，自己填；包郵就留空）' : '收買家郵費（HK\$，包郵就留空）',
              onShip: (v) => setState(() {
                ship = v;
                if (!cn) PostageFields.defaults(v, postIn, postOut);
              }),
              onChanged: () => setState(() {}),
            ),
            const FieldLabel('打包用了什麼'),
            PackPicker(uses: uses, onChanged: () => setState(() {})),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              _sum('收到', 'HK\$ ${fmt(s.receivedHkd)}'),
              _sum('成本',
                  unknown == list.length ? '不明' : 'HK\$ ${fmt(cost)}${unknown > 0 ? '+' : ''}'),
              _sum('出卡利潤', profit == null ? '未知' : '${profit >= 0 ? '+' : ''}${fmt(profit)}',
                  color: profit != null && profit >= 0 ? cGood : null),
              _sum('郵包', '${s.postNet >= 0 ? '+' : ''}${fmt(s.postNet)}'),
            ]),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                if (parseCents(price.text) == null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('請填成交價')));
                  return;
                }
                if (bundle && alloc == 'manual') {
                  final f = _fixed();
                  if (f.every((x) => x != null) &&
                      f.fold<int>(0, (a, b) => a + b!) != s.receivedHkd) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('每件收入合計和盤價不一樣，請調整')));
                    return;
                  }
                }
                store.recordSale(_build());
                Navigator.pop(context, true);
              },
              child: const Text('確認成交'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sum(String label, String value, {Color? color}) => Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 12, color: cSub)),
          Text(value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color ?? cInk)),
        ]),
      );
}
