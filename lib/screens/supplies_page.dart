import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../ui.dart';
import 'item_form.dart' show today;

/// 包材庫存：入貨只填數量和總價，單價自動算；自己勾選正在用哪一批。
class SuppliesPage extends StatefulWidget {
  const SuppliesPage({super.key});
  @override
  State<SuppliesPage> createState() => _SuppliesPageState();
}

class _SuppliesPageState extends State<SuppliesPage> {
  final name = TextEditingController();
  final qty = TextEditingController();
  final total = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final q = int.tryParse(qty.text.trim());
    final t = parseCents(total.text);
    final unit = (q != null && q > 0 && t != null) ? (t / q).round() : null;
    return Scaffold(
      appBar: AppBar(title: const Text('包材庫存')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        if (store.supplies.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('還沒有包材。在下面填第一批入貨。', style: TextStyle(color: cSub)),
          ),
        for (final s in store.supplies)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card2(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(s.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  if (s.left <= 5) const Tag('快用完', fg: cWarn, bg: cWarnTint),
                  const SizedBox(width: 8),
                  Text('剩 ${s.left} 個',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                RadioGroup<String>(
                  groupValue: s.activeLotId,
                  onChanged: (v) {
                    s.activeLotId = v;
                    store.commit();
                    setState(() {});
                  },
                  child: Column(children: [
                    for (final l in s.lots)
                      RadioListTile<String>(
                        value: l.id,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${l.date} 買 ${l.qty} 個 HK\$ ${fmt(l.totalCents)} · 每個 \$${fmt(l.costOf(1))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: Text(
                          '剩 ${l.left}${l.id == s.activeLotId ? ' · 正在用' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Card2(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('買了新一批',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const FieldLabel('材料名稱'),
            TextField(
              controller: name,
              decoration: const InputDecoration(hintText: '例如：硬卡夾'),
            ),
            if (store.supplies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 6, children: [
                  for (final s in store.supplies)
                    ActionChip(
                      label: Text(s.name),
                      onPressed: () => setState(() => name.text = s.name),
                    ),
                ]),
              ),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('數量'),
                  TextField(
                    controller: qty,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('總價 HK\$'),
                  TextField(
                    controller: total,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              unit == null ? '只填數量和總價，會自動算出每個多少錢。' : '每個 HK\$ ${fmt(unit)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || q == null || q <= 0 || t == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請填材料名稱、數量和總價')));
                  return;
                }
                store.addLot(name.text.trim(), q, t, today());
                name.clear();
                qty.clear();
                total.clear();
                setState(() {});
              },
              child: const Text('加入庫存'),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('買包材時會在記帳的「郵包」記一筆支出。打包用掉時只算進利潤，不會重複記帳。',
            style: TextStyle(fontSize: 12, color: cSub)),
      ]),
    );
  }
}
