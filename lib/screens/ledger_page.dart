import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'item_form.dart' show today;
import 'quick_sale.dart';

/// 記帳：大部分由批次和成交自動產生，也可以手動記一筆。
class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String category = '全部';

  String get ym => '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Future<void> _add() async {
    final desc = TextEditingController();
    final amount = TextEditingController();
    final date = TextEditingController(text: today());
    var income = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('記一筆'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('支出')),
                ButtonSegment(value: true, label: Text('收入')),
              ],
              selected: {income},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setD(() => income = v.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: desc, decoration: const InputDecoration(labelText: '描述')),
            const SizedBox(height: 8),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '金額 HK\$'),
            ),
            const SizedBox(height: 8),
            TextField(controller: date, decoration: const InputDecoration(labelText: '日期')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final cents = parseCents(amount.text);
                if (cents == null || desc.text.trim().isEmpty) return;
                store.addManual(ManualEntry(
                  id: store.newId(),
                  date: date.text.trim(),
                  desc: desc.text.trim(),
                  cents: income ? cents : -cents,
                ));
                Navigator.pop(c);
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final inMonth = store.ledger().where((e) => e.date.startsWith(ym)).toList();
          // 郵包單獨一格，不算進出卡收支。
          final main = inMonth.where((e) => e.category != '郵包');
          final income = main.where((e) => e.cents > 0).fold<int>(0, (a, e) => a + e.cents);
          final expense = main.where((e) => e.cents < 0).fold<int>(0, (a, e) => a - e.cents);
          final post = inMonth
              .where((e) => e.category == '郵包')
              .fold<int>(0, (a, e) => a + e.cents);
          final shown =
              inMonth.where((e) => category == '全部' || e.category == category).toList();
          String signed(int c) => '${c >= 0 ? '+' : '−'}HK\$ ${fmt(c.abs())}';
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                const Expanded(
                  child: Text('記帳',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                OutlinedButton(onPressed: _add, child: const Text('記一筆')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => showQuickSale(context),
                  icon: const Icon(Icons.sell_outlined),
                  label: const Text('記出卡'),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                    color: cAccentTint, borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: DefaultTextStyle(
                  style: const TextStyle(color: cInk),
                  child: Column(children: [
                    Row(children: [
                      IconButton(
                        tooltip: '上個月',
                        color: cAccent,
                        onPressed: () =>
                            setState(() => month = DateTime(month.year, month.month - 1)),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text('${month.year} 年 ${month.month} 月',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: '下個月',
                        color: cAccent,
                        onPressed: () =>
                            setState(() => month = DateTime(month.year, month.month + 1)),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ]),
                    Row(children: [
                      _tile('本月淨額', signed(income - expense)),
                      _tile('收入', 'HK\$ ${fmt(income)}'),
                      _tile('支出', 'HK\$ ${fmt(expense)}'),
                      _tile('郵包', signed(post)),
                    ]),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 6),
            ChipRow(
              options: const ['全部', '收卡', '出卡', '郵包', '手續費', '其他'],
              value: category,
              onChanged: (v) => setState(() => category = v),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(
                      child: Text('這個月沒有帳目。', style: TextStyle(color: cSub)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, k) {
                        final e = shown[k];
                        return Card2(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          onTap: e.quickId != null
                              ? () => showQuickSale(context,
                                  existing: store.quick.firstWhere((q) => q.id == e.quickId))
                              : e.manualId == null
                              ? null
                              : () async {
                                  if (await confirm(context, '刪除這筆帳？', '「${e.title}」會被刪除。',
                                      ok: '刪除')) {
                                    store.deleteManual(e.manualId!);
                                  }
                                },
                          child: Row(children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                e.date.length >= 10
                                    ? e.date.substring(5).replaceAll('-', '/')
                                    : e.date,
                                style: const TextStyle(fontSize: 12, color: cSub),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w700)),
                                    Text(
                                      [e.category, if (e.sub.isNotEmpty) e.sub].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: cSub),
                                    ),
                                  ]),
                            ),
                            Text(signed(e.cents),
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: e.cents >= 0 ? cGood : cInk)),
                          ]),
                        );
                      },
                    ),
            ),
          ]);
        },
      );

  Widget _tile(String label, String value) => Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}
