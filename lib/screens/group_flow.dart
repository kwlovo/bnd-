import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart' show kShipMethods;
import '../models2.dart';
import '../ui.dart';
import 'group_page.dart' show SlotPage;
import 'item_form.dart' show today;
import 'pack_picker.dart';
import 'templates_page.dart';

/// 車主的一台車，按草圖分成四個畫面：開車、下單、到貨後、成本。
class GroupFlowPage extends StatefulWidget {
  const GroupFlowPage(this.groupId, {super.key});
  final String groupId;
  @override
  State<GroupFlowPage> createState() => _GroupFlowPageState();
}

class _GroupFlowPageState extends State<GroupFlowPage> {
  Group get g => store.groupOf(widget.groupId)!;
  /// 目前看的是哪一步的畫面，跟著四個進度走：開團、下單、到貨、打包寄出；另有「成本」。
  /// 「打包寄出」那一頁在程式裡叫「寄出」。
  late String view = g.nextStep.isEmpty || g.nextStep == '分好' ? '寄出' : g.nextStep;
  bool samePrice = false;
  final postCtl = <String, TextEditingController>{};
  final outCtl = <String, TextEditingController>{};
  final allPrice = TextEditingController();
  final orderAmount = TextEditingController();
  String orderCurrency = 'HKD';
  final priceCtl = <String, TextEditingController>{};
  late final nameCtl = TextEditingController(text: g.name);

  /// 到貨時才決定郵寄方式：每位車員先預設平郵、補 $4、實付 $2.4，之後逐個改。
  void _arrive() {
    g.steps['到貨'] = today();
    for (final s in g.slots.where((s) => s.sold && s.postIn == 0 && s.postOut == 0)) {
      s
        ..ship = '平郵'
        ..postIn = 400
        ..postOut = 240;
    }
    view = '到貨';
    _save();
  }

  void _save() {
    g.costMode = 'even';
    // 後面的步驟完成了，前面的也算完成。
    if (g.steps.containsKey('到貨')) g.steps.putIfAbsent('下單', today);
    if (g.steps.containsKey('下單')) g.steps.putIfAbsent('開團', today);
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
    store.saveGroup(g);
    setState(() {});
  }

  void _say(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _copy(String key) async {
    await Clipboard.setData(
        ClipboardData(text: renderTemplate(store.templates[key] ?? '', g)));
    _say('已複製${kTemplateNames[key]}文案');
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 400, imageQuality: 60);
    if (x == null) return;
    g.image = base64Encode(await x.readAsBytes());
    _save();
  }

