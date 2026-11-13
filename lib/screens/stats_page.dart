import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../ui.dart';

/// 統計：件數、待售總值、利潤、成員和平台分佈、郵包、拼團。
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String range = '今年至今';
  String metric = '件數';

  bool _in(String date) {
    final now = DateTime.now();
    return switch (range) {
      '本月' => date.startsWith('${now.year}-${now.month.toString().padLeft(2, '0')}'),
      '今年至今' => date.startsWith('${now.year}'),
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.items;
          final stock = items.where((i) => i.status != '已售出').toList();
          final stockValue = stock.fold<int>(0, (a, i) => a + (i.costCents ?? 0));
          final sales = store.sales.where((s) => _in(s.date)).toList();
          final saleIds = {for (final s in sales) s.id};
          final sold = items.where((i) => saleIds.contains(i.saleId)).toList();
          // 成本不明的當成本 0，整筆實收都算利潤。
          final profit =
              sold.fold<int>(0, (a, i) => a + i.soldCents! - (i.costCents ?? 0));
          final unknownSold = sold.where((i) => i.costCents == null).toList();
          final unknownAll = items.where((i) => i.costCents == null).length;
          final fee = sales.where((s) => s.feeByMe).fold<int>(0, (a, s) => a + s.feeHkd);
          final postSales = sales.fold<int>(0, (a, s) => a + s.postNet);
          final groups = store.groups.where((g) => g.owner).toList();
          final gMargin = groups.fold<int>(0, (a, g) => a + g.margin);
          final gPost = groups.fold<int>(0, (a, g) => a + g.postNet);

          // 每位成員
          final rows = <(String, int)>[];
          for (final m in store.members) {
            final mine = items.where((i) => i.member == m);
            final v = switch (metric) {
              '件數' => mine.length,
              '成本' => mine.fold<int>(0, (a, i) => a + (i.costCents ?? 0)),
              _ => mine
                  .where((i) => i.soldCents != null)
                  .fold<int>(0, (a, i) => a + i.soldCents! - (i.costCents ?? 0)),
            };
            rows.add((m, v));
          }
          final maxV = rows.fold<int>(1, (a, r) => r.$2.abs() > a ? r.$2.abs() : a);

          // 每個平台
          final plats = <String, List<int>>{}; // 件數、收入、利潤
          for (final s in sales) {
            final p = plats.putIfAbsent(s.platform, () => [0, 0, 0]);
            final its = items.where((i) => i.saleId == s.id);
            p[0] += its.length;
            p[1] += s.receivedHkd;
            p[2] += its.fold<int>(0, (a, i) => a + i.soldCents! - (i.costCents ?? 0));
          }
          // 類別
          final cats = <String, int>{};
          for (final i in items) {
            cats[i.category] = (cats[i.category] ?? 0) + 1;
          }
          String signed(int c) => '${c >= 0 ? '+' : '−'}HK\$ ${fmt(c.abs())}';

          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
            Row(children: [
              const Expanded(
                child: Text('統計', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              SizedBox(
                width: 110,
                child: PickField(
                  value: range,
                  plain: true,
                  options: const ['本月', '今年至今', '全部'],
                  onChanged: (v) => setState(() => range = v),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _tile('總件數', '${items.length}', sub: '未出 ${stock.length}'),
              const SizedBox(width: 8),
              _tile('未出總值（按成本）', 'HK\$ ${fmt(stockValue)}'),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _tile('出卡利潤', signed(profit), sub: '已出 ${sold.length} 件', good: profit >= 0),
              const SizedBox(width: 8),
              _tile('郵包（郵費差價 − 包材）', signed(postSales + gPost), sub: '和出卡分開算'),
            ]),
            if (unknownAll > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cWarn),
                ),
                child: Text(
                  '$unknownAll 件成本不明，利潤當成本 0 來算。'
                  '${unknownSold.isEmpty ? '' : '其中 ${unknownSold.length} 件已賣出，實收 HK\$ ${fmt(unknownSold.fold<int>(0, (a, i) => a + i.soldCents!))} 全數算進利潤。'}'
                  '可在庫存用「成本不明」篩選來補。',
                  style: const TextStyle(fontSize: 13, color: cWarn),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card2(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(
                    child: Text('每位成員',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '件數', label: Text('件數')),
                      ButtonSegment(value: '成本', label: Text('成本')),
                      ButtonSegment(value: '利潤', label: Text('利潤')),
                    ],
                    selected: {metric},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => metric = v.first),
                  ),
                ]),
                const SizedBox(height: 8),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      SizedBox(
                          width: 72, child: Text(r.$1, style: const TextStyle(fontSize: 13))),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (r.$2.abs() / maxV).clamp(0.0, 1.0).toDouble(),
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: r.$2 >= 0 ? cAccent : cWarn,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          metric == '件數' ? '${r.$2}' : fmt(r.$2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Card2(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('平台表現',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (plats.isEmpty)
                  const Text('這段時間沒有成交。', style: TextStyle(fontSize: 13, color: cSub))
                else ...[
                  _row('平台', '件數', '收入', '利潤', head: true),
                  for (final e in plats.entries)
                    _row(e.key, '${e.value[0]}', fmt(e.value[1]), fmt(e.value[2])),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            Card2(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('其他', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '類別：${cats.isEmpty ? '—' : cats.entries.map((e) => '${e.key} ${e.value}').join('、')}\n'
                  '自己付的手續費：HK\$ ${fmt(fee)}\n'
                  '拼團車位差價合計：${signed(gMargin)}（${groups.length} 台車，不分時間）',
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ]),
            ),
          ]);
        },
      );

  Widget _tile(String label, String value, {String? sub, bool? good}) => Expanded(
        child: Card2(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: cSub)),
            FittedBox(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: good == null ? cInk : (good ? cGood : cWarn))),
            ),
            if (sub != null) Text(sub, style: const TextStyle(fontSize: 11, color: cSub)),
          ]),
        ),
      );

  Widget _row(String a, String b, String c, String d, {bool head = false}) {
    final st = TextStyle(
        fontSize: head ? 11 : 13,
        fontWeight: head ? FontWeight.w700 : FontWeight.w400,
        color: head ? cSub : cInk);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(a, style: st)),
        SizedBox(width: 44, child: Text(b, textAlign: TextAlign.right, style: st)),
        SizedBox(width: 80, child: Text(c, textAlign: TextAlign.right, style: st)),
        SizedBox(width: 80, child: Text(d, textAlign: TextAlign.right, style: st)),
      ]),
    );
  }
}
