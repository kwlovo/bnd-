import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../ui.dart';
import 'backup.dart';
import 'batch_page.dart';
import 'bundle_page.dart';
import 'cut_add_page.dart';
import 'image_search.dart';
import 'poster_page.dart';
import 'item_edit.dart';
import 'item_form.dart';
import 'old_cards.dart';
import 'plan_page.dart';
import 'series_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String q = '';
  String member = '全部';
  String category = '全部物品';
  String status = '全部';

  /// 單卡和系列分開兩個檢視，避免混在一起。
  bool showSeries = false;

  bool _match(Item i) {
    if (member != '全部' && i.member != member) return false;
    if (category != '全部物品' && i.category != category) return false;
    if (status == '成本不明') {
      if (i.costCents != null) return false;
    } else if (status == '未到貨') {
      if (!store.notArrived(i)) return false;
    } else if (status == '運費未補') {
      if (!store.intlUnpaid(i)) return false;
    } else if (status == '全部') {
      // 「全部」不包括已售出；要看已售出，點「已售出」那個按鈕。
      if (i.status == '已售出') return false;
    } else if (i.status != status) {
      return false;
    }
    if (q.isNotEmpty) {
      final s = store.seriesOf(i.seriesId)?.name ?? '';
      final b = store.batchOf(i.batchId)?.name ?? '';
      final hay = '${store.titleOf(i)} ${i.name} ${i.member} ${i.source} $s $b ${i.note}'.toLowerCase();
      if (!hay.contains(q.toLowerCase())) return false;
    }
    return true;
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _addMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_shopping_cart),
            title: const Text('新買的'),
            subtitle: const Text('單買，或一批一個總價（捆物／盤收）'),
            onTap: () {
              Navigator.pop(c);
              _push(const ItemFormPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('舊卡快速入庫'),
            subtitle: const Text('以前收的，不記得價錢也可以'),
            onTap: () {
              Navigator.pop(c);
              _push(const OldCardsPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.grid_on),
            title: const Text('大圖切開入庫'),
            subtitle: const Text('一張圖切成多份，再逐份填名字'),
            onTap: () {
              Navigator.pop(c);
              startCutAdd(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.all_inbox_outlined),
            title: const Text('盤出'),
            subtitle: const Text('勾選多件，打包成一個價賣出'),
            onTap: () {
              Navigator.pop(c);
              _push(const BundlePage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('出物圖'),
            subtitle: const Text('勾選周邊、填價錢，生成一張圖'),
            onTap: () {
              Navigator.pop(c);
              _push(const PosterPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.grid_view),
            title: const Text('新系列'),
            subtitle: const Text('一套卡，例如 6 張隨機小卡'),
            onTap: () {
              Navigator.pop(c);
              _push(const SeriesFormPage());
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
          final all = store.items;
          final unknown = all.where((i) => i.costCents == null).length;
          final onSale = all.where((i) => i.status == '待售').length;
          final soldN = all.where((i) => i.status == '已售出').length;
          final overdue = store.backupOverdueDays(DateTime.now());
          final waiting = all.where(store.notArrived).length;
          final unpaidShip = all.where(store.intlUnpaid).length;
          // 按成員年紀順序排（Sungho、Riwoo、Jaehyun…），同一位成員裡新的在前。
          final shown = all.where(_match).toList()
            ..sort((a, b) {
              final r = store.memberRank(a.member).compareTo(store.memberRank(b.member));
              return r != 0 ? r : b.createdAt.compareTo(a.createdAt);
            });
          // 「單卡」列出每一件（包括屬於系列的）；「系列」只列系列卡片。
          final loose = showSeries ? <Item>[] : shown;
          final seriesCards = showSeries
              ? store.series
                  .where((s) => q.isEmpty || s.name.toLowerCase().contains(q.toLowerCase()))
                  .toList()
              : <Series>[];

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('庫存',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    Text(
                        '未出 ${all.length - soldN} 件（待售 $onSale）· 已售出 $soldN 件'
                        '${waiting > 0 ? ' · 未到貨 $waiting 件' : ''}',
                        style: const TextStyle(fontSize: 13, color: cSub)),
                  ]),
                ),
                IconButton(
                  tooltip: '備份和設定',
                  onPressed: () => _push(const BackupPage()),
                  icon: const Icon(Icons.settings_outlined),
                ),
                FilledButton.icon(
                  onPressed: _addMenu,
                  icon: const Icon(Icons.add),
                  label: const Text('新增／盤出'),
                ),
                const SizedBox(width: 8),
              ]),
            ),
            // 太久沒備份就提醒；資料只存在這部手機，沒備份丟了就找不回。
            if (overdue != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: cWarnTint,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _push(const BackupPage()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            store.lastBackup.isEmpty
                                ? '還沒備份過，資料只存在這部手機'
                                : '已經 $overdue 天沒備份',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: cWarn),
                          ),
                        ),
                        const Text('去備份 ›', style: TextStyle(fontSize: 13, color: cWarn)),
                      ]),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '搜尋名稱、系列、出處、批次',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: '用圖片找',
                    onPressed: () => _push(const ImageSearchPage()),
                    icon: const Icon(Icons.image_search),
                  ),
                ),
                onChanged: (v) => setState(() => q = v.trim()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text('單卡 ${all.length - soldN}')),
                  ButtonSegment(value: true, label: Text('系列 ${store.series.length}')),
                ],
                selected: {showSeries},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => showSeries = s.first),
              ),
            ),
            if (!showSeries) ...[
            ChipRow(
              options: ['全部', ...store.members],
              value: member,
              onChanged: (v) => setState(() => member = v),
            ),
            ChipRow(
              options: const ['全部物品', ...kCategories],
              value: category,
              onChanged: (v) => setState(() => category = v),
            ),
            ChipRow(
              // 有未到貨的就排到最前面，免得忘記。
              options: [
                '全部',
                if (waiting > 0) '未到貨',
                if (unpaidShip > 0 || status == '運費未補') '運費未補',
                '待售',
                '已預留',
                '已售出',
                '成本不明',
                if (waiting == 0) '未到貨',
              ],
              labels: {
                '成本不明': '成本不明 $unknown',
                '未到貨': '未到貨 $waiting',
                '運費未補': '運費未補 $unpaidShip',
              },
              value: status,
              onChanged: (v) => setState(() => status = v),
            ),
            // 深藍的「盤出」橫條，和草圖一樣放在清單上面。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Material(
                color: cNavy,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _push(const BundlePage()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Expanded(
                        child: Text('盤出',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      Text('勾選多件，一個價賣出 ›',
                          style: TextStyle(fontSize: 13, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
            // 已存起來、還沒賣出的盤。
            if (store.plans.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Material(
                  color: cAccentTint,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _push(const PlansPage()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '還沒出的盤 ${store.plans.length} 個'
                            '${store.plans.any((p) => p.depositPaid) ? '（${store.plans.where((p) => p.depositPaid).length} 個已收定金）' : ''}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: cNavy),
                          ),
                        ),
                        const Text('查看 ›', style: TextStyle(fontSize: 13, color: cNavy)),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
            Expanded(
              child: (loose.isEmpty && seriesCards.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          showSeries
                              ? '還沒有系列。新增周邊時填系列名，或按「新增」›「新系列」。'
                              : all.isEmpty
                                  ? '還沒有周邊。按右上角「新增」開始。'
                                  : '沒有符合篩選的周邊。',
                          style: const TextStyle(color: cSub),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        for (final s in seriesCards) ...[
                          _SeriesCard(s, onTap: () => _push(SeriesPage(s.id))),
                          const SizedBox(height: 8),
                        ],
                        for (final i in loose) ...[
                          ItemTile(i, onTap: () => _push(ItemEditPage(i.id))),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ]);
        },
      );
}

class ItemTile extends StatelessWidget {
  const ItemTile(this.item, {super.key, this.onTap});
  final Item item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = store.batchOf(item.batchId);
    // 有品相的（例如娃娃）放最前面，同一位成員有幾件時方便分辨。
    final cond = item.note.startsWith('品相：') ? item.note.split('\n').first : '';
    final sub = [
      if (cond.isNotEmpty) cond,
      if (item.source.isNotEmpty) item.source,
      if (b != null) b.name,
    ].join(' · ');
    return Card2(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        ItemThumb(item.member, item.category, photo: store.photos[item.id]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(store.titleOf(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Tag.status(item.status),
              if (store.notArrived(item)) ...[
                const SizedBox(width: 4),
                const Tag('未到貨', fg: cWarn, bg: cWarnTint),
              ],
              if (store.intlUnpaid(item)) ...[
                const SizedBox(width: 4),
                const Tag('運費未補', fg: cWarn, bg: Colors.white, dashed: true),
              ],
              if (store.planOf(item.id) != null) ...[
                const SizedBox(width: 4),
                const Tag('在盤裡'),
              ],
            ]),
            if (sub.isNotEmpty)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: cSub)),
          ]),
        ),
        const SizedBox(width: 8),
        costLabel(item),
      ]),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard(this.s, {required this.onTap});
  final Series s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final its = store.itemsOfSeries(s.id);
    Item? at(int slot) {
      for (final i in its) {
        if (i.slot == slot) return i;
      }
      return null;
    }

    final got = [for (var k = 0; k < s.members.length; k++) at(k)];
    final have = got.where((i) => i != null).length;
    int n(String st) => got.where((i) => i?.status == st).length;
    Color bar(Item? i) => switch (i?.status) {
          null => Colors.transparent,
          '待售' => cAccent,
          '已售出' => cGood,
          _ => cWarn,
        };
    return Card2(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(s.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          const Tag('系列'),
        ]),
        const SizedBox(height: 4),
        Text(
          '已收 $have / ${s.members.length} · 待售 ${n('待售')} · 已預留 ${n('已預留')} · 已售 ${n('已售出')}',
          style: const TextStyle(fontSize: 13, color: cSub),
        ),
        const SizedBox(height: 8),
        Row(children: [
          for (var k = 0; k < got.length; k++) ...[
            if (k > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: bar(got[k]),
                  borderRadius: BorderRadius.circular(4),
                  border: got[k] == null ? Border.all(color: cSub) : null,
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// 從其他頁面打開批次詳情用。
void openBatch(BuildContext context, String batchId) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => BatchPage(batchId)));
