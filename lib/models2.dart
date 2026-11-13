import 'core/money.dart';

/// 包材的一批入貨。單價 = 總價 ÷ 數量。
class SupplyLot {
  SupplyLot({required this.id, required this.date, required this.qty, required this.totalCents, this.used = 0});
  final String id;
  String date;
  int qty;
  int totalCents;
  int used;

  int get left => qty - used;
  int costOf(int n) => qty == 0 ? 0 : (n * totalCents / qty).round();

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date, 'qty': qty, 'totalCents': totalCents, 'used': used};
  factory SupplyLot.fromJson(Map<String, dynamic> j) => SupplyLot(
      id: j['id'], date: j['date'] ?? '', qty: j['qty'] ?? 0, totalCents: j['totalCents'] ?? 0, used: j['used'] ?? 0);
}

class Supply {
  Supply({required this.id, required this.name, List<SupplyLot>? lots, this.activeLotId})
      : lots = lots ?? [];
  final String id;
  String name;
  List<SupplyLot> lots;

  /// 使用者勾選「正在用」的那一批。
  String? activeLotId;

  int get left => lots.fold(0, (a, l) => a + l.left);

  SupplyLot? lot(String? id) {
    for (final l in lots) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// 打包時預設用的批次：勾選的那批，否則第一批還有剩的。
  SupplyLot? get defaultLot {
    final a = lot(activeLotId);
    if (a != null && a.left > 0) return a;
    for (final l in lots) {
      if (l.left > 0) return l;
    }
    return lots.isEmpty ? null : lots.last;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lots': [for (final l in lots) l.toJson()],
        'activeLotId': activeLotId,
      };
  factory Supply.fromJson(Map<String, dynamic> j) => Supply(
        id: j['id'],
        name: j['name'],
        lots: [for (final m in (j['lots'] ?? []) as List) SupplyLot.fromJson(m)],
        activeLotId: j['activeLotId'],
      );
}

/// 一個包裹用了某種包材的某一批多少個。
class PackUse {
  PackUse({required this.supplyId, required this.lotId, required this.qty});
  String supplyId;
  String lotId;
  int qty;

  Map<String, dynamic> toJson() => {'supplyId': supplyId, 'lotId': lotId, 'qty': qty};
  factory PackUse.fromJson(Map<String, dynamic> j) =>
      PackUse(supplyId: j['supplyId'], lotId: j['lotId'], qty: j['qty'] ?? 0);
  PackUse copy() => PackUse(supplyId: supplyId, lotId: lotId, qty: qty);
}

/// 盤：選好一起賣的周邊，可以先存起來，之後才成交。買家可以先付定金保留。
class Plan {
  Plan({
    required this.id,
    required this.name,
    required this.itemIds,
    this.price = 0,
    this.currency = 'HKD',
    this.buyer = '',
    this.depositPct = 0,
    this.depositPaid = false,
    this.depositDate = '',
    this.note = '',
  });

  final String id;
  String name;
  List<String> itemIds;

  /// 盤價（[currency] 的分）。
  int price;

  /// 盤價的幣別：HKD 或 RMB。
  String currency;
  String buyer;

  /// 定金佔盤價的百分比；0 = 不收定金。
  double depositPct;
  bool depositPaid;
  String depositDate;
  String note;

  /// 顯示用的幣別符號。
  String get unit => currency == 'HKD' ? 'HK\$' : currency;

  /// 定金金額（和盤價同一幣別）。
  int get deposit => (price * depositPct / 100).round();

  /// 成交時還要收的尾款。
  int get balance => price - (depositPaid ? deposit : 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'itemIds': itemIds,
        'price': price,
        'currency': currency,
        'buyer': buyer,
        'depositPct': depositPct,
        'depositPaid': depositPaid,
        'depositDate': depositDate,
        'note': note,
      };
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'],
        name: j['name'] ?? '',
        itemIds: List<String>.from(j['itemIds'] ?? const []),
        price: j['price'] ?? 0,
        currency: j['currency'] ?? 'HKD',
        buyer: j['buyer'] ?? '',
        depositPct: (j['depositPct'] ?? 0).toDouble(),
        depositPaid: j['depositPaid'] ?? false,
        depositDate: j['depositDate'] ?? '',
        note: j['note'] ?? '',
      );
}

const kSteps =['開團', '下單', '到貨', '分好', '寄出'];
const kOrderPlatforms = ['Weverse', 'Yetimall', '閒魚', '一直娛', 'Starfans', '其他'];
const kSources = ['Threads', 'IG', 'WhatsApp', '其他'];
const kCostStages = ['下單', '轉運倉', '運回來'];

class CostLine {
  CostLine({
    required this.id,
    required this.stage,
    required this.name,
    required this.minor,
    this.currency = 'HKD',
    this.rate = 1,
    this.actual = false,
    this.estHkd,
    this.date = '',
  });
  final String id;
  String stage;
  String name;
  int minor;
  String currency;
  double rate;