  Future<void> _slot(Slot? s) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => SlotPage(g.id, s?.id)));
    if (store.groupOf(widget.groupId) == null) return;
    priceCtl.clear();
    _save();
  }

  bool _noPost(Slot s) => s.ship == '順豐' || s.ship == '面交' || s.postIn == 0;
  bool _paidOk(Slot s) => _noPost(s) || s.postInPaid;

  CostLine? _line(String name) {
    for (final c in g.costs) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// 加或改一項成本。由預估改為實際時保留預估值來比較。
  Future<void> _cost(CostLine? line, {String name = '', String stage = '下單'}) async {
    final nameC = TextEditingController(text: line?.name ?? name);
    final amount = TextEditingController(text: line == null ? '' : fmt(line.minor));
    final date =
        TextEditingController(text: line?.date.isNotEmpty == true ? line!.date : today());
    var st = line?.stage ?? stage;
    var currency = line?.currency ?? 'HKD';
    var actual = line?.actual ?? false;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(line == null ? '加一項成本' : '改成本'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: '名稱')),
              const SizedBox(height: 8),
              PickField(
                value: st,
                label: '階段',
                options: kCostStages,
                onChanged: (v) => st = v,
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
      if (minor == null || nameC.text.trim().isEmpty) return;
      final rate = currency == line?.currency ? line!.rate : (store.rates[currency] ?? 1);
      if (line == null) {
        g.costs.add(CostLine(
            id: store.newId(),
            stage: st,
            name: nameC.text.trim(),
            minor: minor,
            currency: currency,
            rate: rate,
            actual: actual,
            date: date.text.trim()));
      } else {
        if (!line.actual && actual) line.estHkd = line.hkd;
        line
          ..name = nameC.text.trim()
          ..stage = st
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

  Widget _pill(String t, Color fg, Color bg, VoidCallback? onTap) => Material(
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

  /// 補郵費 → 打包 → 寄出。下一步是亮藍，做完變綠，點綠色可取消。
  Widget _pipeline(Slot s) {
    const grey = Color(0xFFEBEEF3);
    final next = !_paidOk(s) ? 0 : (!s.packed ? 1 : (!s.sent ? 2 : 3));
    final face = s.ship == '面交';
    Widget todo(String t, int k, VoidCallback f) =>
        next == k ? _pill(t, Colors.white, cAccent, f) : _pill(t, cSub, grey, f);
    return Row(children: [
      Expanded(
        child: _noPost(s)
            ? _pill(s.ship == '順豐' ? '到付' : '不用補', cSub, grey, null)
            : s.postInPaid
                // 已補是在「到貨」那頁按的，這裡只顯示、不能取消。
                ? _pill('已補 \$${fmt(s.postIn)}', cGood, cGoodTint, null)
                : todo('標為已補 \$${fmt(s.postIn)}', 0, () {
                    s.postInPaid = true;
                    _save();
                  }),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: s.packed
            ? _pill('已打包 \$${fmt(s.pack)}', cGood, cGoodTint, () => _pack(s))
            : todo('打包', 1, () => _pack(s)),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: s.sent
            ? _pill(
                face
                    ? '已交收'
                    : '已寄 ${s.sentDate.length >= 10 ? s.sentDate.substring(5).replaceAll('-', '/') : ''}',
                cGood,
                cGoodTint, () {
                s.sent = false;
                _save();
              })
            : todo(face ? '已交收' : '寄出', 2, () {
                s
                  ..sent = true
                  ..sentDate = today();
                _save();
              }),
      ),
    ]);
  }

  Widget _stepper() {
    final soldN = g.slots.where((s) => s.sold).length;
    final sentN = g.slots.where((s) => s.sold && s.sent).length;
    return Row(children: [
      // 打包和寄出合成一步，所以這裡不列「分好」。
      for (final s in kSteps.where((s) => s != '分好'))
        Expanded(
          // 點任何一步，下面就顯示那一步的畫面。正在看的那一步是深藍。
          child: InkWell(
          onTap: () => setState(() => view = s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: view == s
                      ? cNavy
                      : g.steps.containsKey(s)
                          ? cAccent
                          : const Color(0xFFD5DAE3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s == '寄出' ? '打包寄出 $sentN/$soldN' : s,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: g.steps.containsKey(s) ? FontWeight.w700 : FontWeight.w400),
              ),
              if (g.steps[s] != null && s != '寄出')
                Text(g.steps[s]!.substring(5).replaceAll('-', '/'),
                    style: const TextStyle(fontSize: 10, color: cSub)),
            ]),
          ),
          ),
        ),
    ]);
  }

  /// 每位車員在這一步要做的事。到貨：選郵寄方式和補郵費；打包、寄出：三步進度。
  Widget _stageBody(Slot s, String stage) {
    if (stage == '到貨') {
      final ctl = postCtl.putIfAbsent(
          s.id, () => TextEditingController(text: s.postIn == 0 ? '' : fmt(s.postIn)));
      final quick = switch (s.ship) {
        '平郵' => const ['4', '5', '8.5'],
        '易寄取' => const ['10', '13'],
        _ => const <String>[],
      };
      void setIn(String v) {
        s.postIn = parseCents(v) ?? 0;
        ctl.text = v;
        _save();
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, children: [
          for (final m in kShipMethods)
            ChoiceChip(
              label: Text(m),
              selected: s.ship == m,
              showCheckmark: false,
              onSelected: (_) {
                s.ship = m;
                final (i, o) = switch (m) {
                  '平郵' => (400, 240),
                  '易寄取' => (1000, 1000),
                  _ => (0, 0),
                };
                s
                  ..postIn = i
                  ..postOut = o
                  ..postInPaid = false;
                postCtl.remove(s.id);
                outCtl.remove(s.id);
                _save();
              },
            ),
        ]),
        if (s.ship == '順豐')
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('順豐到付，不用補郵費。', style: TextStyle(fontSize: 12, color: cSub)),
          )
        else if (s.ship == '面交')
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('面交，不用補郵費。', style: TextStyle(fontSize: 12, color: cSub)),
          )
        else ...[
          const SizedBox(height: 6),
          Row(children: [
            SizedBox(
              width: 104,
              child: TextField(
                controller: ctl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '補 \$ '),
                onChanged: (v) {
                  s.postIn = parseCents(v) ?? 0;
                  _save();
                },
              ),
            ),
            const SizedBox(width: 6),
            for (final q in quick)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ActionChip(label: Text('\$$q'), onPressed: () => setIn(q)),
              ),
            ActionChip(label: const Text('包郵'), onPressed: () => setIn('')),
          ]),
          const SizedBox(height: 8),
          s.postIn == 0
              ? _pill('包郵，不用補', cSub, const Color(0xFFEBEEF3), null)
              : s.postInPaid
                  ? _pill('已補 \$${fmt(s.postIn)}（點一下取消）', cGood, cGoodTint, () {
                      s.postInPaid = false;
                      _save();
                    })
                  : _pill('標為已補 \$${fmt(s.postIn)}', Colors.white, cAccent, () {
                      s.postInPaid = true;
                      _save();
                    }),
        ],
      ]);
    }
    if (stage == '寄出' && (s.ship == '平郵' || s.ship == '易寄取')) {
      // 實付郵費用選的：平郵 2.4／4.3／8.5，易寄取 10／13，特殊情況選「其他」自己填。
      final presets = s.ship == '平郵' ? const [240, 430, 850] : const [1000, 1300];
      final now = '${s.postOut}';
      return Column(children: [
        _pipeline(s),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(
            child: Text('實付郵費（用來算郵費差價）', style: TextStyle(fontSize: 12, color: cSub)),
          ),
          SizedBox(
            width: 124,
            child: PickField(
              value: now,
              label: '實付郵費',
              options: [for (final p in presets) '$p', '其他'],
              labels: {
                for (final p in presets) '$p': 'HK\$ ${fmt(p)}',
                now: s.postOut == 0 ? '未填' : 'HK\$ ${fmt(s.postOut)}',
                '其他': '其他',
              },
              onChanged: (v) async {
                if (v != '其他') {
                  s.postOut = int.parse(v);
                  _save();
                  return;
                }
                final ctl = TextEditingController();
                final typed = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('實付郵費'),
                    content: TextField(
                      controller: ctl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(prefixText: 'HK\$ '),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, ctl.text),
                          child: const Text('確定')),
                    ],
                  ),
                );
                final cents = typed == null ? null : parseCents(typed);
                if (cents != null) s.postOut = cents;
                _save();
              },
            ),
          ),
        ]),
      ]);
    }
    return _pipeline(s);
  }

  Widget _big(String label, VoidCallback onTap, {Color color = cAccent}) => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
            backgroundColor: color, minimumSize: const Size.fromHeight(48)),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _tile(String label, String value, {String? sub, VoidCallback? onTap}) => Expanded(
        child: Card2(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: onTap == null ? cSub : cAccent,
                    fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w700)),
            FittedBox(
              child: Text(value,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            if (sub != null) Text(sub, style: const TextStyle(fontSize: 11, color: cSub)),
          ]),
        ),
      );

  // ---------- 開車：圖片、定價 ----------

  List<Widget> _openView(List<int> costs) {
    final total = g.margin + g.marginIfFull;
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(10),
          child: g.image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(base64Decode(g.image!),
                      width: 66, height: 66, fit: BoxFit.cover, gaplessPlayback: true),
                )
              : Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cSub, width: 1.5),
                  ),
                  child: const Text('+ 圖片', style: TextStyle(fontSize: 12, color: cSub)),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('團名'),
            TextField(
              controller: nameCtl,
              onChanged: (v) {
                if (v.trim().isEmpty) return;
                g.name = v.trim();
                store.saveGroup(g);
              },
            ),
          ]),
        ),
      ]),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('下單平台'),
            PickField(
              value: kOrderPlatforms.contains(g.platform) ? g.platform : '其他',
              options: kOrderPlatforms,
              onChanged: (v) {
                g.platform = v;
                _save();
              },
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('位數'),
            Container(
              height: 48,
              alignment: Alignment.centerLeft,
              child: Text('${g.slots.length} 位',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Card2(
        onTap: () => setState(() => view = '成本'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Expanded(
              child:
                  Text('預估成本', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Text('逐項填 ›',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cAccent)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text('合計 HK\$ ${fmt(g.totalCost)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Text('每位成本 HK\$ ${costs.isEmpty ? '0' : fmt(costs.first)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const Text('成本永遠每位平均分。郵費和包材另計。',
              style: TextStyle(fontSize: 12, color: cSub)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Text('全款價',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cSub)),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('全部一樣')),
              ButtonSegment(value: false, label: Text('自己輸入')),
            ],
            selected: {samePrice},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => samePrice = v.first),
          ),
        ),
      ]),
      if (samePrice)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: allPrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixText: 'HK\$ ', hintText: '每個位的全款價'),
            onChanged: (v) {
              final p = parseCents(v);
              if (p == null) return;
              for (final s in g.slots) {
                s.price = p;
              }
              priceCtl.clear();
              _save();
            },
          ),
        ),
      const SizedBox(height: 8),
      Card2(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Text('位（點名字改成員、車員）',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cSub)),
              ),
              SizedBox(
                width: 96,
                child: Text('全款價 HK\$',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cSub)),
              ),
              SizedBox(
                width: 56,
                child: Text('每位差價',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cSub)),
              ),
            ]),
          ),
          for (var k = 0; k < g.slots.length; k++)
            Builder(builder: (_) {
              final s = g.slots[k];
              final ctl = priceCtl.putIfAbsent(
                  s.id, () => TextEditingController(text: s.price == 0 ? '' : fmt(s.price)));
              return Container(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFEBEEF3)))),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _slot(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.member,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(s.self ? '我自留' : (s.buyer.isEmpty ? '剩位' : s.buyer),
                              style: const TextStyle(fontSize: 12, color: cSub)),
                        ]),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: s.self
                        ? const Text('—', style: TextStyle(color: cSub))
                        : TextField(
                            controller: ctl,
                            enabled: !samePrice,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              s.price = parseCents(v) ?? 0;
                              _save();
                            },
                          ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      s.self
                          ? '不計'
                          : '${s.price - costs[k] >= 0 ? '+' : ''}${fmt(s.price - costs[k])}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: s.self ? cSub : (s.price - costs[k] >= 0 ? cGood : cWarn)),
                    ),
                  ),
                ]),
              );
            }),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton.icon(
          onPressed: () => _slot(null),
          icon: const Icon(Icons.add),
          label: const Text('加一個位'),
        ),
        if (g.slots.isEmpty) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              for (final m in store.members.where((m) => m != '團體')) {
                g.slots.add(Slot(id: store.newId(), member: m));
              }
              _save();
            },
            child: const Text('每位成員各一個'),
          ),
        ],
        const Spacer(),
        Text('全部賣出差價 ${total >= 0 ? '+' : ''}${fmt(total)}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: total >= 0 ? cGood : cWarn)),
      ]),
      const SizedBox(height: 16),
      _big(g.steps.containsKey('開團') ? '複製開車文案' : '開車並複製開車文案', () {
        g.steps.putIfAbsent('開團', today);
        _save();
        _copy('open');
      }),
    ];
  }

  // ---------- 下單 ----------

  List<Widget> _orderView(List<int> costs) {
    final unpaid = g.slots.where((s) => s.sold && !s.paid).toList();
    final free = g.slots.where((s) => !s.taken).length;
    final line = _line('下單價格');
    return [
      if (unpaid.isNotEmpty || free > 0)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: cWarnTint, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              [
                if (unpaid.isNotEmpty)
                  '還有 ${unpaid.length} 人未付：${unpaid.map((s) => '${s.buyer}（${s.member} 位 \$${fmt(s.price)}）').join('、')}。',
                if (free > 0) '剩位 $free 個。',
              ].join(''),
              style: const TextStyle(fontSize: 13, color: cWarn, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (unpaid.isNotEmpty)
                OutlinedButton(onPressed: () => _copy('dun'), child: const Text('複製催款訊息')),
              if (free > 0)
                OutlinedButton(onPressed: () => _copy('left'), child: const Text('複製剩位文案')),
            ]),
          ]),
        ),
      const FieldLabel('位和付款（點「未付」可直接標為已付）'),
      Card2(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Column(children: [
          for (var k = 0; k < g.slots.length; k++)
            Builder(builder: (_) {
              final s = g.slots[k];
              return InkWell(
                onTap: () => _slot(s),
                child: Container(
                  decoration: BoxDecoration(
                      border: k == 0
                          ? null
                          : const Border(top: BorderSide(color: Color(0xFFEBEEF3)))),
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(children: [
                    SizedBox(
                      width: 76,
                      child: Text(s.member,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: Text(
                        s.self ? '我自留' : (s.buyer.isEmpty ? '剩位' : '${s.buyer} · ${s.source}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: s.taken ? cInk : cAccent),
                      ),
                    ),
                    Text(s.self ? '成本 \$${fmt(costs[k])}' : '\$${fmt(s.price)}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: !s.sold
                          ? const SizedBox()
                          : InkWell(
                              onTap: () {
                                s.paid = !s.paid;
                                if (s.paid) s.paidDate = today();
                                _save();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: s.paid
                                    ? const Tag('已付', fg: cGood, bg: cGoodTint)
                                    : const Tag('未付', fg: cWarn, bg: cWarnTint),
                              ),
                            ),
                    ),
                  ]),
                ),
              );
            }),
        ]),
      ),
      const SizedBox(height: 12),
      Card2(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('實際下單價格（含代購費）',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: orderAmount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: line == null
                      ? '只填一個總數'
                      : '目前 ${line.currency} ${fmt(line.minor)}（${line.actual ? '實際' : '預估'}）',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: PickField(
                value: orderCurrency,
                options: store.rates.keys.toList(),
                onChanged: (v) => orderCurrency = v,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final minor = parseCents(orderAmount.text);
                if (minor == null) return;
                final rate = store.rates[orderCurrency] ?? 1;
                if (line == null) {
                  g.costs.add(CostLine(
                      id: store.newId(),
                      stage: '下單',
                      name: '下單價格',
                      minor: minor,
                      currency: orderCurrency,
                      rate: rate,
                      actual: true,
                      date: today()));
                } else {
                  if (!line.actual) line.estHkd = line.hkd;
                  line
                    ..minor = minor
                    ..currency = orderCurrency
                    ..rate = rate
                    ..actual = true
                    ..date = today();
                }
                orderAmount.clear();
                _save();
                _say('已記下實際下單價格');
              },
              child: const Text('記下'),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('會自動記入記帳。其他費用到「成本」那一頁加。',
              style: TextStyle(fontSize: 12, color: cSub)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        _tile('總成本 ›', 'HK\$ ${fmt(g.totalCost)}',
            sub: '實際 ${g.actualCount} 項 · 預估 ${g.estCount} 項',
            onTap: () => setState(() => view = '成本')),
        const SizedBox(width: 8),
        _tile('每位成本', 'HK\$ ${costs.isEmpty ? '0' : fmt(costs.first)}'),
      ]),
      const SizedBox(height: 16),
      if (!g.steps.containsKey('下單'))
        _big('已下單', () {
          g.steps['下單'] = today();
          _save();
        })
      else if (!g.steps.containsKey('到貨'))
        _big('已到貨', _arrive)
      else
        const Text('已下單、已到貨。點上面的「到貨」處理每位車員的郵寄方式。',
            style: TextStyle(fontSize: 13, color: cSub)),
    ];
  }

  // ---------- 到貨後：逐個車員 ----------

  List<Widget> _stageView(String stage) {
    if (!g.steps.containsKey('到貨')) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('到貨之後才決定郵寄方式。到貨後這裡會列出每位車員，逐個補郵費、打包、寄出。',
              style: TextStyle(fontSize: 14, color: cSub)),
        ),
        _big('已到貨', _arrive),
      ];
    }
    final sold = g.slots.where((s) => s.sold).toList();
    // 還沒做這一步的車員排在前面。
    bool doneHere(Slot s) => stage == '到貨' ? _paidOk(s) : s.sent;
    final shown = [...sold.where((s) => !doneHere(s)), ...sold.where(doneHere)];
    final selfN = g.slots.where((s) => s.self).length;
    return [
      if (stage == '到貨')
      Row(children: [
        Expanded(
          child: FilledButton(onPressed: () => _copy('arrive'), child: const Text('複製到貨通知')),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _cost(_line('國際運費'), name: '國際運費', stage: '運回來'),
            child: const Text('填實際運費'),
          ),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          switch (stage) {
            '到貨' => '逐個車員選郵寄方式和補郵費，補了就標為已補。',
            _ => '誰補了郵費就先打包、寄出誰，不用等全部人。做一個按一個。',
          },
          style: const TextStyle(fontSize: 13, color: cSub),
        ),
      ),
      if (shown.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('還沒有車員。到「下單」那一步點位來填車員。', style: TextStyle(color: cSub)),
        ),
      for (final s in shown)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card2(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(children: [
              InkWell(
                onTap: () => _slot(s),
                child: Row(children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: s.buyer,
                            style:
                                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        TextSpan(
                            text: '  ${s.member} 位 · ${s.source}',
                            style: const TextStyle(fontSize: 12, color: cSub)),
                      ]),
                    ),
                  ),
                  Text(
                    '${s.ship}${s.ship == '順豐' ? ' · 到付' : (s.postIn > 0 ? ' · \$${fmt(s.postIn)}' : ' · 免郵費')} ›',
                    style: const TextStyle(fontSize: 12, color: cAccent),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              _stageBody(s, stage),
            ]),
          ),
        ),
      const SizedBox(height: 12),
      if (stage == '到貨')
        _big('下一步：打包寄出', () => setState(() => view = '寄出')),
      if (selfN > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('自留的 $selfN 個位已自動加入庫存。',
              style: const TextStyle(fontSize: 12, color: cSub)),
        ),
      if (g.steps.containsKey('寄出')) ...[
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => _copy('sent'), child: const Text('複製寄出通知')),
      ],
    ];
  }

  // ---------- 成本清單 ----------

  List<Widget> _costView(List<int> costs) {
    final over = [
      for (final c in g.costs)
        if (c.actual && c.estHkd != null && c.hkd > c.estHkd!) c,
    ];
    return [
      for (final c in over)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
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
      if (g.costs.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('還沒有成本。先加預估，之後逐項改成實際。', style: TextStyle(color: cSub)),
        ),
      for (final st in kCostStages)
        if (g.costs.any((c) => c.stage == st)) ...[
          FieldLabel(st),
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
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      if (c.currency != 'HKD' || (c.actual && c.estHkd != null))
                        Text(
                          [
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
        ],
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _cost(null),
          icon: const Icon(Icons.add),
          label: const Text('加一項成本'),
        ),
      ),
      const SizedBox(height: 8),
      const Text('郵費差價和包材不入每位成本，另開「郵包」一格計算，結算時再和車位差價合計。',
          style: TextStyle(fontSize: 12, color: cSub)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final costs = g.slotCosts();
    final body = switch (view) {
      '開團' => _openView(costs),
      '下單' => _orderView(costs),
      '到貨' || '打包' || '寄出' => _stageView(view),
      _ => _costView(costs),
    };
    String signed(int c) => '${c >= 0 ? '+' : '−'}HK\$ ${fmt(c.abs())}';
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
            tooltip: '編輯文案模板',
            icon: const Icon(Icons.edit_note),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => TemplatesPage(sample: g))),
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
        _stepper(),
        const SizedBox(height: 6),
        if (view == '成本')
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('成本清單（點上面任何一步返回）',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ...body,
      ]),
      // 底部深藍的結算條：車位差價、郵包、合計利潤。
      bottomNavigationBar: SafeArea(
        child: Container(
          color: cNavy,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Row(children: [
              for (final e in {
                '車位差價': signed(g.margin),
                '郵包': signed(g.postNet),
                '合計利潤': signed(g.margin + g.postNet),
              }.entries)
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(e.key, style: const TextStyle(fontSize: 12)),
                    FittedBox(
                      child: Text(e.value,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
