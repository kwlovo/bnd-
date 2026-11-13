import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models2.dart';
import '../ui.dart';
import 'supplies_page.dart';

/// 選這個包裹用了什麼包材。直接修改傳入的 [uses]，每次改動呼叫 [onChanged]。
class PackPicker extends StatefulWidget {
  const PackPicker({super.key, required this.uses, required this.onChanged});
  final List<PackUse> uses;
  final VoidCallback onChanged;
  @override
  State<PackPicker> createState() => _PackPickerState();
}

class _PackPickerState extends State<PackPicker> {
  PackUse? _use(String supplyId) {
    for (final u in widget.uses) {
      if (u.supplyId == supplyId) return u;
    }
    return null;
  }

  void _changed() {
    widget.uses.removeWhere((u) => u.qty <= 0);
    setState(() {});
    widget.onChanged();
  }

  void _step(Supply s, int d) {
    final u = _use(s.id);
    if (u == null) {
      final lot = s.defaultLot;
      if (lot == null || d < 0) return;
      widget.uses.add(PackUse(supplyId: s.id, lotId: lot.id, qty: 1));
    } else {
      u.qty += d;
    }
    _changed();
  }

  void _applyPreset(String name) {
    widget.uses.clear();
    for (final line in store.presets[name] ?? const []) {
      final s = store.supplyOf(line['supplyId']);
      final lot = s?.defaultLot;
      if (s == null || lot == null) continue;
      widget.uses.add(PackUse(supplyId: s.id, lotId: lot.id, qty: line['qty'] ?? 1));
    }
    _changed();
  }

  Future<void> _savePreset() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('存成打包組合'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(hintText: '例如：平郵小卡組合'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('儲存')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    store.presets[name.text.trim()] = [
      for (final u in widget.uses) {'supplyId': u.supplyId, 'qty': u.qty},
    ];
    store.commit();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final open = TextButton(
      onPressed: () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SuppliesPage()));
        setState(() {});
      },
      child: const Text('包材庫存 ›'),
    );
    if (store.supplies.isEmpty) {
      return Row(children: [
        const Expanded(
          child: Text('還沒有包材。先到包材庫存入貨，之後打包就能自動算成本。',
              style: TextStyle(fontSize: 12, color: cSub)),
        ),
        open,
      ]);
    }
    final total = store.packCostOf(widget.uses);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (store.presets.isNotEmpty)
        Wrap(spacing: 6, children: [
          for (final n in store.presets.keys)
            ActionChip(label: Text(n), onPressed: () => _applyPreset(n)),
        ]),
      for (final s in store.supplies)
        Builder(builder: (_) {
          final u = _use(s.id);
          final lots = s.lots.where((l) => l.left > 0 || l.id == u?.lotId).toList();
          final lot = s.lot(u?.lotId) ?? s.defaultLot;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.name}（剩 ${s.left}）', style: const TextStyle(fontSize: 13)),
                  if (u != null && lots.length > 1)
                    PickField(
                      value: u.lotId,
                      plain: true,
                      fontSize: 12,
                      label: '用哪一批',
                      options: [for (final l in lots) l.id],
                      labels: {
                        for (final l in lots)
                          l.id: '${l.date} 批 @\$${fmt(l.costOf(1))}（剩 ${l.left}）',
                      },
                      onChanged: (v) {
                        u.lotId = v;
                        _changed();
                      },
                    )
                  else if (lot != null)
                    Text('每個 \$${fmt(lot.costOf(1))}',
                        style: const TextStyle(fontSize: 12, color: cSub)),
                ]),
              ),
              IconButton(
                tooltip: '${s.name} 減少',
                onPressed: u == null ? null : () => _step(s, -1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 20,
                child: Text('${u?.qty ?? 0}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: '${s.name} 增加',
                onPressed: () => _step(s, 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
          );
        }),
      Row(children: [
        Expanded(
          child: Text('包材成本 HK\$ ${fmt(total)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        if (widget.uses.isNotEmpty)
          TextButton(onPressed: _savePreset, child: const Text('存成組合')),
        open,
      ]),
    ]);
  }
}
