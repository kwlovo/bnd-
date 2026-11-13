import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../models2.dart';
import '../ui.dart';
import 'item_form.dart' show today;
import 'photo.dart';

/// 我跟的車：只記跟過什麼團、付了多少、寄出了沒有。
class FollowPage extends StatefulWidget {
  const FollowPage(this.groupId, {super.key});
  final String groupId;
  @override
  State<FollowPage> createState() => _FollowPageState();
}

/// 跟車付的價錢（HKD 分）。
int followPrice(Group g) => g.slots.fold(0, (a, s) => a + s.price);

/// 跟車時我付給車主的郵費（HKD 分）。
int followPost(Group g) => g.slots.isEmpty ? 0 : g.slots.first.postOut;

/// 設定跟車的價錢：只留一個位，當作已付，記帳會記一筆支出。
void setFollowPrice(Group g, int cents) {
  final date = g.steps['開團'] ?? today();
  if (g.slots.isEmpty) {
    g.slots.add(
        Slot(id: store.newId(), member: store.members.first, price: cents, buyer: '我'));
  } else {
    g.slots.removeRange(1, g.slots.length);
    g.slots.first.price = cents;
  }
  g.slots.first
    ..paid = cents > 0
    ..paidDate = date;
}

class _FollowPageState extends State<FollowPage> {
  Group get g => store.groupOf(widget.groupId)!;
  late final name = TextEditingController(text: g.name);
  late final leader = TextEditingController(text: g.leader);
  late final price =
      TextEditingController(text: followPrice(g) == 0 ? '' : fmt(followPrice(g)));

  late final post =
      TextEditingController(text: followPost(g) == 0 ? '' : fmt(followPost(g)));

  void _save() {
    store.saveGroup(g);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (store.groupOf(widget.groupId) == null) return const Scaffold();
    final sent = g.steps['寄出'];
    final got = g.steps['到貨'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('我跟的車'),
        actions: [
          IconButton(
            tooltip: '刪除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirm(context, '刪除這台車？', '「${g.name}」的紀錄會被刪除，不能復原。',
                  ok: '刪除')) {
                final x = g;
                if (context.mounted) Navigator.pop(context);
                store.deleteGroup(x);
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Material(
          color: g.image == null ? cAccentTint : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: cLine),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final b = await pickPhoto(context);
              if (b == null) return;
              g.image = base64Encode(b);
              _save();
            },
            child: g.image == null
                ? const SizedBox(
                    height: 72,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_outlined),
                      SizedBox(width: 8),
                      Text('加圖片（可不加）',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: cAccent)),
                    ]),
                  )
                : SizedBox(
                    height: 200,
                    child: Image.memory(base64Decode(g.image!),
                        fit: BoxFit.contain, gaplessPlayback: true),
                  ),
          ),
        ),
        const FieldLabel('團名'),
        TextField(
          controller: name,
          onChanged: (v) {
            if (v.trim().isEmpty) return;
            g.name = v.trim();
            _save();
          },
        ),
        const FieldLabel('車主（可不填）'),
        TextField(
          controller: leader,
          onChanged: (v) {
            g.leader = v.trim();
            _save();
          },
        ),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('成員'),
              PickField(
                value: g.slots.isEmpty || g.slots.first.member.isEmpty
                    ? store.members.first
                    : g.slots.first.member,
                options: store.members,
                onChanged: (v) {
                  if (g.slots.isEmpty) setFollowPrice(g, 0);
                  g.slots.first.member = v;
                  final i = store.itemOf(g.slots.first.itemId);
                  if (i != null) i.member = v;
                  _save();
                },
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('類別'),
              PickField(
                value: g.category,
                options: {...kCategories, g.category}.toList(),
                onChanged: (v) {
                  g.category = v;
                  final i = store.itemOf(g.slots.isEmpty ? null : g.slots.first.itemId);
                  if (i != null) i.category = v;
                  _save();
                },
              ),
            ]),
          ),
        ]),
        const FieldLabel('價格'),
        TextField(
          controller: price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'HK\$ '),
          onChanged: (v) {
            setFollowPrice(g, parseCents(v) ?? 0);
            _save();
          },
        ),
        const FieldLabel('我付了的郵費（還沒付就留空）'),
        TextField(
          controller: post,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'HK\$ '),
          onChanged: (v) {
            if (g.slots.isEmpty) setFollowPrice(g, 0);
            g.slots.first.postOut = parseCents(v) ?? 0;
            _save();
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('合共 HK\$ ${fmt(followPrice(g) + followPost(g))}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('價格和郵費會在記帳裡各記成一筆拼團支出。',
              style: TextStyle(fontSize: 12, color: cSub)),
        ),
        const SizedBox(height: 16),
        Material(
          color: sent == null ? cAccent : cGoodTint,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (sent == null) {
                g.steps['寄出'] = today();
              } else {
                g.steps.remove('寄出');
              }
              _save();
            },
            child: SizedBox(
              height: 52,
              child: Center(
                child: Text(
                  sent == null
                      ? '車主還沒寄出 · 點一下標為已寄出'
                      : '已寄出 ${sent.substring(5).replaceAll('-', '/')}（點一下取消）',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: sent == null ? Colors.white : cGood),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 已收到：自動加進庫存，成本 = 價格 + 郵費。
        Material(
          color: got == null ? cAccent : cGoodTint,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              if (got == null) {
                if (g.slots.isEmpty) setFollowPrice(g, 0);
                g.steps['到貨'] = today();
                g.steps.putIfAbsent('寄出', today);
                _save();
                return;
              }
              final i = store.itemOf(g.slots.isEmpty ? null : g.slots.first.itemId);
              final sale = store.saleOf(i?.saleId);
              if (sale != null) {
                // 已經賣出：問清楚，確認後連成交紀錄一起取消。
                final others = sale.itemIds.length - 1;
                if (!await confirm(
                    context,
                    '這件已經賣出',
                    '取消已收到會連這筆成交紀錄和它的帳一起取消，庫存裡這件也會移除。'
                        '${others > 0 ? '同一筆成交的另外 $others 件會回到待售。' : ''}',
                    ok: '全部取消')) {
                  return;
                }
                store.undoSale(sale);
              } else if (!await confirm(context, '取消已收到？', '庫存裡這件周邊會一併移除。',
                  ok: '取消已收到')) {
                return;
              }
              g.steps.remove('到貨');
              if (i != null) {
                g.slots.first.itemId = null;
                store.deleteItem(i);
              }
              _save();
            },
            child: SizedBox(
              height: 52,
              child: Center(
                child: Text(
                  got == null
                      ? '還沒收到 · 點一下標為已收到並加入庫存'
                      : '已收到 ${got.substring(5).replaceAll('-', '/')} · 已加入庫存（點一下取消）',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: got == null ? Colors.white : cGood),
                ),
              ),
            ),
          ),
        ),
        if (got != null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('庫存裡這件的成本是價格加郵費，之後改價格或郵費會跟著更新。',
                style: TextStyle(fontSize: 12, color: cSub)),
          ),
      ]),
    );
  }
}
