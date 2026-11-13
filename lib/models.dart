/// 所有周邊預設都在出售，只是還沒出掉，所以沒有「自留」和「準備盤」。
const kStatuses = ['待售', '已預留', '已售出'];
const kCategories = ['小卡', '專輯', '官娃', '飯製娃', '海報', '應援物', '其他'];
const kDefaultMembers = [
  'Sungho', 'Riwoo', 'Jaehyun', 'Taesan', 'Leehan', 'Woonhak', '團體',
];

/// 成本的可靠程度。
enum CostKind { exact, approx, unknown }

/// 批次總價怎樣分到每一件。
enum AllocMethod { even, byRef, manual }

/// 入手批次類型。
enum BatchType { single, bundle, old }

class Item {
  Item({
    required this.id,
    required this.name,
    required this.member,
    required this.category,
    this.status = '待售',
    required this.batchId,
    this.seriesId,
    this.slot,
    this.costCents,
    this.costKind = CostKind.unknown,
    this.refCents,
    this.manualCents,
    this.source = '',
    this.note = '',
    this.saleId,
    this.soldCents,
    required this.createdAt,
  });

  /// 成交紀錄；null = 還沒賣出。
  String? saleId;

  /// 這一件的實收（HKD 分，已扣自付手續費）。
  int? soldCents;

  final String id;
  String name;
  String member;
  String category;
  String status;
  String batchId;
  String? seriesId;
  int? slot;

  /// 分攤後的成本（HKD 分）；null = 成本不明。由批次自動計算。
  int? costCents;
  CostKind costKind;

  /// 參考市價（分），只用來決定按比例分攤時誰分多一點。
  int? refCents;

  /// 手動分攤時使用者填的成本（分）。
  int? manualCents;
  String source;
  String note;
  final int createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'member': member,
        'category': category,
        'status': status,
        'batchId': batchId,
        'seriesId': seriesId,
        'slot': slot,
        'costCents': costCents,
        'costKind': costKind.name,
        'refCents': refCents,
        'manualCents': manualCents,
        'source': source,
        'note': note,
        'saleId': saleId,
        'soldCents': soldCents,
        'createdAt': createdAt,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        name: j['name'],
        member: j['member'],
        category: j['category'],
        status: j['status'] ?? '待售',
        batchId: j['batchId'],
        seriesId: j['seriesId'],
        slot: j['slot'],
        costCents: j['costCents'],
        costKind: CostKind.values.byName(j['costKind'] ?? 'unknown'),
        refCents: j['refCents'],
        manualCents: j['manualCents'],
        source: j['source'] ?? '',
        note: j['note'] ?? '',
        saleId: j['saleId'],
        soldCents: j['soldCents'],
        createdAt: j['createdAt'] ?? 0,
      );
}

const kPlatforms = ['閒魚', '小紅書', 'IG', 'Carousell', 'WhatsApp', 'Threads'];
const kShipMethods = ['平郵', '易寄取', '順豐', '面交'];

/// 一次成交。郵費和包材另算「郵包」，不混進出卡收支。
class Sale {
  Sale({
    required this.id,
    required this.itemIds,
    required this.date,
    required this.platform,
    required this.priceMinor,
    this.currency = 'HKD',
    this.rate = 1,
    this.feeMinor = 0,
    this.feeByMe = false,
    this.buyer = '',
    this.ship = '平郵',
    this.postIn = 0,
    this.postOut = 0,
    this.pack = 0,
    this.even = false,
    this.fixed,
    List<Map<String, dynamic>>? uses,
  }) : uses = uses ?? [];

  /// 盤出時自己填的每件收入（HKD 分，順序同 [itemIds]）；null 的件平分剩下的。
  List<int?>? fixed;

  /// 盤出時收入怎樣分回每件：false 按成本比例，true 平均分。
  bool even;

  /// 用了哪些包材（PackUse 的 JSON），取消成交時用來把包材加回庫存。
  List<Map<String, dynamic>> uses;

  final String id;
  List<String> itemIds;
  String date;
  String platform;
  int priceMinor;
  String currency;
  double rate;
  int feeMinor;
  bool feeByMe;
  String buyer;
  String ship;

  /// 向買家收的郵費、實付郵費、包材成本（HKD 分）。
  int postIn;
  int postOut;
  int pack;

  int get priceHkd => (priceMinor * rate).round();
  int get feeHkd => (feeMinor * rate).round();

  /// 實收：買家付手續費時等於成交價，我付時扣掉手續費。
  int get receivedHkd => priceHkd - (feeByMe ? feeHkd : 0);