  /// false = 預估，true = 實際。
  bool actual;

  /// 由預估改為實際時，保留原本的預估值（HKD 分）。
  int? estHkd;
  String date;

  int get hkd => toHkd(minor, rate);

  Map<String, dynamic> toJson() => {
        'id': id,
        'stage': stage,
        'name': name,
        'minor': minor,
        'currency': currency,
        'rate': rate,
        'actual': actual,
        'estHkd': estHkd,
        'date': date,
      };
  factory CostLine.fromJson(Map<String, dynamic> j) => CostLine(
        id: j['id'],
        stage: j['stage'] ?? '下單',
        name: j['name'] ?? '',
        minor: j['minor'] ?? 0,
        currency: j['currency'] ?? 'HKD',
        rate: (j['rate'] ?? 1).toDouble(),
        actual: j['actual'] ?? false,
        estHkd: j['estHkd'],
        date: j['date'] ?? '',
      );
}

class Slot {
  Slot({
    required this.id,
    required this.member,
    this.price = 0,
    this.ownCost,
    this.buyer = '',
    this.source = 'IG',
    this.paid = false,
    this.paidDate = '',
    this.self = false,
    this.ship = '平郵',
    this.postIn = 0,
    this.postInPaid = false,
    this.postOut = 0,
    List<PackUse>? uses,
    this.pack = 0,
    this.sent = false,
    this.packed = false,
    this.sentDate = '',
    this.itemId,
  }) : uses = uses ?? [];

  /// 這位車員的包裹已打包。
  bool packed;
  String sentDate;

  final String id;
  String member;

  /// 全款價（HKD 分）。
  int price;

  /// 「各位原價」模式下這個位自己的進價（HKD 分）。
  int? ownCost;

  /// 車員；空白 = 剩位。
  String buyer;
  String source;
  bool paid;
  String paidDate;

  /// 我自己留的位。
  bool self;
  String ship;
  int postIn;
  bool postInPaid;
  int postOut;
  List<PackUse> uses;
  int pack;
  bool sent;

  /// 自留位到貨後建立的庫存周邊。
  String? itemId;

  bool get taken => self || buyer.isNotEmpty;
  bool get sold => !self && buyer.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'member': member,
        'price': price,
        'ownCost': ownCost,
        'buyer': buyer,
        'source': source,
        'paid': paid,
        'paidDate': paidDate,
        'self': self,
        'ship': ship,
        'postIn': postIn,
        'postInPaid': postInPaid,
        'postOut': postOut,
        'uses': [for (final u in uses) u.toJson()],
        'pack': pack,
        'sent': sent,
        'packed': packed,
        'sentDate': sentDate,
        'itemId': itemId,
      };
  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        id: j['id'],
        member: j['member'] ?? '',
        price: j['price'] ?? 0,
        ownCost: j['ownCost'],
        buyer: j['buyer'] ?? '',
        source: j['source'] ?? 'IG',
        paid: j['paid'] ?? false,
        paidDate: j['paidDate'] ?? '',
        self: j['self'] ?? false,
        ship: j['ship'] ?? '平郵',
        postIn: j['postIn'] ?? 0,
        postInPaid: j['postInPaid'] ?? false,
        postOut: j['postOut'] ?? 0,
        uses: [for (final m in (j['uses'] ?? []) as List) PackUse.fromJson(m)],
        pack: j['pack'] ?? 0,
        sent: j['sent'] ?? false,
        packed: j['packed'] ?? false,
        sentDate: j['sentDate'] ?? '',
        itemId: j['itemId'],
      );
}

class Group {
  Group({
    required this.id,
    required this.name,
    this.owner = true,
    this.platform = 'Weverse',
    this.leader = '',
    this.costMode = 'even',
    Map<String, String>? steps,
    List<Slot>? slots,
    List<CostLine>? costs,
    this.category = '小卡',
    this.image,
  })  : steps = steps ?? {},
        slots = slots ?? [],
        costs = costs ?? [];

  final String id;
  String name;

  /// 這台車的圖片（縮小後的 base64），開太多車時用來辨認。
  String? image;

  /// true = 我是車主，false = 我是車員。
  bool owner;
  String platform;

  /// 我是車員時的車主帳號。
  String leader;

  /// 'even' 每位平均分；'own' 各位原價＋平分其他成本。
  String costMode;

  /// 已完成的步驟 → 日期。
  Map<String, String> steps;
  List<Slot> slots;
  List<CostLine> costs;
  String category;

  int get totalCost =>
      costs.fold(0, (a, c) => a + c.hkd) +
      (costMode == 'own' ? slots.fold(0, (a, s) => a + (s.ownCost ?? 0)) : 0);

  int get actualCount => costs.where((c) => c.actual).length;
  int get estCount => costs.where((c) => !c.actual).length;

