import 'package:flutter/material.dart';

import '../core/money.dart';
import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'crop_page.dart';
import 'item_edit.dart';

/// 建立系列：名稱、出處，以及每個卡位是哪位成員（也定下順序）。
class SeriesFormPage extends StatefulWidget {
  const SeriesFormPage({super.key});
  @override
  State<SeriesFormPage> createState() => _SeriesFormPageState();
}

class _SeriesFormPageState extends State<SeriesFormPage> {
  final name = TextEditingController();
  final source = TextEditingController();
  late final slots = store.members.where((m) => m != '團體').toList();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('新系列')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          const FieldLabel('系列名稱'),
          TextField(
            controller: name,
            decoration: const InputDecoration(hintText: '例如：19.99 隨機小卡'),
          ),
          const FieldLabel('出處（可不填）'),
          TextField(controller: source),
          FieldLabel('卡位（共 ${slots.length} 張，按順序）'),
          for (var k = 0; k < slots.length; k++)
            Row(children: [
              SizedBox(width: 28, child: Text('${k + 1}')),
              Expanded(
                child: PickField(
                  value: slots[k],
                  options: {...store.members, slots[k]}.toList(),
                  onChanged: (v) => setState(() => slots[k] = v),
                ),
              ),
              IconButton(
                tooltip: '移除這個卡位',
                onPressed: slots.length == 1 ? null : () => setState(() => slots.removeAt(k)),
                icon: const Icon(Icons.close),
              ),
            ]),
          OutlinedButton.icon(
            onPressed: () => setState(() => slots.add(store.members.first)),
            icon: const Icon(Icons.add),
            label: const Text('加一個卡位'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              if (name.text.trim().isEmpty) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('請填系列名稱')));
                return;
              }
              store.addSeries(Series(
                id: store.newId(),
                name: name.text.trim(),
                source: source.text.trim(),
                members: List.of(slots),
              ));
              Navigator.pop(context);
            },
            child: const Text('建立系列'),
          ),
        ]),
      );
}

class SeriesPage extends StatelessWidget {
  const SeriesPage(this.seriesId, {super.key});
  final String seriesId;

  Future<void> _fill(BuildContext context, Series s, int slot) async {
    final member = s.members[slot];
    final cands = store.items
        .where((i) => i.seriesId == null && i.member == member)
        .toList();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: Icon(s.wish[slot] ? Icons.favorite : Icons.favorite_border),
            title: Text(s.wish[slot] ? '移出心願' : '加入心願'),
            onTap: () {
              store.toggleWish(s, slot);
              Navigator.pop(c);
            },
          ),
          const Divider(height: 1),
          if (cands.isEmpty)
            ListTile(title: Text('庫存裡沒有未歸入系列的 $member 周邊'))
          else
            for (final i in cands)
              ListTile(
                leading: ItemThumb(i.member, i.category, size: 40, photo: store.photos[i.id]),
                title: Text('把「${i.name}」放進這格'),
                onTap: () {
                  i
                    ..seriesId = s.id
                    ..slot = slot;
                  if (s.wish[slot]) s.wish[slot] = false;
                  store.updateItem(i);
                  Navigator.pop(c);
                },
              ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.seriesOf(seriesId)!;
          final its = store.itemsOfSeries(s.id);
          Item? at(int slot) {
            for (final i in its) {
              if (i.slot == slot) return i;
            }
            return null;
          }

          final known = its.where((i) => i.costCents != null);
          final cost = known.fold<int>(0, (a, i) => a + i.costCents!);
          final unknown = its.length - known.length;
          return Scaffold(
            appBar: AppBar(title: Text(s.name)),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '${s.source.isEmpty ? '' : '出處：${s.source} · '}共 ${s.members.length} 張',
                    style: const TextStyle(fontSize: 13, color: cSub),
                  ),
                ),
                Text('已收 ${its.length} / ${s.members.length}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
                children: [
                  for (var k = 0; k < s.members.length; k++)
                    if (at(k) case final i?)
                      Card2(
                        padding: const EdgeInsets.all(6),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ItemEditPage(i.id))),
                        child: Column(children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCE5FB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: store.photos[i.id] == null
                                  ? null
                                  : Image.memory(store.photos[i.id]!,
                                      fit: BoxFit.cover, gaplessPlayback: true),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(s.members[k],
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Tag.status(i.status),
                        ]),
                      )
                    else
                      Material(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: cSub, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _fill(context, s, k),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(s.wish[k] ? '心願中' : '未收',
                                  style: const TextStyle(fontSize: 12, color: cSub)),
                              const SizedBox(height: 6),
                              Text(s.members[k],
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              const Text('點一下',
                                  style: TextStyle(fontSize: 11, color: cAccent)),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
              if (its.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final cut = await cropMany(context,
                          count: s.members.length, labels: s.members);
                      if (cut == null) return;
                      // 第 k 格的相片給第 k 個卡位；還沒收的卡位略過。
                      for (var k = 0; k < s.members.length && k < cut.length; k++) {
                        final i = at(k);
                        if (i != null) await store.setPhoto(i.id, cut[k]);
                      }
                    },
                    icon: const Icon(Icons.grid_on),
                    label: const Text('一張大圖切開，按卡位順序放相片'),
                  ),
                ),
              const SizedBox(height: 12),
              Card2(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('系列帳目',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '收卡成本合計 HK\$ ${fmt(cost)}${unknown > 0 ? ' + $unknown 張不明' : ''}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ]),
              ),
            ]),
          );
        },
      );
}
