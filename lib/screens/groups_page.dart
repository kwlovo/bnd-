import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../models2.dart';
import '../ui.dart';
import 'buyers_page.dart';
import 'follow_page.dart';
import 'group_flow.dart';
import 'item_form.dart' show today;

/// 拼團列表：我開的車（車主）和我跟的車（車員）。
class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    final leader = TextEditingController();
    final price = TextEditingController();
    var owner = true;
    var platform = kOrderPlatforms.first;
    var category = '小卡';
    final g = await showDialog<Group>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('開車／跟車'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('我是車主')),
                  ButtonSegment(value: false, label: Text('我是車員')),
                ],
                selected: {owner},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setD(() => owner = v.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: '團名')),
              const SizedBox(height: 8),
              if (owner)
                PickField(
                  value: platform,
                  label: '下單平台',
                  options: kOrderPlatforms,
                  onChanged: (v) => platform = v,
                )
              else
                TextField(
                    controller: leader, decoration: const InputDecoration(labelText: '車主帳號')),
              const SizedBox(height: 8),
              if (owner)
                PickField(
                  value: category,
                  label: '物品類別',
                  options: kCategories,
                  onChanged: (v) => category = v,
                )
              else
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '價格', prefixText: 'HK\$ '),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  c,
                  Group(
                    id: store.newId(),
                    name: name.text.trim(),
                    owner: owner,
                    platform: owner ? platform : '',
                    leader: leader.text.trim(),
                    category: category,
                  ),
                );
              },
              child: const Text('建立'),
            ),
          ],
        ),
      ),
    );
    if (g == null) return;
    if (!g.owner) {
      // 跟車只記團名、價格、寄出了沒有，建立後留在清單，不用再進去填。
      g.steps['開團'] = today();
      setFollowPrice(g, parseCents(price.text) ?? 0);
      store.saveGroup(g);
      return;
    }
    store.saveGroup(g);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupFlowPage(g.id)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final mine = store.groups.where((g) => g.owner).toList().reversed.toList();
          final joined = store.groups.where((g) => !g.owner).toList().reversed.toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                const Expanded(
                  child: Text('拼團',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const BuyersPage())),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('車員'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _create(context),
                  icon: const Icon(Icons.add),
                  label: const Text('開車／跟車'),
                ),
              ]),
            ),
            Expanded(
              child: store.groups.isEmpty
                  ? const Center(
                      child: Text('還沒有車。按右上角開始。', style: TextStyle(color: cSub)))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                      // 截團今天、明天或已過還沒下單的，放在最上面提醒。
                      for (final g in mine)
                        if ((g.daysToDeadline(DateTime.now()) ?? 99) <= 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: cWarnTint,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => GroupFlowPage(g.id))),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Text('「${g.name}」${deadlineText(g)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: cWarn)),
                                ),
                              ),
                            ),
                          ),
                      if (mine.isNotEmpty) const _Head('我開的車（我是車主）'),
                      for (final g in mine) _GroupCard(g),
                      if (joined.isNotEmpty) const _Head('我跟的車（我是車員）'),
                      for (final g in joined) _GroupCard(g),
                    ]),
            ),
          ]);
        },
      );
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cSub)),
      );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard(this.g);
  final Group g;

  @override
  Widget build(BuildContext context) {
    final unpaid = g.slots.where((s) => (g.owner ? s.sold : true) && !s.paid).length;
    final free = g.slots.where((s) => !s.taken).length;
    final done = g.nextStep.isEmpty;
    if (!g.owner) {
      // 我跟的車：只顯示團名、價格、寄出了沒有。
      final sent = g.steps['寄出'];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card2(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => FollowPage(g.id))),
          child: Row(children: [
            if (g.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(base64Decode(g.image!),
                    width: 44, height: 44, fit: BoxFit.cover, gaplessPlayback: true),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  '${followPrice(g) == 0 ? '未填價格' : 'HK\$ ${fmt(followPrice(g))}'}'
                  '${followPost(g) == 0 ? '' : ' + 郵費 ${fmt(followPost(g))}'}'
                  '${g.leader.isEmpty ? '' : ' · ${g.leader}'}',
                  style: const TextStyle(fontSize: 13, color: cSub),
                ),
              ]),
            ),
            g.steps.containsKey('到貨')
                ? const Tag('已收到', fg: cGood, bg: cGoodTint)
                : sent == null
                ? const Tag('未寄出', fg: cWarn, bg: cWarnTint)
                : Tag('已寄出 ${sent.substring(5).replaceAll('-', '/')}',
                    fg: cGood, bg: cGoodTint),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card2(
        // 車主的車用按草圖分頁的新畫面；我跟的車用簡單的舊畫面。
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GroupFlowPage(g.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (g.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(base64Decode(g.image!),
                    width: 44, height: 44, fit: BoxFit.cover, gaplessPlayback: true),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(g.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            g.owner
                ? const Tag('車主', fg: Colors.white, bg: cAccent)
                : const Tag('車員', fg: cAccent, bg: Colors.white, dashed: true),
          ]),
          const SizedBox(height: 8),
          StepBar(g),
          const SizedBox(height: 8),
          Text(
            '${done ? '已完成' : '下一步：${g.owner && (g.nextStep == '分好' || g.nextStep == '寄出') ? '打包寄出' : g.nextStep}'} · ${g.slots.length} 位'
            '${g.owner ? ' · 差價 ${fmt(g.margin)}' : ''}',
            style: const TextStyle(fontSize: 13, color: cSub),
          ),
          if (deadlineText(g) case final t?) ...[
            const SizedBox(height: 6),
            Tag(t, fg: cWarn, bg: cWarnTint),
          ],
          if (g.note.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('備註：${g.note.trim()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: cInk)),
          ],
          if (unpaid > 0 || (g.owner && free > 0)) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              if (unpaid > 0) Tag('未付款 $unpaid ${g.owner ? '人' : '位'}', fg: cWarn, bg: cWarnTint),
              if (g.owner && free > 0)
                Tag('剩位 $free', fg: const Color(0xFF1F45B8), bg: cAccentTint),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// 五步進度條。
class StepBar extends StatelessWidget {
  const StepBar(this.g, {super.key});
  final Group g;
  @override
  Widget build(BuildContext context) => Row(children: [
        // 車主的車把打包和寄出合成一步，只有四格。
        for (final (k, s) in kSteps.where((s) => !g.owner || s != '分好').indexed) ...[
          if (k > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: g.steps.containsKey(s) ? cAccent : const Color(0xFFD5DAE3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ]);
}
