import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import '../models2.dart' show PackUse;
import 'item_form.dart' show today;
import 'pack_picker.dart';
import 'sale_page.dart' show PostageFields;

/// 快速記出卡：不用先把卡放進庫存，只記賣了多少、當初買成多少。
/// 給 [existing] 就是改那一筆。
Future<void> showQuickSale(BuildContext context, {QuickSale? existing}) =>
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => QuickSalePage(existing: existing)));

class QuickSalePage extends StatefulWidget {
  const QuickSalePage({super.key, this.existing});
  final QuickSale? existing;
  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class _QuickSalePageState extends State<QuickSalePage> {
  late final q = widget.existing;
  late final price = TextEditingController(text: q == null ? '' : fmt(q!.priceMinor));
  late final cost = TextEditingController(
      text: q?.costHkd == null ? '' : fmt(q!.costHkd!));
  late final desc = TextEditingController(text: q?.desc ?? '');
  late final date = TextEditingController(text: q?.date ?? today());
  late String platform = q?.platform ?? '';
  late String currency = q?.currency ?? 'HKD';

  // 寄卡：交收方式、郵費（HK$）、打包用了什麼。全部可以不填。
  late String ship = q?.ship ?? '';
  late final postIn =
      TextEditingController(text: (q?.postIn ?? 0) == 0 ? '' : fmt(q!.postIn));
  late final postOut =
      TextEditingController(text: (q?.postOut ?? 0) == 0 ? '' : fmt(q!.postOut));
  late final uses = [for (final m in q?.uses ?? const []) PackUse.fromJson(m)];

  double get rate =>
      q != null && q!.currency == currency ? q!.rate : (store.rates[currency] ?? 1);

  void _save() {
    final p = parseCents(price.text);
    if (p == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請填賣了多少')));
      return;
    }
    final x = q ??
        QuickSale(id: store.newId(), date: today(), priceMinor: 0);
    x
      ..date = date.text.trim().isEmpty ? today() : date.text.trim()
      ..desc = desc.text.trim()
      ..platform = platform
      ..priceMinor = p
      ..currency = currency
      ..rate = rate
      ..costHkd = parseCents(cost.text);
    final oldUses = List.of(x.uses);
    x
      ..ship = ship
      ..postIn = ship.isEmpty ? 0 : (parseCents(postIn.text) ?? 0)
      ..postOut = ship.isEmpty ? 0 : (parseCents(postOut.text) ?? 0)
      ..uses = [for (final u in uses) u.toJson()]
      ..pack = store.packCostOf(uses);
    store.saveQuick(x, oldUses: q == null ? const [] : oldUses);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = parseCents(price.text);
    final c = parseCents(cost.text);
    final got = p == null ? null : toHkd(p, rate);
    final earn = got == null ? null : got - (c ?? 0);
    const num = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(q == null ? '記出卡' : '改這筆出卡'),
        actions: [
          if (q != null)
            IconButton(
              tooltip: '刪除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, '刪除這筆出卡？', '這筆收入會從記帳和統計拿走。', ok: '刪除')) {
                  store.deleteQuick(q!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const Text('不用先把卡放進庫存，只記賣了多少、當初買成多少，就會算進出卡收入和利潤。',
            style: TextStyle(fontSize: 13, color: cSub)),
        const FieldLabel('賣了多少'),
        Row(children: [
          SizedBox(
            width: 110,
            child: PickField(
              value: currency,
              options: store.rates.keys.toList(),
              onChanged: (v) => setState(() => currency = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: price,
              autofocus: q == null,
              keyboardType: num,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        const FieldLabel('當初買成多少（HK\$，不記得就留空）'),
        TextField(
          controller: cost,
          keyboardType: num,
          decoration: const InputDecoration(prefixText: 'HK\$ '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (earn != null)
          Text(
            '${c == null ? '成本不明，當 0 算：' : ''}'
            '賺 ${earn >= 0 ? '' : '−'}HK\$ ${fmt(earn.abs())}',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: earn >= 0 ? cGood : cWarn),
          ),
        const SizedBox(height: 8),
        Card2(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('寄卡（可不填）',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Text('選了交收方式就會記郵費。郵費差價和包材算在「郵包」，和出卡收入分開。',
                style: TextStyle(fontSize: 12, color: cSub)),
            if (ship.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, children: [
                  for (final m in kShipMethods)
                    ActionChip(
                      label: Text(m),
                      onPressed: () => setState(() {
                        ship = m;
                        PostageFields.defaults(m, postIn, postOut);
                      }),
                    ),
                ]),
              )
            else ...[
              PostageFields(
                ship: ship,
                postIn: postIn,
                postOut: postOut,
                onShip: (v) => setState(() {
                  ship = v;
                  PostageFields.defaults(v, postIn, postOut);
                }),
                onChanged: () => setState(() {}),
              ),
              const FieldLabel('打包用了什麼'),
              PackPicker(uses: uses, onChanged: () => setState(() {})),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Builder(builder: (_) {
                    final net = (parseCents(postIn.text) ?? 0) -
                        (parseCents(postOut.text) ?? 0) -
                        store.packCostOf(uses);
                    return Text('郵包 ${net >= 0 ? '+' : '−'}HK\$ ${fmt(net.abs())}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: net >= 0 ? cGood : cWarn));
                  }),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    ship = '';
                    postIn.clear();
                    postOut.clear();
                    uses.clear();
                  }),
                  child: const Text('不記寄卡'),
                ),
              ]),
            ],
          ]),
        ),
        const FieldLabel('在哪裡賣（可不選）'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in kPlatforms)
            ChoiceChip(
              label: Text(x),
              selected: platform == x,
              showCheckmark: false,
              onSelected: (on) => setState(() {
                platform = on ? x : '';
                // 閒魚、小紅書收人民幣。
                if (on && (x == '閒魚' || x == '小紅書') && store.rates.containsKey('RMB')) {
                  currency = 'RMB';
                }
              }),
            ),
        ]),
        const FieldLabel('寫點什麼（可不填，例如賣了什麼）'),
        TextField(controller: desc),
        const FieldLabel('日期'),
        TextField(controller: date),
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
