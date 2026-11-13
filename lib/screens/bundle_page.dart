import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models2.dart';
import '../ui.dart';
import 'item_form.dart' show today;
import 'plan_page.dart';
import 'sale_page.dart';

/// 盤出：勾選一堆周邊，合成一個盤（之後才賣、可以取消），或者已經賣出就直接成交。
/// 給了 [planId] 就是把勾選的加進那個已有的盤。
class BundlePage extends StatefulWidget {
  const BundlePage({super.key, this.planId});
  final String? planId;
  @override
  State<BundlePage> createState() => _BundlePageState();
}

class _BundlePageState extends State<BundlePage> {
  final picked = <String>{};
  String member = '全部';

  Plan? get _target {
    for (final p in store.plans) {
      if (p.id == widget.planId) return p;
    }
    return null;
  }

  void _toggle(String id) => setState(() => picked.contains(id) ? picked.remove(id) : picked.add(id));

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final avail = store.items
        .where((i) => i.status != '已售出' && (member == '全部' || i.member == member))
        .toList()
      ..sort((a, b) {
        final r = store.memberRank(a.member).compareTo(store.memberRank(b.member));
        return r != 0 ? r : b.createdAt.compareTo(a.createdAt);
      });
    final chosen = store.items.where((i) => picked.contains(i.id)).toList();
    final cost = chosen.fold<int>(0, (a, i) => a + (i.costCents ?? 0));
    final unknown = chosen.where((i) => i.costCents == null).length;
    return Scaffold(
      appBar: AppBar(title: Text(target == null ? '盤出：選周邊' : '加進「${target.name}」')),
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
                      () {
                        // 已經在別的盤裡的不能再選，免得一件放進兩個盤。
                        final inPlan = store.planOf(i.id);
                        final locked = inPlan != null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Card2(
                            padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
                            onTap: locked ? null : () => _toggle(i.id),
                            child: Row(children: [
                              Checkbox(
                                value: locked || picked.contains(i.id),
                                onChanged: locked ? null : (_) => _toggle(i.id),
                              ),
                              ItemThumb(i.member, i.category,
                                  size: 44, photo: store.photos[i.id]),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(store.titleOf(i),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: locked ? cSub : cInk)),
                                      Text(
                                          locked
                                              ? '已在「${inPlan.name}」'
                                              : '${i.member} · ${i.category}',
                                          style: const TextStyle(fontSize: 12, color: cSub)),
                                    ]),
                              ),
                              costLabel(i),
                            ]),
                          ),
                        );
                      }(),
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
            if (target != null)
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: chosen.isEmpty
                    ? null
                    : () {
                        target.itemIds.addAll([for (final i in chosen) i.id]);
                        store.savePlan(target);
                        Navigator.pop(context);
                      },
                child: Text('加進這個盤（${chosen.length} 件）'),
              )
            else ...[
              // 主要做法：先合成盤，之後才賣；可以取消，也可以之後收定金。
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
                child: Text(chosen.isEmpty ? '勾選要放進盤的周邊' : '合成盤（${chosen.length} 件）'),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: chosen.isEmpty
                    ? null
                    : () async {
                        final done = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SalePage([for (final i in chosen) i.id])),
                        );
                        if (done == true && context.mounted) Navigator.pop(context);
                      },
                child: const Text('已經賣出了：直接成交'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
