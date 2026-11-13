import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models2.dart';
import '../ui.dart';
import 'bundle_page.dart';
import 'item_form.dart' show today;
import 'sale_page.dart';

/// 還沒出的盤的清單。
class PlansPage extends StatelessWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('還沒出的盤')),
          body: store.plans.isEmpty
              ? const Center(
                  child: Text('沒有存起來的盤。', style: TextStyle(color: cSub)))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                  for (final p in store.plans.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card2(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => PlanPage(p.id))),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w700)),
                                  Text(
                                    '${p.itemIds.length} 件'
                                    '${p.price > 0 ? ' · 盤價 ${p.unit} ${fmt(p.price)}' : ' · 未填盤價'}'
                                    '${p.buyer.isEmpty ? '' : ' · ${p.buyer}'}',
                                    style: const TextStyle(fontSize: 13, color: cSub),
                                  ),
                                  // 盤裡有什麼，一眼看到。
                                  Text(
                                    [
                                      for (final id in p.itemIds)
                                        if (store.itemOf(id) case final i?) store.titleOf(i),
                                    ].join('、'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: cInk),
                                  ),
                                ]),
                          ),
                          if (p.depositPaid)
                            Tag('已收定金 ${p.unit} ${fmt(p.deposit)}', fg: cGood, bg: cGoodTint)
                          else if (p.depositPct > 0)
                            Tag('定金未收', fg: cWarn, bg: cWarnTint)
                          else
                            const Tag('待出'),
                        ]),
                      ),
                    ),
                ]),
        ),
      );
}

/// 一個盤：改名字、盤價、買家，記定金，最後成交。
class PlanPage extends StatefulWidget {
  const PlanPage(this.planId, {super.key});
  final String planId;
  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  Plan? get _p {
    for (final x in store.plans) {
      if (x.id == widget.planId) return x;
    }
    return null;
  }

  late final name = TextEditingController(text: _p?.name ?? '');
  late final price =
      TextEditingController(text: (_p?.price ?? 0) == 0 ? '' : fmt(_p!.price));
  late final buyer = TextEditingController(text: _p?.buyer ?? '');
  late final pct = TextEditingController(
      text: (_p?.depositPct ?? 0) == 0 ? '' : _pctText(_p!.depositPct));

  static String _pctText(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  void _save(Plan p) {
    store.savePlan(p);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) return const Scaffold();
    final list = [
      for (final id in p.itemIds)
        if (store.itemOf(id) case final i?) i,
    ];
    final cost = list.fold<int>(0, (a, i) => a + (i.costCents ?? 0));
    final unknown = list.where((i) => i.costCents == null).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('盤'),
        actions: [
          IconButton(
            tooltip: '取消這個盤',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirm(context, '取消這個盤？',
                  '周邊不會刪除，只是不再放在一起，全部回到待售。'
                      '${p.depositPaid ? '已收的定金請自己處理。' : ''}',
                  ok: '取消這個盤')) {
                if (context.mounted) Navigator.pop(context);
                store.deletePlan(p);
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const FieldLabel('盤的名字'),
        TextField(
          controller: name,
          onChanged: (v) {
            if (v.trim().isEmpty) return;
            p.name = v.trim();
            _save(p);
          },
        ),
        FieldLabel('這個盤有 ${list.length} 件'),
        Card2(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(children: [
            for (final i in list)
              Row(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ItemThumb(i.member, i.category, size: 40, photo: store.photos[i.id]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(store.titleOf(i),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                costLabel(i),
                IconButton(
                  tooltip: '從盤裡拿走',
                  onPressed: list.length == 1
                      ? null
                      : () {
                          p.itemIds.remove(i.id);
                          if (i.status == '已預留') i.status = '待售';
                          _save(p);
                        },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ]),
          ]),
        ),
        Row(children: [
          Expanded(
            child: Text(
              '成本合計 HK\$ ${fmt(cost)}${unknown > 0 ? ' + $unknown 件不明' : ''}',
              style: const TextStyle(fontSize: 12, color: cSub),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BundlePage(planId: p.id)));
              setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('加更多'),
          ),
        ]),
        const FieldLabel('盤價'),
        Row(children: [
          SizedBox(
            width: 110,
            child: PickField(
              value: p.currency,
              options: {...store.rates.keys, p.currency}.toList(),
              labels: const {'HKD': '港幣 HKD', 'RMB': '人民幣 RMB'},
              onChanged: (v) {
                p.currency = v;
                _save(p);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                p.price = parseCents(v) ?? 0;
                _save(p);
              },
            ),
          ),
        ]),
        const FieldLabel('買家（可不填）'),
        TextField(
          controller: buyer,
          onChanged: (v) {
            p.buyer = v.trim();
            _save(p);
          },
        ),
        const FieldLabel('定金（買家先付一部分保留）'),
        Row(children: [
          SizedBox(
            width: 96,
            child: TextField(
              controller: pct,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: '%', hintText: '不收'),
              onChanged: (v) {
                final x = double.tryParse(v.trim()) ?? 0;
                p.depositPct = x.clamp(0, 100).toDouble();
                if (p.depositPct == 0) p.depositPaid = false;
                _save(p);
              },
            ),
          ),
          const SizedBox(width: 8),
          for (final q in const ['30', '50'])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: Text('$q%'),
                onPressed: () {
                  pct.text = q;
                  p.depositPct = double.parse(q);
                  _save(p);
                },
              ),
            ),
          ActionChip(
            label: const Text('不收'),
            onPressed: () {
              pct.text = '';
              p
                ..depositPct = 0
                ..depositPaid = false;
              _save(p);
            },
          ),
        ]),
        if (p.depositPct > 0) ...[
          const SizedBox(height: 8),
          Text(
            p.price == 0
                ? '填了盤價就會算出定金。'
                : '定金 ${p.unit} ${fmt(p.deposit)}，尾款 ${p.unit} ${fmt(p.price - p.deposit)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Material(
            color: p.depositPaid ? cGoodTint : cAccent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: p.price == 0
                  ? null
                  : () {
                      p
                        ..depositPaid = !p.depositPaid
                        ..depositDate = p.depositPaid ? today() : '';
                      _save(p);
                    },
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    p.depositPaid
                        ? '已收定金 ${p.unit} ${fmt(p.deposit)} · 已預留（點一下取消）'
                        : '標為已收定金',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.depositPaid ? cGood : Colors.white),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('收了定金，盤裡的周邊會變成「已預留」。定金先不入帳，成交時連尾款一次記。',
                style: TextStyle(fontSize: 12, color: cSub)),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48), backgroundColor: cNavy),
          onPressed: () async {
            final done = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => SalePage([for (final i in list) i.id],
                    priceCents: p.price, buyerName: p.buyer, currencyCode: p.currency),
              ),
            );
            if (done == true && context.mounted) Navigator.pop(context);
          },
          child: Text(p.depositPaid
              ? '賣出了：成交（尾款 ${p.unit} ${fmt(p.balance)}）'
              : '賣出了：成交'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          onPressed: () async {
            if (await confirm(context, '拆開這個盤？',
                '周邊不會刪除，只是不再放在一起，全部回到待售。'
                    '${p.depositPaid ? '已收的定金請自己處理。' : ''}',
                ok: '拆開')) {
              if (context.mounted) Navigator.pop(context);
              store.deletePlan(p);
            }
          },
          child: const Text('不盤了：拆開這個盤'),
        ),
      ]),
    );
  }
}
