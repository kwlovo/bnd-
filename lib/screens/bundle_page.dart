import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models2.dart';
import '../ui.dart';
import 'item_form.dart' show today;
import 'plan_page.dart';
import 'sale_page.dart';

/// 盤出：直接勾選要放進這個盤的周邊，下一步填盤價。
class BundlePage extends StatefulWidget {
  const BundlePage({super.key});
  @override
  State<BundlePage> createState() => _BundlePageState();
}

class _BundlePageState extends State<BundlePage> {
  final picked = <String>{};
  String member = '全部';

  @override
  Widget build(BuildContext context) {
    final avail = store.items
        .where((i) => i.status != '已售出' && (member == '全部' || i.member == member))
        .toList();
    final chosen = store.items.where((i) => picked.contains(i.id)).toList();
    final cost = chosen.fold<int>(0, (a, i) => a + (i.costCents ?? 0));
    final unknown = chosen.where((i) => i.costCents == null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('盤出：選周邊')),
      body: Column(children: [
        ChipRow(
          options: ['全部', ...store.members],
          value: member,
          onChanged: (v) => setState(() => member = v),
        ),
        Expanded(
          child: avail.isEmpty
              ? const Center(child: Text('沒有可以盤出的周邊。', style: TextStyle(color: cSub)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    for (final i in avail)
                      CheckboxListTile(
                        value: picked.contains(i.id),
                        onChanged: (v) => setState(
                            () => v == true ? picked.add(i.id) : picked.remove(i.id)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(store.titleOf(i),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        subtitle: Text('${i.member} · ${i.category}',
                            style: const TextStyle(fontSize: 12)),
                        secondary: costLabel(i),
                      ),
                  ],
                ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '已選 ${chosen.length} 件 · 成本合計 HK\$ ${fmt(cost)}${unknown > 0 ? ' + $unknown 件不明' : ''}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: chosen.length < 2
                  ? null
                  : () async {
                      final done = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SalePage([for (final i in chosen) i.id])),
                      );
                      if (done == true && context.mounted) Navigator.pop(context);
                    },
              child: Text(chosen.length < 2 ? '現在成交要至少選 2 件' : '已經賣出：填盤價成交'),
            ),
            const SizedBox(height: 6),
            // 還沒賣出：先把選好的存成一個盤，之後才成交，也可以先收定金保留。
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: chosen.isEmpty
                  ? null
                  : () {
                      final p = Plan(
                        id: store.newId(),
                        name: '${today().substring(5).replaceAll('-', '/')} 的盤',
                        itemIds: [for (final i in chosen) i.id],
                      );
                      store.savePlan(p);
                      Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => PlanPage(p.id)));
                    },
              child: const Text('還沒賣出：先存起來（可收定金保留）'),
            ),
          ]),
        ),
      ),
    );
  }
}
