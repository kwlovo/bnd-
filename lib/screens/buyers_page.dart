import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models2.dart';
import '../ui.dart';
import 'group_flow.dart';

/// 同一個車員的判斷：不分大小寫、不理前面的 @ 和空格。
String buyerKey(String name) =>
    name.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '').trim();

/// 一個車員在某台車的一個位。
typedef BuyerSlot = (Group, Slot);

/// 我開的車裡，每個車員上了哪些位（一人可能上幾台車）。
Map<String, List<BuyerSlot>> buyersAcrossGroups() {
  final out = <String, List<BuyerSlot>>{};
  for (final g in store.groups.where((g) => g.owner)) {
    for (final s in g.slots.where((s) => s.sold)) {
      out.putIfAbsent(buyerKey(s.buyer), () => []).add((g, s));
    }
  }
  return out;
}

/// 這個車員上了幾台不同的車。
int carsOf(String buyer) {
  final list = buyersAcrossGroups()[buyerKey(buyer)] ?? const [];
  return {for (final (g, _) in list) g.id}.length;
}

/// 車員總覽：每個車員上了哪些車、付了沒有、寄了沒有。上多於一台車的排最前。
class BuyersPage extends StatefulWidget {
  const BuyersPage({super.key});
  @override
  State<BuyersPage> createState() => _BuyersPageState();
}

class _BuyersPageState extends State<BuyersPage> {
  String q = '';
  bool onlyMulti = true;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final all = buyersAcrossGroups().entries.toList();
          int cars(MapEntry<String, List<BuyerSlot>> e) =>
              {for (final (g, _) in e.value) g.id}.length;
          // 還有東西沒寄出的才需要記住；全部寄了的排最後。
          bool open(MapEntry<String, List<BuyerSlot>> e) => e.value.any((x) => !x.$2.sent);
          final multiN = all.where((e) => cars(e) > 1 && open(e)).length;
          final shown = all
              .where((e) => !onlyMulti || cars(e) > 1)
              .where((e) => q.isEmpty || e.key.contains(buyerKey(q)))
              .toList()
            ..sort((a, b) {
              final o = (open(b) ? 1 : 0).compareTo(open(a) ? 1 : 0);
              if (o != 0) return o;
              final c = cars(b).compareTo(cars(a));
              return c != 0 ? c : a.key.compareTo(b.key);
            });
          return Scaffold(
            appBar: AppBar(title: const Text('車員總覽')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Text(
                multiN == 0
                    ? '現在沒有車員同時上多於一台車（還沒寄完的）。'
                    : '有 $multiN 個車員同時上了多於一台車，寄的時候可以一起寄。',
                style: const TextStyle(fontSize: 13, color: cSub),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                    hintText: '搜尋車員帳號', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => q = v.trim()),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('上多於一台車')),
                  ButtonSegment(value: false, label: Text('全部車員')),
                ],
                selected: {onlyMulti},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => onlyMulti = s.first),
              ),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('沒有符合的車員。', style: TextStyle(color: cSub)),
                ),
              for (final e in shown) ...[
                _BuyerCard(e.value, cars: cars(e)),
                const SizedBox(height: 8),
              ],
            ]),
          );
        },
      );
}

class _BuyerCard extends StatelessWidget {
  const _BuyerCard(this.slots, {required this.cars});
  final List<BuyerSlot> slots;
  final int cars;

  @override
  Widget build(BuildContext context) {
    final first = slots.first.$2;
    final unpaid = slots.where((x) => !x.$2.paid).fold<int>(0, (a, x) => a + x.$2.price);
    final notSent = slots.where((x) => !x.$2.sent).length;
    return Card2(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(first.buyer,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          if (cars > 1) Tag('上了 $cars 台車', fg: Colors.white, bg: cNavy),
        ]),
        Text(
          [
            first.source,
            '${slots.length} 個位',
            if (unpaid > 0) '未付 HK\$ ${fmt(unpaid)}',
            notSent == 0 ? '全部已寄' : '$notSent 個未寄',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: unpaid > 0 ? cWarn : cSub),
        ),
        const SizedBox(height: 6),
        for (final (g, s) in slots)
          InkWell(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => GroupFlowPage(g.id))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  child: Text('${g.name} · ${s.member}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                ),
                Text('\$${fmt(s.price)}', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                s.paid
                    ? const Tag('已付', fg: cGood, bg: cGoodTint)
                    : const Tag('未付', fg: cWarn, bg: cWarnTint),
                const SizedBox(width: 4),
                s.sent
                    ? const Tag('已寄', fg: cGood, bg: cGoodTint)
                    : Tag(g.steps.containsKey('到貨') ? '未寄' : g.nextStep),
              ]),
            ),
          ),
      ]),
    );
  }
}
