import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'item_form.dart' show today;

class _Copy {
  final price = TextEditingController();
  final condition = TextEditingController();
}

/// 同款加幾張：同一個東西有很多張時，照著這件多建幾件。
/// 每張可以有自己的價錢（不記得就留空）和品相，不一定是新買的。
class CopiesPage extends StatefulWidget {
  const CopiesPage(this.itemId, {super.key});
  final String itemId;
  @override
  State<CopiesPage> createState() => _CopiesPageState();
}

class _CopiesPageState extends State<CopiesPage> {
  late final Item src = store.items.firstWhere((i) => i.id == widget.itemId);
  final copies = [_Copy()];

  /// 新買的要記入記帳；以前就有的不記，免得影響本月收支。
  bool newlyBought = false;
  bool copyPhoto = true;

  void _save() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final costs = [for (final c in copies) parseCents(c.price.text)];
    final allKnown = costs.every((c) => c != null);
    final b = Batch(
      id: store.newId(),
      name: '${store.titleOf(src)} 同款',
      type: copies.length == 1 ? BatchType.single : BatchType.bundle,
      date: newlyBought ? today() : '',
      // 全部填了價錢就用合計做總價；有留空的就當「忘記了總價」，填了的照填。
      totalMinor: allKnown ? costs.fold<int>(0, (a, c) => a + c!) : null,
      method: AllocMethod.manual,
      inLedger: newlyBought && allKnown,
    );
    final items = <Item>[
      for (var k = 0; k < copies.length; k++)
        Item(
          id: store.newId(),
          name: src.name,
          member: src.member,
          category: src.category,
          batchId: b.id,
          source: src.source,
          note: copies[k].condition.text.trim().isEmpty
              ? ''
              : '品相：${copies[k].condition.text.trim()}',
          manualCents: costs[k],
          createdAt: now + k,
        ),
    ];
    store.addBatchWithItems(b, items);
    final photo = store.photos[src.id];
    if (copyPhoto && photo != null) {
      for (final i in items) {
        store.setPhoto(i.id, photo);
      }
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已加入 ${items.length} 張同款')));
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = store.photos[src.id] != null;
    return Scaffold(
      appBar: AppBar(title: const Text('同款加幾張')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Card2(
          child: Row(children: [
            ItemThumb(src.member, src.category, size: 48, photo: store.photos[src.id]),
            const SizedBox(width: 12),
            Expanded(
              child: Text('照著「${store.titleOf(src)}」多加幾張一樣的。'
                  '每張可以填自己的價錢和品相，不記得價錢就留空。',
                  style: const TextStyle(fontSize: 13)),
            ),
          ]),
        ),
        FieldLabel('還有幾張（${copies.length}）'),
        for (var k = 0; k < copies.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 24, child: Text('${k + 1}')),
              SizedBox(
                width: 104,
                child: TextField(
                  controller: copies[k].price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '價錢', prefixText: 'HK\$ '),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: copies[k].condition,
                  decoration: const InputDecoration(hintText: '品相（可不填）'),
                ),
              ),
              IconButton(
                tooltip: '移除這張',
                onPressed:
                    copies.length == 1 ? null : () => setState(() => copies.removeAt(k)),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => copies.add(_Copy())),
          icon: const Icon(Icons.add),
          label: const Text('再加一張'),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: newlyBought,
          onChanged: (v) => setState(() => newlyBought = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('是新買的（記入記帳）'),
          subtitle: const Text('以前就有的不用勾，不會影響本月收支'),
        ),
        if (hasPhoto)
          CheckboxListTile(
            value: copyPhoto,
            onChanged: (v) => setState(() => copyPhoto = v ?? true),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('用同一張相片'),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('加入 ${copies.length} 張'),
        ),
      ]),
    );
  }
}
