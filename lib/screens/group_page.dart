import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/money.dart';
import '../main.dart';
import '../models2.dart';
import '../ui.dart';
import 'item_form.dart' show today;
import 'pack_picker.dart';
import 'sale_page.dart' show PostageFields;
import 'templates_page.dart';

/// 一台車的詳情：進度、位、成本清單、文案、結算。
class GroupPage extends StatefulWidget {
  const GroupPage(this.groupId, {super.key});
  final String groupId;
  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  Group get g => store.groupOf(widget.groupId)!;

  final allPrice = TextEditingController();

  void _save() {
    // 成本永遠每位平均分。
    g.costMode = 'even';
    if (g.owner) {
      // 「分好」「寄出」由每位車員的進度自動決定。
      final sold = g.slots.where((s) => s.sold).toList();
      final arrived = g.steps.containsKey('到貨');
      void setStep(String k, bool done) {
        if (done) {
          g.steps.putIfAbsent(k, today);
        } else {
          g.steps.remove(k);
        }
      }

      setStep('分好', arrived && sold.isNotEmpty && sold.every((s) => s.packed));
      setStep('寄出', arrived && sold.isNotEmpty && sold.every((s) => s.sent));
    }
    store.saveGroup(g);
    setState(() {});
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x == null) return;
    g.image = base64Encode(await x.readAsBytes());
    _save();
  }

  /// 打包這位車員的包裹：選用料，成本自動算，包材庫存自動扣。
  Future<void> _pack(Slot s) async {
    final uses = [for (final u in s.uses) u.copy()];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${s.buyer} 的包裹用了什麼',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: PackPicker(uses: uses, onChanged: () => setS(() {})),
                  ),
                ),
                const SizedBox(height: 8),
                // 金額條用亮藍，最下面的按鈕用深藍，兩者不撞色。
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration:
                      BoxDecoration(color: cAccent, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Expanded(
                      child: Text('這個包裹的包材（計入郵包那一格）',
                          style: TextStyle(fontSize: 13, color: Colors.white)),
                    ),
                    Text('HK\$ ${fmt(store.packCostOf(uses))}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: cNavy, minimumSize: const Size.fromHeight(48)),
                  child: Text('${s.buyer} 打包完成'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    store.consume(s.uses, -1);
    store.consume(uses, 1);
    s
      ..uses = uses
      ..pack = store.packCostOf(uses)
      ..packed = true;
    _save();
  }

  /// 每位車員各自走三步：補郵費 → 打包 → 寄出。下一步要做的是實心按鈕，
  /// 做完的變成綠色，點綠色可以取消。
  Widget _pipeline(Slot s) {
    final noPost = s.ship == '順豐' || s.ship == '面交' || s.postIn == 0;
    final paidOk = noPost || s.postInPaid;
    final next = !paidOk ? 0 : (!s.packed ? 1 : (!s.sent ? 2 : 3));
    final face = s.ship == '面交';

    Widget pill(String t, Color fg, Color bg, VoidCallback? onTap) => Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Center(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(t,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                  ),
                ),
              ),
            ),
          ),
        );
    Widget done(String t, VoidCallback undo) => pill(t, cGood, cGoodTint, undo);
    Widget todo(String t, bool primary, VoidCallback onTap) => primary
        ? pill(t, Colors.white, cAccent, onTap)
        : pill(t, cSub, const Color(0xFFEBEEF3), onTap);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(
          child: noPost
              ? pill(s.ship == '順豐' ? '到付' : '不用補', cSub, const Color(0xFFEBEEF3), null)
              : s.postInPaid
                  ? done('已補 \$${fmt(s.postIn)}', () {
                      s.postInPaid = false;
                      _save();
                    })
                  : todo('標為已補 \$${fmt(s.postIn)}', next == 0, () {
                      s.postInPaid = true;
                      _save();
                    }),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: s.packed
              ? done('已打包 \$${fmt(s.pack)}', () => _pack(s))
              : todo('打包', next == 1, () => _pack(s)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: s.sent
              ? done(face ? '已交收' : '已寄 ${s.sentDate.length >= 10 ? s.sentDate.substring(5).replaceAll('-', '/') : ''}', () {
                  s.sent = false;
                  _save();
                })
              : todo(face ? '已交收' : '寄出', next == 2, () {
                  s
                    ..sent = true
                    ..sentDate = today();
                  _save();
                }),
        ),
      ]),
    );
  }

  void _say(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  void _toggleStep(String step) {
    if (g.steps.containsKey(step)) {
      g.steps.remove(step);
    } else {
      g.steps[step] = today();
      if (step == '到貨') {
        final n = g.slots.where((s) => (g.owner ? s.self : true) && s.itemId == null).length;
        if (n > 0) _say('$n 個位已加入庫存');
      }
    }
    _save();
  }

  Future<void> _copy(String key) async {
    await Clipboard.setData(
        ClipboardData(text: renderTemplate(store.templates[key] ?? '', g)));
    _say('已複製${kTemplateNames[key]}文案');
  }

  Future<void> _slot(Slot? s) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => SlotPage(g.id, s?.id)));
    if (store.groupOf(widget.groupId) != null) _save();
  }

  Future<void> _cost(CostLine? line) async {
    final name = TextEditingController(text: line?.name ?? '');
    final amount = TextEditingController(text: line == null ? '' : fmt(line.minor));
    final date = TextEditingController(text: line?.date.isNotEmpty == true ? line!.date : today());
    var stage = line?.stage ?? kCostStages.first;
    var currency = line?.currency ?? 'HKD';
    var actual = line?.actual ?? false;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(line == null ? '加一項成本' : '改成本'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: name,
                decoration:
                    const InputDecoration(labelText: '名稱', hintText: '例如：下單價格、國際運費'),
              ),
              const SizedBox(height: 8),
              PickField(
                value: stage,
                label: '階段',
                options: kCostStages,
                onChanged: (v) => stage = v,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '金額'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: PickField(
                    value: currency,
                    options: store.rates.keys.toList(),
                    onChanged: (v) => currency = v,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('預估')),
                  ButtonSegment(value: true, label: Text('實際')),
                ],
                selected: {actual},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setD(() => actual = v.first),
              ),
              const SizedBox(height: 8),
              TextField(controller: date, decoration: const InputDecoration(labelText: '日期')),
            ]),
          ),
          actions: [
            if (line != null)
              TextButton(onPressed: () => Navigator.pop(c, 'delete'), child: const Text('刪除')),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('儲存')),
          ],
        ),
      ),
    );
    if (r == 'delete') {
      g.costs.remove(line);
    } else if (r == 'save') {
      final minor = parseCents(amount.text);
      if (minor == null || name.text.trim().isEmpty) return;
      final rate = currency == line?.currency ? line!.rate : (store.rates[currency] ?? 1);
      if (line == null) {
        g.costs.add(CostLine(
          id: store.newId(),
          stage: stage,
          name: name.text.trim(),
          minor: minor,
          currency: currency,
          rate: rate,
          actual: actual,
          date: date.text.trim(),
        ));
      } else {
        // 由預估改為實際時，保留原本的預估值來比較。
        if (!line.actual && actual) line.estHkd = line.hkd;
        line
          ..name = name.text.trim()
          ..stage = stage
          ..minor = minor
          ..currency = currency
          ..rate = rate
          ..actual = actual
          ..date = date.text.trim();
      }
    } else {
      return;
    }
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final costs = g.slotCosts();
    final soldN = g.slots.where((s) => s.sold).length;
    final packedN = g.slots.where((s) => s.sold && s.packed).length;
    final sentN = g.slots.where((s) => s.sold && s.sent).length;
    final over = [
      for (final c in g.costs)
        if (c.actual && c.estHkd != null && c.hkd > c.estHkd!) c,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (g.image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(base64Decode(g.image!),
                  width: 36, height: 36, fit: BoxFit.cover, gaplessPlayback: true),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(g.name, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            tooltip: g.image == null ? '加這台車的圖片' : '換圖片',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _pickImage,
          ),
          IconButton(
            tooltip: '刪除這台車',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirm(context, '刪除這台車？', '「${g.name}」和它的帳會被刪除，已入庫存的周邊會保留。',
                  ok: '刪除')) {
                store.deleteGroup(g);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        // 進度：點一下打勾並記下今天的日期，再點一下取消。
        Row(children: [
          for (final s in kSteps)
            Expanded(
              child: InkWell(
                // 車主的「分好」「寄出」由每位車員的進度自動決定，不能手動打勾。
                onTap: g.owner && (s == '分好' || s == '寄出') ? null : () => _toggleStep(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  child: Column(children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: g.steps.containsKey(s) ? cAccent : const Color(0xFFD5DAE3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(s,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                g.steps.containsKey(s) ? FontWeight.w700 : FontWeight.w400)),
                    Text(
                      g.owner && s == '分好'
                          ? '打包 $packedN / $soldN'
                          : g.owner && s == '寄出'
                              ? '寄出 $sentN / $soldN'
                              : g.steps[s] == null
                                  ? '點一下'
                                  : g.steps[s]!.substring(5).replaceAll('-', '/'),
                      style: const TextStyle(fontSize: 11, color: cSub),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        if (g.owner) ...[
          Row(children: [
            _stat('已收款／應收', 'HK\$ ${fmt(g.received)} / ${fmt(g.due)}'),
            const SizedBox(width: 8),
            _stat('總成本', 'HK\$ ${fmt(g.totalCost)}',
                sub: '實際 ${g.actualCount} 項 · 預估 ${g.estCount} 項'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _stat('車位差價', '${g.margin >= 0 ? '+' : '−'}HK\$ ${fmt(g.margin.abs())}',
                sub: g.marginIfFull != 0 ? '剩位賣出再 +${fmt(g.marginIfFull)}' : null,
                color: g.margin >= 0 ? cGood : cWarn),
            const SizedBox(width: 8),
            _stat('郵包（郵費差價 − 包材）',
                '${g.postNet >= 0 ? '+' : '−'}HK\$ ${fmt(g.postNet.abs())}',
                sub: '合計利潤 ${fmt(g.margin + g.postNet)}'),
          ]),
          for (final c in over)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(color: cWarnTint, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${c.name}比預估高 HK\$ ${fmt(c.hkd - c.estHkd!)}（預估 ${fmt(c.estHkd!)} → 實際 ${fmt(c.hkd)}），差價已重新計算。',
                  style: const TextStyle(fontSize: 13, color: cWarn, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ] else
          Card2(
            child: Text(
              '車主 ${g.leader.isEmpty ? '（未填）' : g.leader} · '
              '已付 HK\$ ${fmt(g.slots.where((s) => s.paid).fold<int>(0, (a, s) => a + s.price))}'
              ' / 全款 ${fmt(g.slots.fold<int>(0, (a, s) => a + s.price))}\n'
              '到貨那一步打勾後，我的位會自動加入庫存，成本就是全款價。',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        const FieldLabel('位（自己選成員，可重複）'),
        for (var k = 0; k < g.slots.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Builder(builder: (_) {
              final s = g.slots[k];
              final who = !g.owner
                  ? '我的位'
                  : s.self
                      ? '我自留'
                      : s.buyer.isEmpty
                          ? '剩位'
                          : '${s.buyer} · ${s.source}';
              return Card2(
                onTap: () => _slot(s),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.member,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        [
                          who,
                          if (g.owner && s.sold) s.ship,
                          if (g.owner && s.sold && s.postIn > 0)
                            '補郵費 \$${fmt(s.postIn)}${s.postInPaid ? '（已補）' : ''}',
                          if (s.sent) '已寄',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: cSub),
                      ),
                    ]),
                  ),
                  if (g.owner && s.self)
                    Text('成本 \$${fmt(costs[k])}',
                        style: const TextStyle(fontSize: 13, color: cSub))
                  else ...[
                    Text('\$${fmt(s.price)}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    if (!g.owner || s.sold)
                      s.paid
                          ? const Tag('已付', fg: cGood, bg: cGoodTint)
                          : const Tag('未付', fg: cWarn, bg: cWarnTint),
                    if (g.owner) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${s.price - costs[k] >= 0 ? '+' : ''}${fmt(s.price - costs[k])}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ]),
                if (g.owner && s.sold && g.steps.containsKey('到貨')) _pipeline(s),
                ]),
              );
            }),
          ),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => _slot(null),
            icon: const Icon(Icons.add),
            label: const Text('加一個位'),
          ),
          if (g.owner && g.slots.isEmpty)
            OutlinedButton(
              onPressed: () {
                for (final m in store.members.where((m) => m != '團體')) {
                  g.slots.add(Slot(id: store.newId(), member: m, postIn: 400, postOut: 240));
                }
                _save();
              },
              child: const Text('每位成員各加一個位'),
            ),
        ]),
        if (g.owner) ...[
          const FieldLabel('全款價：全部一樣（想逐個位不同，就點進每個位自己輸入）'),
          Row(children: [
            Expanded(
              child: TextField(
                controller: allPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: 'HK\$ ', hintText: '每個位的全款價'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final p = parseCents(allPrice.text);
                if (p == null || g.slots.isEmpty) return;
                for (final s in g.slots) {
                  s.price = p;
                }
                allPrice.clear();
                _save();
                _say('全部位已改成 HK\$ ${fmt(p)}');
              },
              child: const Text('套用到全部位'),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('成本永遠每位平均分：下面成本清單的合計 ÷ 位數。郵費和包材另計。',
              style: TextStyle(fontSize: 12, color: cSub)),
          const FieldLabel('成本清單'),
          for (final st in kCostStages)
            for (final c in g.costs.where((c) => c.stage == st))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card2(
                  onTap: () => _cost(c),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name,
                            style:
                                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(
                          [
                            c.stage,
                            if (c.currency != 'HKD') '${c.currency} ${fmt(c.minor)}',
                            if (c.actual && c.estHkd != null) '預估 \$${fmt(c.estHkd!)}',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: cSub),
                        ),
                      ]),
                    ),
                    c.actual
                        ? const Tag('實際', fg: cGood, bg: cGoodTint)
                        : const Tag('預估', fg: cSub, bg: Colors.white, dashed: true),
                    const SizedBox(width: 8),
                    Text('HK\$ ${fmt(c.hkd)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _cost(null),
              icon: const Icon(Icons.add),
              label: const Text('加一項成本'),
            ),
          ),
          const FieldLabel('複製文案（按你的模板產生）'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final k in kTemplateNames.keys)
              OutlinedButton(onPressed: () => _copy(k), child: Text(kTemplateNames[k]!)),
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => TemplatesPage(sample: g))),
              child: const Text('編輯模板 ›'),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _stat(String label, String value, {String? sub, Color? color}) => Expanded(
        child: Card2(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: cSub)),
            FittedBox(
              child: Text(value,
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color ?? cInk)),
            ),
            if (sub != null) Text(sub, style: const TextStyle(fontSize: 11, color: cSub)),
          ]),
        ),
      );
}

