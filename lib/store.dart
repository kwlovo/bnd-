import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/money.dart';
import 'models.dart';
import 'models2.dart';

/// 全部資料存在本機，整份以 JSON 儲存；備份就是匯出這份 JSON。
class Store extends ChangeNotifier {
  static const _key = 'merch_app_data_v1';

  final List<Item> items = [];
  final List<Batch> batches = [];
  final List<Series> series = [];
  final List<Sale> sales = [];
  final List<ManualEntry> manual = [];
  final List<Supply> supplies = [];
  final List<Group> groups = [];

  /// 已存起來、還沒賣出的盤。
  final List<Plan> plans = [];

  Plan? planOf(String itemId) => _find(plans, (p) => p.itemIds.contains(itemId));

  /// 儲存盤。收了定金，盤裡的周邊會變成「已預留」；沒收就是「待售」。
  void savePlan(Plan p) {
    if (!plans.contains(p)) plans.add(p);
    for (final i in items.where((i) => p.itemIds.contains(i.id) && i.status != '已售出')) {
      i.status = p.depositPaid ? '已預留' : '待售';
    }
    commit();
  }

  /// 取消盤：周邊回到待售。
  void deletePlan(Plan p) {
    plans.remove(p);
    for (final i in items.where((i) => p.itemIds.contains(i.id) && i.status == '已預留')) {
      i.status = '待售';
    }
    commit();
  }

  /// 周邊賣掉或刪除後，從盤裡拿走；盤空了就移除。
  void _dropFromPlans(Iterable<String> ids) {
    for (final p in plans) {
      p.itemIds.removeWhere(ids.contains);
    }
    plans.removeWhere((p) => p.itemIds.isEmpty);
  }

  /// 打包組合：名稱 → [{supplyId, qty}]
  Map<String, List<Map<String, dynamic>>> presets = {};
  Map<String, String> templates = Map.of(kDefaultTemplates);
  List<String> members = List.of(kDefaultMembers);
  Map<String, double> rates = {'HKD': 1, 'RMB': 1.08};

  final _rand = Random();
  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

  // ---------- 備份提醒 ----------

  /// 上次備份的日期（yyyy-MM-dd），沒備份過是空字串。
  String lastBackup = '';

  /// 第一次打開 app 的日期，用來算「從沒備份過」多久了。
  String firstUse = '';

  /// 已經超過 7 天沒備份就返回天數，否則返回 null。沒有資料不提醒。
  int? backupOverdueDays(DateTime now, {bool? hasData}) {
    hasData ??= items.isNotEmpty || groups.isNotEmpty;
    final ref = lastBackup.isNotEmpty ? lastBackup : firstUse;
    if (!hasData || ref.isEmpty) return null;
    final from = DateTime.tryParse(ref);
    if (from == null) return null;
    final days = now.difference(from).inDays;
    return days > 7 ? days : null;
  }

