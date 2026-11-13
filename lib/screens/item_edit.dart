import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import 'sale_page.dart';
import '../models.dart';
import '../ui.dart';
import 'batch_page.dart';
import 'copies_page.dart';
import 'inventory.dart';
import 'photo.dart';

class ItemEditPage extends StatefulWidget {
  const ItemEditPage(this.itemId, {super.key});
  final String itemId;
  @override
  State<ItemEditPage> createState() => _ItemEditPageState();
}

class _ItemEditPageState extends State<ItemEditPage> {
  late final Item item = store.items.firstWhere((i) => i.id == widget.itemId);
  late final name = TextEditingController(text: item.name);
  late final source = TextEditingController(text: item.source);
  late final note = TextEditingController(text: item.note);

  void _save() {
    item
      ..name = name.text.trim()
      ..source = source.text.trim()
      ..note = note.text.trim();
    store.updateItem(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final b = store.batchOf(item.batchId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('周邊'),
        actions: [
          IconButton(
            tooltip: '刪除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirm(context, '刪除這件周邊？', '「${item.name}」會被刪除，不能復原。', ok: '刪除')) {
                store.deleteItem(item);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        PhotoBox(item.id),
        const SizedBox(height: 8),
        Card2(
          onTap: b == null ? null : () => openBatch(context, b.id),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('成本（由入手批次分攤）',
                    style: TextStyle(fontSize: 12, color: cSub)),
                const SizedBox(height: 4),
                Text(
                  item.costCents == null
                      ? '成本不明'
                      : '${item.costKind == CostKind.approx ? '≈ ' : ''}HK\$ ${fmt(item.costCents!)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (b != null)
                  Text('批次：${b.name}', style: const TextStyle(fontSize: 12, color: cSub)),
              ]),
            ),
            const Text('改成本 ›',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cAccent)),
          ]),
        ),
        const SizedBox(height: 8),
        if (b != null && b.overseas) ...[
          ArrivedPill(b, onChanged: () => setState(() {})),
          const SizedBox(height: 8),
        ],
        if (store.saleOf(item.saleId) case final s?)
          Card2(
            child: Row(children: [
              Expanded(
                child: Text(
                  '已售出 · ${s.platform} · ${s.date}\n'
                  '實收 HK\$ ${fmt(item.soldCents ?? 0)}'
                  ' · 利潤 ${fmt((item.soldCents ?? 0) - (item.costCents ?? 0))}'
                  '${item.costCents == null ? '（成本不明，當 0）' : ''}'
                  ' · 郵包 ${fmt(s.postNet)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (await confirm(context, '取消這次成交？', '周邊會回到待售，相關的帳也會移除。',
                      ok: '取消成交')) {
                    store.undoSale(s);
                    setState(() {});
                  }
                },
                child: const Text('取消成交'),
              ),
            ]),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => SalePage([item.id])));
              setState(() {});
            },
            icon: const Icon(Icons.sell_outlined),
            label: const Text('記錄成交'),
          ),
        const SizedBox(height: 8),
        if (item.category == '小卡' && item.status != '已售出')
          _CardQty(item, onChanged: () => setState(() {}))
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => CopiesPage(item.id))),
            icon: const Icon(Icons.library_add_outlined),
            label: const Text('我有幾件一樣的：同款加幾件'),
          ),
        const FieldLabel('名稱'),
        TextField(controller: name),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('成員'),
              PickField(
                value: item.member,
                options: {...store.members, item.member}.toList(),
                onChanged: (v) => setState(() => item.member = v),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('類別'),
              PickField(
                value: item.category,
                options: {...kCategories, item.category}.toList(),
                onChanged: (v) => setState(() => item.category = v),
              ),
            ]),
          ),
        ]),
        const FieldLabel('狀態'),
        Wrap(spacing: 8, children: [
          // 「已售出」只能由記錄成交產生，這裡只切換待售和已預留。
          for (final s in kStatuses.where((s) => s != '已售出' || item.status == s))
            ChoiceChip(
              label: Text(s),
              selected: item.status == s,
              onSelected: (_) => setState(() => item.status = s),
            ),
        ]),
        const FieldLabel('出處（哪張專輯、特典、活動）'),
        TextField(controller: source),
        const FieldLabel('備註'),
        TextField(controller: note, maxLines: 3),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('儲存'),
        ),
      ]),
    );
  }
}

/// 小卡的數量：直接加減同款的張數。加的那張成本不明，要填價錢就點那一張進去改。
class _CardQty extends StatelessWidget {
  const _CardQty(this.item, {required this.onChanged});
  final Item item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final copies = store.copiesOf(item);
    final n = copies.length;
    // 減的時候拿走最新加、還沒放進盤的那張（不會是正在看的這張）。
    final removable = copies.reversed
        .where((i) => i.id != item.id && store.planOf(i.id) == null)
        .toList();
    return Card2(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(children: [
        const Expanded(
          child: Text('數量（同款小卡）',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: '少一張',
          onPressed: removable.isEmpty
              ? null
              : () async {
                  final x = removable.first;
                  final ok = await confirm(
                      context,
                      '少一張？',
                      '會移除最後加的那一張'
                          '${x.costCents == null ? '' : '（成本 HK\$ ${fmt(x.costCents!)}）'}。',
                      ok: '移除');
                  if (!ok) return;
                  store.deleteItem(x);
                  onChanged();
                },
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 32,
          child: Text('$n',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: '多一張',
          onPressed: () {
            store.addCopy(item);
            onChanged();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('已加一張。價錢不同的話，在庫存點那一行，再點新的那張補價錢')));
          },
          icon: const Icon(Icons.add_circle_outline),
        ),
      ]),
    );
  }
}