  /// 每個位的成本，順序同 [slots]。
  List<int> slotCosts() {
    if (slots.isEmpty) return [];
    final shared = allocateEven(costs.fold(0, (a, c) => a + c.hkd), slots.length);
    if (costMode != 'own') return shared;
    return [for (var k = 0; k < slots.length; k++) (slots[k].ownCost ?? 0) + shared[k]];
  }

  /// 已賣出的位的差價合計（自留位不計）。
  int get margin {
    final c = slotCosts();
    var m = 0;
    for (var k = 0; k < slots.length; k++) {
      if (slots[k].sold) m += slots[k].price - c[k];
    }
    return m;
  }

  /// 剩位全部賣出可以再多的差價。
  int get marginIfFull {
    final c = slotCosts();
    var m = 0;
    for (var k = 0; k < slots.length; k++) {
      if (!slots[k].taken) m += slots[k].price - c[k];
    }
    return m;
  }

  int get received => slots.where((s) => s.sold && s.paid).fold(0, (a, s) => a + s.price);
  int get due => slots.where((s) => s.sold).fold(0, (a, s) => a + s.price);

  /// 郵包 = 已收的補郵費 − 實付郵費 − 包材。
  /// 只算已賣出的位；補郵費要車員已補才算，實付郵費要已寄出才算。
  int get postNet => slots.where((s) => s.sold).fold(
      0,
      (a, s) => a + (s.postInPaid ? s.postIn : 0) - (s.sent ? s.postOut : 0) - s.pack);

  String get nextStep {
    for (final s in kSteps) {
      if (!steps.containsKey(s)) return s;
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner,
        'platform': platform,
        'leader': leader,
        'costMode': costMode,
        'steps': steps,
        'slots': [for (final s in slots) s.toJson()],
        'costs': [for (final c in costs) c.toJson()],
        'category': category,
        'image': image,
      };
  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'],
        name: j['name'] ?? '',
        owner: j['owner'] ?? true,
        platform: j['platform'] ?? '',
        leader: j['leader'] ?? '',
        costMode: j['costMode'] ?? 'even',
        steps: Map<String, String>.from(j['steps'] ?? const {}),
        slots: [for (final m in (j['slots'] ?? []) as List) Slot.fromJson(m)],
        costs: [for (final m in (j['costs'] ?? []) as List) CostLine.fromJson(m)],
        category: j['category'] ?? '小卡',
        image: j['image'],
      );
}

const kTemplateNames = {
  'open': '開車',
  'left': '剩位',
  'dun': '催款',
  'arrive': '到貨',
  'sent': '寄出',
};

const kDefaultTemplates = {
  'open': '【＜團名＞】開車\n＜全部位和價錢＞\n全款制，到貨後另補本地郵費\n有意請私訊',
  'left': '【＜團名＞】還有剩位\n＜剩位清單＞\n全款制，到貨後另補本地郵費\n有意請私訊',
  'dun': '【＜團名＞】提提大家付款\n＜未付名單＞',
  'arrive': '【＜團名＞】到貨啦\n＜補郵費名單＞\n請補本地郵費，謝謝',
  'sent': '【＜團名＞】已寄出\n＜寄出名單＞',
};

const kTemplateTokens = ['＜團名＞', '＜全部位和價錢＞', '＜剩位清單＞', '＜未付名單＞', '＜補郵費名單＞', '＜寄出名單＞', '＜下單平台＞'];

/// 把模板裡的標籤換成這個團的實際資料。
String renderTemplate(String tpl, Group g) {
  String lines(Iterable<Slot> ss, String Function(Slot) f) =>
      ss.isEmpty ? '（沒有）' : ss.map(f).join('\n');
  return tpl
      .replaceAll('＜團名＞', g.name)
      .replaceAll('＜下單平台＞', g.platform)
      .replaceAll('＜全部位和價錢＞',
          lines(g.slots.where((s) => !s.self), (s) => '${s.member}　HK\$ ${fmt(s.price)}'))
      .replaceAll('＜剩位清單＞',
          lines(g.slots.where((s) => !s.taken), (s) => '${s.member}　HK\$ ${fmt(s.price)}'))
      .replaceAll('＜未付名單＞',
          lines(g.slots.where((s) => s.sold && !s.paid), (s) => '${s.buyer}　${s.member} 位　HK\$ ${fmt(s.price)}'))
      .replaceAll(
          '＜補郵費名單＞',
          lines(g.slots.where((s) => s.sold),
              (s) => '${s.buyer}　${s.ship}　${s.postIn > 0 ? '補 HK\$ ${fmt(s.postIn)}' : (s.ship == '順豐' ? '到付' : '免郵費')}'))
      .replaceAll('＜寄出名單＞',
          lines(g.slots.where((s) => s.sold && s.sent), (s) => '${s.buyer}　${s.ship}'));
}