  /// 郵包 = 郵費差價 − 包材。
  int get postNet => postIn - postOut - pack;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemIds': itemIds,
        'date': date,
        'platform': platform,
        'priceMinor': priceMinor,
        'currency': currency,
        'rate': rate,
        'feeMinor': feeMinor,
        'feeByMe': feeByMe,
        'buyer': buyer,
        'ship': ship,
        'postIn': postIn,
        'postOut': postOut,
        'pack': pack,
        'even': even,
        'fixed': fixed,
        'uses': uses,
      };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: j['id'],
        itemIds: List<String>.from(j['itemIds'] ?? const []),
        date: j['date'] ?? '',
        platform: j['platform'] ?? '',
        priceMinor: j['priceMinor'] ?? 0,
        currency: j['currency'] ?? 'HKD',
        rate: (j['rate'] ?? 1).toDouble(),
        feeMinor: j['feeMinor'] ?? 0,
        feeByMe: j['feeByMe'] ?? false,
        buyer: j['buyer'] ?? '',
        ship: j['ship'] ?? '平郵',
        postIn: j['postIn'] ?? 0,
        postOut: j['postOut'] ?? 0,
        pack: j['pack'] ?? 0,
        even: j['even'] ?? false,
        fixed: j['fixed'] == null ? null : List<int?>.from(j['fixed']),
        uses: [for (final m in (j['uses'] ?? []) as List) Map<String, dynamic>.from(m)],
      );
}

/// 手動記的一筆帳。[cents] 正數是收入，負數是支出。
class ManualEntry {
  ManualEntry({required this.id, required this.date, required this.desc, required this.cents});
  final String id;
  String date;
  String desc;
  int cents;

  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'desc': desc, 'cents': cents};
  factory ManualEntry.fromJson(Map<String, dynamic> j) =>
      ManualEntry(id: j['id'], date: j['date'] ?? '', desc: j['desc'] ?? '', cents: j['cents'] ?? 0);
}

/// 記帳頁的一行。由批次、成交和手動帳即時算出，不另外儲存，所以來源改了帳也跟著改。
class LedgerEntry {
  LedgerEntry(this.date, this.category, this.title, this.sub, this.cents, {this.manualId});
  final String date;
  final String category;
  final String title;
  final String sub;
  final int cents;
  final String? manualId;
}

class Batch {
  Batch({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    this.platform = '',
    this.seller = '',
    this.totalMinor,
    this.currency = 'HKD',
    this.rate = 1,
    this.approx = false,
    this.method = AllocMethod.even,
    this.inLedger = true,
    this.overseas = false,
    this.intlShip = 0,
    this.arrived = true,
    this.intlPaid = false,
  });

  /// 國際運費補了沒有；只有外網切卡才有意義。
  bool intlPaid;

  /// 外網切卡（Mercari、閃電市場等）：除了物品價格還要補國際運費，而且要等到貨。
  bool overseas;

  /// 國際運費（HKD 分），算進這批的總成本。
  int intlShip;

  /// 到貨了沒有；只有外網切卡會是 false。
  bool arrived;

  final String id;
  String name;
  BatchType type;

  /// yyyy-MM-dd；舊卡可以是空字串。
  String date;
  String platform;
  String seller;

  /// 原幣別總價（分）；null = 忘記了。
  int? totalMinor;
  String currency;

  /// 原幣別 → HKD 的匯率，儲存當時實際用的匯率。
  double rate;

  /// 總價只是大概。
  bool approx;
  AllocMethod method;

  /// 是否記入記帳（舊卡預設不記）。
  bool inLedger;

  int? get totalHkd =>
      totalMinor == null ? null : (totalMinor! * rate).round() + intlShip;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'date': date,
        'platform': platform,
        'seller': seller,
        'totalMinor': totalMinor,
        'currency': currency,
        'rate': rate,
        'approx': approx,
        'method': method.name,
        'inLedger': inLedger,
        'overseas': overseas,
        'intlShip': intlShip,
        'arrived': arrived,
        'intlPaid': intlPaid,
      };

  factory Batch.fromJson(Map<String, dynamic> j) => Batch(
        id: j['id'],
        name: j['name'],
        type: BatchType.values.byName(j['type'] ?? 'bundle'),
        date: j['date'] ?? '',
        platform: j['platform'] ?? '',
        seller: j['seller'] ?? '',
        totalMinor: j['totalMinor'],
        currency: j['currency'] ?? 'HKD',
        rate: (j['rate'] ?? 1).toDouble(),
        approx: j['approx'] ?? false,
        method: AllocMethod.values.byName(j['method'] ?? 'even'),
        inLedger: j['inLedger'] ?? true,
        overseas: j['overseas'] ?? false,
        intlShip: j['intlShip'] ?? 0,
        arrived: j['arrived'] ?? true,
        intlPaid: j['intlPaid'] ?? false,
      );
}

class Series {
  Series({
    required this.id,
    required this.name,
    this.source = '',
    required this.members,
    List<bool>? wish,
  }) : wish = wish ?? List.filled(members.length, false);

  final String id;
  String name;
  String source;

  /// 每個卡位是哪位成員，順序即卡位順序。
  List<String> members;

  /// 每個卡位是否已加入心願。
  List<bool> wish;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source,
        'members': members,
        'wish': wish,
      };

  factory Series.fromJson(Map<String, dynamic> j) => Series(
        id: j['id'],
        name: j['name'],
        source: j['source'] ?? '',
        members: List<String>.from(j['members'] ?? const []),
        wish: j['wish'] == null ? null : List<bool>.from(j['wish']),
      );
}