/// 一個位：誰要、付款、交收和補郵費、打包用料、是否已寄。
class SlotPage extends StatefulWidget {
  const SlotPage(this.groupId, this.slotId, {super.key});
  final String groupId;
  final String? slotId;
  @override
  State<SlotPage> createState() => _SlotPageState();
}

class _SlotPageState extends State<SlotPage> {
  late final Group g = store.groupOf(widget.groupId)!;
  late final Slot? old = () {
    for (final s in g.slots) {
      if (s.id == widget.slotId) return s;
    }
    return null;
  }();
  late String member = old?.member ?? store.members.first;
  late final price = TextEditingController(text: old == null ? '' : fmt(old!.price));
  late final own =
      TextEditingController(text: old?.ownCost == null ? '' : fmt(old!.ownCost!));
  late final buyer = TextEditingController(text: old?.buyer ?? '');
  late String source = old?.source ?? 'IG';
  late bool paid = old?.paid ?? false;
  late bool self = old?.self ?? false;
  late String ship = old?.ship ?? '平郵';
  late final postIn = TextEditingController(
      text: old == null ? '' : (old!.postIn == 0 ? '' : fmt(old!.postIn)));
  late final postOut = TextEditingController(
      text: old == null ? '' : (old!.postOut == 0 ? '' : fmt(old!.postOut)));
  late bool postInPaid = old?.postInPaid ?? false;
  late bool sent = old?.sent ?? false;
  late final uses = [for (final u in old?.uses ?? <PackUse>[]) u.copy()];

