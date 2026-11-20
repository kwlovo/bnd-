import 'package:flutter_test/flutter_test.dart';
import 'package:merch_app/models.dart';
import 'package:merch_app/models2.dart';
import 'package:merch_app/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('快速出卡寄卡：郵費記在郵包，包材扣庫存，改和刪會放回', () {
    SharedPreferences.setMockInitialValues({});
    final s = Store();
    final lot = SupplyLot(id: 'L', date: '2026-11-01', qty: 10, totalCents: 1000);
    s.supplies.add(Supply(id: 'S', name: '卡套', lots: [lot], activeLotId: 'L'));

    final use = PackUse(supplyId: 'S', lotId: 'L', qty: 2);
    final q = QuickSale(
      id: 'q', date: '2026-11-20', priceMinor: 5000, costHkd: 3000,
      ship: '平郵', postIn: 400, postOut: 240,
      uses: [use.toJson()], pack: s.packCostOf([use]),
    );
    s.saveQuick(q);
    expect(lot.used, 2);
    expect(q.pack, 200);
    expect(q.postNet, 400 - 240 - 200);

    final post = s.ledger().where((e) => e.quickId == 'q' && e.category == '郵包').toList();
    expect(post.map((e) => e.cents).toList()..sort(), [-240, 400]);

    // 改成用 1 個：先放回 2 個，再扣 1 個。
    final old = List.of(q.uses);
    q.uses = [PackUse(supplyId: 'S', lotId: 'L', qty: 1).toJson()];
    s.saveQuick(q, oldUses: old);
    expect(lot.used, 1);

    s.deleteQuick('q');
    expect(lot.used, 0);
    expect(s.ledger().where((e) => e.quickId == 'q'), isEmpty);
  });
}
