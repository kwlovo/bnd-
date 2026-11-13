import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';

/// 外網切卡的到貨按鈕：未到貨是亮藍，點一下標為已到貨；已到貨是綠色，點一下取消。
class ArrivedPill extends StatelessWidget {
  const ArrivedPill(this.b, {super.key, this.onChanged});
  final Batch b;
  final VoidCallback? onChanged;

  Widget _pill(bool done, String text, VoidCallback onTap) => Expanded(
        child: Material(
          color: done ? cGoodTint : cAccent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Center(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(text,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: done ? cGood : Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          _pill(b.arrived, b.arrived ? '已到貨' : '未到貨 · 點一下標為已到貨', () {
            b.arrived = !b.arrived;
            store.updateBatch(b);
            onChanged?.call();
          }),
          const SizedBox(width: 8),
          _pill(b.intlPaid, b.intlPaid ? '國際運費已補' : '國際運費未補 · 點一下標為已補', () {
            b.intlPaid = !b.intlPaid;
            store.updateBatch(b);
            onChanged?.call();
          }),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${b.platform} 外網切卡 · 綠色的再點一下可以取消',
              style: const TextStyle(fontSize: 12, color: cSub)),
        ),
      ]);
}

/// 入手批次詳情：改總價、改分攤方式、逐件填參考價或成本。
class BatchPage extends StatefulWidget {
  const BatchPage(this.batchId, {super.key});
  final String batchId;
  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  late final Batch b = store.batchOf(widget.batchId)!;
  late final total = TextEditingController(
      text: b.totalMinor == null ? '' : fmt(b.totalMinor!));
  late final intl =
      TextEditingController(text: b.intlShip == 0 ? '' : fmt(b.intlShip));
  final fields = <String, TextEditingController>{};

  TextEditingController _field(Item i) => fields.putIfAbsent(i.id, () {
        final v = b.method == AllocMethod.byRef ? i.refCents : i.manualCents;
        return TextEditingController(text: v == null ? '' : fmt(v));
      });

  void _apply() {
    b.totalMinor = parseCents(total.text);
    if (b.overseas) b.intlShip = parseCents(intl.text) ?? 0;
    for (final i in store.itemsOfBatch(b.id)) {
      final v = parseCents(_field(i).text);
      if (b.method == AllocMethod.byRef) i.refCents = v;
      if (b.method == AllocMethod.manual) i.manualCents = v;
    }
    store.updateBatch(b);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = store.itemsOfBatch(b.id);
    int n(String s) => items.where((i) => i.status == s).length;
    final totalHkd = b.totalHkd;
    final recovered = items.fold<int>(0, (a, i) => a + (i.soldCents ?? 0));
    final diff = (b.method == AllocMethod.manual && totalHkd != null)
        ? manualDiff(totalHkd, [for (final i in items) i.manualCents])
        : 0;
    final allFilled = items.every((i) => i.manualCents != null);
    return Scaffold(
      appBar: AppBar(title: Text(b.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Card2(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              totalHkd == null
                  ? '總價：忘記了'
                  : '總價 ${b.approx ? '≈ ' : ''}HK\$ ${fmt(totalHkd)}'
                      '${b.currency == 'HKD' ? '' : '（${b.currency} ${fmt(b.totalMinor!)}，匯率 ${b.rate}）'}'
                      '${b.overseas ? (b.intlShip > 0 ? '\n含國際運費 HK\$ ${fmt(b.intlShip)}' : '\n國際運費還沒補') : ''}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${items.length} 件 · 已售 ${n('已售出')} · 待售 ${n('待售')}'
              '${b.inLedger ? '' : ' · 不記入記帳'}',
              style: const TextStyle(fontSize: 13, color: cSub),
            ),
            const SizedBox(height: 4),
            if (totalHkd != null && totalHkd > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (recovered / totalHkd).clamp(0, 1).toDouble(),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '已回收 HK\$ ${fmt(recovered)}（${(recovered * 100 / totalHkd).round()}%）· '
                '${recovered >= totalHkd ? '已賺 HK\$ ${fmt(recovered - totalHkd)}' : '再賣 HK\$ ${fmt(totalHkd - recovered)} 就回本'}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ]),
        ),
        if (b.overseas) ...[
          const SizedBox(height: 8),
          ArrivedPill(b, onChanged: () => setState(() {})),
          const FieldLabel('國際運費（HK\$，算進這批成本）'),
          TextField(
            controller: intl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '還沒補就留空'),
          ),
        ],
        FieldLabel(b.overseas
            ? '物品價格（${b.currency}，不含國際運費）留空 = 忘記了'
            : '總價（${b.currency}）留空 = 忘記了'),
        Row(children: [
          Expanded(
            child: TextField(
              controller: total,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('只是大概'),
            selected: b.approx,
            onSelected: (v) => setState(() => b.approx = v),
          ),
        ]),
        const FieldLabel('怎樣分到每一件'),
        SegmentedButton<AllocMethod>(
          segments: const [
            ButtonSegment(value: AllocMethod.even, label: Text('平均分')),
            ButtonSegment(value: AllocMethod.byRef, label: Text('按參考價')),
            ButtonSegment(value: AllocMethod.manual, label: Text('手動')),
          ],
          selected: {b.method},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            b.method = s.first;
            fields.clear();
          }),
        ),
        const SizedBox(height: 6),
        Text(
          switch (b.method) {
            AllocMethod.even => '總價 ÷ 件數。',
            AllocMethod.byRef => '每件填一個大概市價，按比例分總價；不用準，只決定誰分多一點。',
            AllocMethod.manual => '記得的逐件填，留空的會平均分掉剩下的金額。',
          },
          style: const TextStyle(fontSize: 12, color: cSub),
        ),
        if (b.method == AllocMethod.manual && allFilled && diff != 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '逐件合計和總價相差 HK\$ ${fmt(diff)}，請調整。',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cWarn),
            ),
          ),
        const SizedBox(height: 12),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card2(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(store.titleOf(i),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Tag.status(i.status),
                    ]),
                    const SizedBox(height: 2),
                    costLabel(i),
                  ]),
                ),
                if (b.method != AllocMethod.even)
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _field(i),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: b.method == AllocMethod.byRef ? '參考價' : '成本',
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _apply,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('重新計算並儲存'),
        ),
      ]),
    );
  }
}