  /// 剛備份完，記下今天。
  Future<void> markBackup() async {
    lastBackup = DateTime.now().toIso8601String().substring(0, 10);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('merch_last_backup', lastBackup);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    lastBackup = prefs.getString('merch_last_backup') ?? '';
    firstUse = prefs.getString('merch_first_use') ?? '';
    if (firstUse.isEmpty) {
      firstUse = DateTime.now().toIso8601String().substring(0, 10);
      await prefs.setString('merch_first_use', firstUse);
    }
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        importJson(raw, save: false);
      } catch (_) {
        // 讀不到就當作空白開始，不讓 app 打不開。
      }
    }
    try {
      await Hive.initFlutter();
      final box = _box = await Hive.openBox('photos');
      for (final k in box.keys) {
        final v = box.get(k);
        if (v is Uint8List) {
          photos['$k'] = v;
        } else if (v is List) {
          photos['$k'] = Uint8List.fromList(v.cast<int>());
        }
      }
      // 早期版本把相片放在小空間裡，搬過來。
      for (final k in prefs.getKeys().toList()) {
        if (!k.startsWith(_photoPrefix)) continue;
        try {
          final id = k.substring(_photoPrefix.length);
          final bytes = base64Decode(prefs.getString(k)!);
          await box.put(id, bytes);
          photos[id] = bytes;
        } catch (_) {
          // 壞掉的相片略過。
        }
        await prefs.remove(k);
      }
    } catch (_) {
      // 相片庫打不開時，其他功能照常用，只是沒有相片。
    }
  }

  // ---------- 周邊相片 ----------
  // 相片和主資料分開存（每件一格），主資料和備份文字才不會變得很大。

  static const _photoPrefix = 'merch_photo_';

  /// 相片庫（網頁版是瀏覽器的資料庫，iPhone 版是檔案），容量比主資料大得多。
  Box? _box;

  /// 周邊 id → 相片
  final Map<String, Uint8List> photos = {};

  /// 設定或移除（bytes 為 null）一件周邊的相片。成功返回 null，否則返回給用戶看的原因。
  Future<String?> setPhoto(String itemId, Uint8List? bytes) async {
    if (bytes == null) {
      if (photos.remove(itemId) == null) return null;
      notifyListeners();
      try {
        await _box?.delete(itemId);
      } catch (_) {}
      return null;
    }
    if (bytes.length > 600000) return '這張相片太大，請先裁小一點再試';
    try {
      await _box?.put(itemId, bytes);
    } catch (_) {
      return '相片存不進去，裝置的儲存空間可能滿了';
    }
    photos[itemId] = bytes;
    notifyListeners();
    return null;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, exportJson());
  }

  /// [withPhotos]：連周邊相片一起放進去（檔案會大很多，只適合存成檔案）。
  String exportJson({bool withPhotos = false}) => jsonEncode({
        'version': 2,
        if (withPhotos)
          'photos': {for (final e in photos.entries) e.key: base64Encode(e.value)},
        'items': [for (final i in items) i.toJson()],
        'batches': [for (final b in batches) b.toJson()],
        'series': [for (final s in series) s.toJson()],
        'sales': [for (final s in sales) s.toJson()],
        'manual': [for (final m in manual) m.toJson()],
        'supplies': [for (final s in supplies) s.toJson()],
        'groups': [for (final g in groups) g.toJson()],
        'plans': [for (final p in plans) p.toJson()],
        'presets': presets,
        'templates': templates,
        'members': members,
        'rates': rates,
      });

  /// 用備份內容取代目前全部資料。格式不對會拋出例外，原資料不變。
  void importJson(String raw, {bool save = true}) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    List l(String k) => (j[k] ?? []) as List;
    final ni = [for (final m in j['items'] as List) Item.fromJson(m)];
    // 舊版本的「自留」「準備盤」已取消，一律當作待售。
    for (final i in ni) {
      if (!kStatuses.contains(i.status)) i.status = '待售';
    }
    final nb = [for (final m in j['batches'] as List) Batch.fromJson(m)];
    final ns = [for (final m in l('series')) Series.fromJson(m)];
    final nsa = [for (final m in l('sales')) Sale.fromJson(m)];
    final nm = [for (final m in l('manual')) ManualEntry.fromJson(m)];
    final nsu = [for (final m in l('supplies')) Supply.fromJson(m)];
    final ng = [for (final m in l('groups')) Group.fromJson(m)];
    items..clear()..addAll(ni);
    batches..clear()..addAll(nb);
    series..clear()..addAll(ns);
    sales..clear()..addAll(nsa);
    manual..clear()..addAll(nm);
    supplies..clear()..addAll(nsu);
    groups..clear()..addAll(ng);
    if (j['members'] != null) members = List<String>.from(j['members']);
    for (final g in groups) {
      sortSlots(g);
    }
    final np2 = [for (final m in l('plans')) Plan.fromJson(m)];
    plans..clear()..addAll(np2);
    presets = {
      for (final e in ((j['presets'] ?? {}) as Map).entries)
        e.key as String: [for (final m in e.value as List) Map<String, dynamic>.from(m)],
    };
    templates = {...kDefaultTemplates, ...Map<String, String>.from(j['templates'] ?? const {})};
    if (j['members'] != null) members = List<String>.from(j['members']);
    if (j['rates'] != null) {
      rates = {
        for (final e in (j['rates'] as Map).entries)
          e.key as String: (e.value as num).toDouble(),
      };
      // 不再使用韓元；舊紀錄各自保存了當時的匯率，不受影響。
      rates.remove('KRW');
    }
    // 備份裡有相片才取代相片；沒有相片的文字備份不會動到現有相片。
    if (j['photos'] is Map) {
      final np = <String, Uint8List>{};
      for (final e in (j['photos'] as Map).entries) {
        try {
          np['${e.key}'] = base64Decode(e.value as String);
        } catch (_) {
          // 壞掉的相片略過。
        }
      }
      photos
        ..clear()
        ..addAll(np);
      _savePhotos(np);
    }
    if (save) commit();
  }

  Future<void> _savePhotos(Map<String, Uint8List> all) async {
    try {
      await _box?.clear();
      await _box?.putAll(all);
    } catch (_) {}
  }

  /// 通知畫面更新並存檔。
  void commit() {
    notifyListeners();
    _save();
  }

  // ---------- 查找 ----------

  T? _find<T>(Iterable<T> list, bool Function(T) test) {
    for (final x in list) {
      if (test(x)) return x;
    }
    return null;
  }

  Batch? batchOf(String id) => _find(batches, (b) => b.id == id);
  Series? seriesOf(String? id) => _find(series, (s) => s.id == id);
  Sale? saleOf(String? id) => _find(sales, (s) => s.id == id);
  Supply? supplyOf(String id) => _find(supplies, (s) => s.id == id);
  Group? groupOf(String id) => _find(groups, (g) => g.id == id);
  Item? itemOf(String? id) => _find(items, (i) => i.id == id);

  /// 外網切卡買了但還沒到貨。
  bool notArrived(Item i) {
    final b = batchOf(i.batchId);
    return b != null && b.overseas && !b.arrived;
  }

  /// 外網切卡的國際運費還沒補。
  bool intlUnpaid(Item i) {
    final b = batchOf(i.batchId);
    return b != null && b.overseas && !b.intlPaid;
  }

  List<Item> itemsOfBatch(String batchId) =>
      items.where((i) => i.batchId == batchId).toList();
  List<Item> itemsOfSeries(String seriesId) =>
      items.where((i) => i.seriesId == seriesId).toList();

  /// 顯示用的名字：屬於系列的卡用「系列名 + 卡位編號」（編號即成員年紀順序），
  /// 否則用自己的名稱。
  String titleOf(Item i) {
    final s = seriesOf(i.seriesId);
    if (s == null || i.slot == null) return i.name;
    return '${s.name} ${i.slot! + 1}';
  }

  /// 按名稱找系列，沒有就建一個（卡位按成員順序）。
  Series seriesNamed(String name) {
    final found = _find(series, (s) => s.name == name);
    if (found != null) return found;
    final s = Series(
      id: newId(),
      name: name,
      members: members.where((m) => m != '團體').toList(),
    );
    series.add(s);
    return s;
  }

  // ---------- 入手批次 ----------

  /// 按批次的總價和分攤方式，重算裡面每一件的成本。
  void recalc(String batchId) {
    final b = batchOf(batchId);
    if (b == null) return;
    final list = itemsOfBatch(batchId);
    if (list.isEmpty) return;
    final total = b.totalHkd;
    if (total == null) {
      for (final i in list) {
        // 批次忘了總價時，個別填過成本的件仍然保留。
        if (i.manualCents != null) {
          i.costCents = i.manualCents;
          i.costKind = CostKind.exact;
        } else {
          i.costCents = null;
          i.costKind = CostKind.unknown;
        }
      }
      return;
    }
    final List<int> shares;
    switch (b.method) {
      case AllocMethod.even:
        shares = allocateEven(total, list.length);
      case AllocMethod.byRef:
        shares = allocate(total, [for (final i in list) i.refCents ?? 0]);
      case AllocMethod.manual:
        shares = allocateWithFixed(total, [for (final i in list) i.manualCents]);
    }
    for (var k = 0; k < list.length; k++) {
      list[k].costCents = shares[k];
      list[k].costKind = b.approx ? CostKind.approx : CostKind.exact;
    }
  }

  void addBatchWithItems(Batch b, List<Item> newItems) {
    batches.add(b);
    items.addAll(newItems);
    recalc(b.id);
    commit();
  }

  void updateBatch(Batch b) {
    recalc(b.id);
    commit();
  }

  void updateItem(Item i) {
    recalc(i.batchId);
    commit();
  }

  void deleteItem(Item i) {
    final s = saleOf(i.saleId);
    if (s != null) {
      s.itemIds.remove(i.id);
      if (s.itemIds.isEmpty) sales.remove(s);
    }
    items.remove(i);
    _dropFromPlans([i.id]);
    setPhoto(i.id, null);
    if (itemsOfBatch(i.batchId).isEmpty) {
      batches.removeWhere((b) => b.id == i.batchId);
    } else {
      recalc(i.batchId);
    }
    commit();
  }

  // ---------- 包材 ----------

  int packCostOf(List<PackUse> uses) {
    var c = 0;
    for (final u in uses) {
      c += supplyOf(u.supplyId)?.lot(u.lotId)?.costOf(u.qty) ?? 0;
    }
    return c;
  }

  /// 從庫存扣掉（sign = 1）或加回（sign = -1）包材。
  void consume(List<PackUse> uses, int sign) {
    for (final u in uses) {
      final lot = supplyOf(u.supplyId)?.lot(u.lotId);
      if (lot != null) lot.used += sign * u.qty;
    }
  }

  /// 入貨：只填數量和總價，單價自動算。材料名不存在就新增。
  void addLot(String name, int qty, int totalCents, String date) {
    var s = _find(supplies, (x) => x.name == name);
    if (s == null) {
      s = Supply(id: newId(), name: name);
      supplies.add(s);
    }
    final lot = SupplyLot(id: newId(), date: date, qty: qty, totalCents: totalCents);
    s.lots.add(lot);
    s.activeLotId ??= lot.id;
    commit();
  }

  // ---------- 成交 ----------

  /// 記錄成交：周邊變「已售出」，實收分回每一件（單件就是全數）。
  void recordSale(Sale s) {
    final list = [for (final id in s.itemIds) items.firstWhere((i) => i.id == id)];
    final shares = s.fixed != null && s.fixed!.length == list.length
        ? allocateWithFixed(s.receivedHkd, s.fixed!)
        : s.even
            ? allocateEven(s.receivedHkd, list.length)
            : allocate(s.receivedHkd, [for (final i in list) i.costCents ?? 0]);
    for (var k = 0; k < list.length; k++) {
      list[k]
        ..status = '已售出'
        ..saleId = s.id
        ..soldCents = shares[k];
    }
    consume([for (final m in s.uses) PackUse.fromJson(m)], 1);
    _dropFromPlans(s.itemIds);
    sales.add(s);
    commit();
  }

  /// 取消成交：周邊回到待售，包材加回庫存，相關的帳自動消失。
  void undoSale(Sale s) {
    for (final i in items.where((i) => i.saleId == s.id)) {
      i
        ..status = '待售'
        ..saleId = null
        ..soldCents = null;
    }
    consume([for (final m in s.uses) PackUse.fromJson(m)], -1);
    sales.remove(s);
    commit();
  }

  void addManual(ManualEntry m) {
    manual.add(m);
    commit();
  }

  void deleteManual(String id) {
    manual.removeWhere((m) => m.id == id);
    commit();
  }

  // ---------- 拼團 ----------

  /// 自留位（或我跟的車的位）入庫存；已入庫的會更新成本。
  void syncGroupItems(Group g) {
    final arrived = g.steps.containsKey('到貨');
    final costs = g.slotCosts();
    for (var k = 0; k < g.slots.length; k++) {
      final s = g.slots[k];
      final mine = g.owner ? s.self : true;
      if (!mine) continue;
      // 跟車的成本 = 價格 + 我付給車主的郵費。
      final cost = g.owner ? costs[k] : s.price + s.postOut;
      final existing = itemOf(s.itemId);
      if (existing != null) {
        final b = batchOf(existing.batchId);
        if (b != null) {
          b.totalMinor = cost;
          recalc(b.id);
        }
      } else if (arrived) {
        final b = Batch(
          id: newId(),
          name: g.name,
          type: BatchType.single,
          date: g.steps['到貨'] ?? '',
          platform: g.platform,
          totalMinor: cost,
          inLedger: false, // 錢已經記在拼團的帳裡，不重複記。
        );
        final it = Item(
          id: newId(),
          name: g.owner ? '${s.member} ${g.category}' : g.name,
          member: s.member.isEmpty ? members.first : s.member,
          category: g.category,
          batchId: b.id,
          source: g.name,
          createdAt: DateTime.now().millisecondsSinceEpoch + k,
        );
        batches.add(b);
        items.add(it);
        recalc(b.id);
        s.itemId = it.id;
      }
    }
  }

  /// 車裡的位永遠按成員順序排（Sungho、Riwoo…），同一位成員的保持加入的先後。
  void sortSlots(Group g) {
    int rank(String m) {
      final k = members.indexOf(m);
      return k < 0 ? members.length : k;
    }

    final indexed = [for (var k = 0; k < g.slots.length; k++) (k, g.slots[k])];
    indexed.sort((a, b) {
      final r = rank(a.$2.member).compareTo(rank(b.$2.member));
      return r != 0 ? r : a.$1.compareTo(b.$1);
    });
    g.slots
      ..clear()
      ..addAll([for (final x in indexed) x.$2]);
  }

  void saveGroup(Group g) {
    if (!groups.contains(g)) groups.add(g);
    sortSlots(g);
    syncGroupItems(g);
    commit();
  }

  void deleteGroup(Group g) {
    for (final s in g.slots) {
      consume(s.uses, -1);
    }
    groups.remove(g);
    commit();
  }

  // ---------- 記帳 ----------

  /// 全部帳目，新到舊。由來源即時算出，所以來源改了帳也跟著改。
  List<LedgerEntry> ledger() {
    final out = <LedgerEntry>[];
    for (final b in batches) {
      final t = b.totalHkd;
      if (!b.inLedger || t == null) continue;
      out.add(LedgerEntry(b.date, '收卡', b.name, b.platform, -t));
    }
    for (final s in sales) {
      final names = [
        for (final i in items.where((i) => i.saleId == s.id)) titleOf(i),
      ].join('、');
      final sub = [s.platform, if (s.buyer.isNotEmpty) s.buyer].join(' · ');
      out.add(LedgerEntry(s.date, '出卡', names, sub, s.priceHkd));
      if (s.feeByMe && s.feeHkd > 0) {
        out.add(LedgerEntry(s.date, '手續費', '${s.platform} 手續費', names, -s.feeHkd));
      }
      if (s.postIn > 0) out.add(LedgerEntry(s.date, '郵包', '收郵費（${s.ship}）', names, s.postIn));
      if (s.postOut > 0) out.add(LedgerEntry(s.date, '郵包', '實付郵費（${s.ship}）', names, -s.postOut));
    }
    // 包材在買的時候記一筆；用掉時只算進利潤，不重複記帳。
    for (final su in supplies) {
      for (final l in su.lots) {
        out.add(LedgerEntry(l.date, '郵包', '買包材：${su.name} ×${l.qty}', '', -l.totalCents));
      }
    }
    for (final g in groups) {
      final d0 = g.steps['開團'] ?? '';
      if (g.owner) {
        for (final s in g.slots) {
          if (s.sold && s.paid) {
            out.add(LedgerEntry(s.paidDate.isEmpty ? d0 : s.paidDate, '拼團',
                '${s.member} 位全款', '${g.name} · ${s.buyer}', s.price));
          }
          if (s.sold && s.postInPaid && s.postIn > 0) {
            out.add(LedgerEntry(g.steps['到貨'] ?? d0, '郵包', '收郵費（${s.ship}）',
                '${g.name} · ${s.buyer}', s.postIn));
          }
          if (s.sold && s.sent && s.postOut > 0) {
            out.add(LedgerEntry(g.steps['寄出'] ?? g.steps['到貨'] ?? d0, '郵包',
                '實付郵費（${s.ship}）', '${g.name} · ${s.buyer}', -s.postOut));
          }
        }
        for (final c in g.costs.where((c) => c.actual)) {
          out.add(LedgerEntry(c.date.isEmpty ? d0 : c.date, '拼團', c.name, g.name, -c.hkd));
        }
        if (g.costMode == 'own' && g.steps.containsKey('下單')) {
          final own = g.slots.fold<int>(0, (a, s) => a + (s.ownCost ?? 0));
          if (own > 0) out.add(LedgerEntry(g.steps['下單']!, '拼團', '各位進價合計', g.name, -own));
        }
      } else {
        for (final s in g.slots.where((s) => s.paid)) {
          out.add(LedgerEntry(s.paidDate.isEmpty ? d0 : s.paidDate, '拼團',
              '${s.member} 位（跟車）', '${g.name} · ${g.leader}', -s.price));
        }
        // 跟車時我付給車主的郵費。
        for (final s in g.slots.where((s) => s.postOut > 0)) {
          out.add(LedgerEntry(g.steps['寄出'] ?? (s.paidDate.isEmpty ? d0 : s.paidDate),
              '拼團', '郵費（跟車）', '${g.name} · ${g.leader}', -s.postOut));
        }
      }
    }
    for (final m in manual) {
      out.add(LedgerEntry(m.date, '其他', m.desc, '手動記', m.cents, manualId: m.id));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  // ---------- 其他 ----------

  void addSeries(Series s) {
    series.add(s);
    commit();
  }

  void toggleWish(Series s, int slot) {
    s.wish[slot] = !s.wish[slot];
    commit();
  }

  void addMember(String name) {
    if (name.isEmpty || members.contains(name)) return;
    members.add(name);
    commit();
  }
}