  void _save() {
    final s = old ?? Slot(id: store.newId(), member: member);
    if (old == null) g.slots.add(s);
    // 包材：先把舊的加回庫存，再扣新的。
    store.consume(s.uses, -1);
    store.consume(uses, 1);
    if (paid && !s.paid) s.paidDate = today();
    s
      ..member = member
      ..price = parseCents(price.text) ?? 0
      ..ownCost = parseCents(own.text)
      ..buyer = self ? '' : buyer.text.trim()
      ..source = source
      ..paid = paid
      ..self = self
      ..ship = ship
      ..postIn = self ? 0 : (parseCents(postIn.text) ?? 0)
      ..postInPaid = postInPaid
      ..postOut = self ? 0 : (parseCents(postOut.text) ?? 0)
      ..uses = uses
      ..pack = store.packCostOf(uses)
      ..sent = sent;
    store.saveGroup(g);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const num = TextInputType.numberWithOptions(decimal: true);
    final owner = g.owner;
    return Scaffold(
      appBar: AppBar(
        title: Text(old == null ? '加一個位' : '${old!.member} 位'),
        actions: [
          if (old != null)
            IconButton(
              tooltip: '刪除這個位',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, '刪除這個位？', '${old!.member} 位會被刪除。', ok: '刪除')) {
                  store.consume(old!.uses, -1);
                  g.slots.remove(old);
                  store.saveGroup(g);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const FieldLabel('成員'),
        PickField(
          value: member,
          options: {...store.members, member}.toList(),
          onChanged: (v) => setState(() => member = v),
        ),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('全款價 HK\$'),
              TextField(controller: price, keyboardType: num),
            ]),
          ),
          if (owner && g.costMode == 'own') ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('這個位的進價 HK\$'),
                TextField(controller: own, keyboardType: num),
              ]),
            ),
          ],
        ]),
        if (owner)
          CheckboxListTile(
            value: self,
            onChanged: (v) => setState(() => self = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('我自留（按真實成本入庫存，不計差價）'),
          ),
        if (owner && !self) ...[
          const FieldLabel('車員（留空 = 剩位）'),
          TextField(controller: buyer, decoration: const InputDecoration(hintText: '帳號或名字')),
          const FieldLabel('來自'),
          Wrap(spacing: 6, children: [
            for (final x in kSources)
              ChoiceChip(
                label: Text(x),
                selected: source == x,
                showCheckmark: false,
                onSelected: (_) => setState(() => source = x),
              ),
          ]),
        ],
        if (!self)
          CheckboxListTile(
            value: paid,
            onChanged: (v) => setState(() => paid = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(owner ? '已付全款' : '我已付款'),
          ),
        // 郵寄方式要到貨後才知道，到貨前不顯示。
        if (owner && !self && g.steps.containsKey('到貨')) ...[
          const SizedBox(height: 8),
          Card2(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('到貨後：交收和補郵費',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              PostageFields(
                ship: ship,
                postIn: postIn,
                postOut: postOut,
                inLabel: '向車員收的補郵費（HK\$，包郵就留空）',
                onShip: (v) => setState(() {
                  ship = v;
                  PostageFields.defaults(v, postIn, postOut);
                }),
                onChanged: () => setState(() {}),
              ),
              CheckboxListTile(
                value: postInPaid,
                onChanged: (v) => setState(() => postInPaid = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('車員已補郵費'),
              ),
              const FieldLabel('打包用了什麼'),
              PackPicker(uses: uses, onChanged: () => setState(() {})),
              CheckboxListTile(
                value: sent,
                onChanged: (v) => setState(() => sent = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('已寄出／已交收'),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('儲存'),
        ),
      ]),
    );
  }
}
