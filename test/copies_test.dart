import 'package:flutter_test/flutter_test.dart';
import 'package:merch_app/models.dart';
import 'package:merch_app/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('小卡加一張同款：成本不明、不記帳，同款數量 +1', () {
    SharedPreferences.setMockInitialValues({});
    final s = Store();
    final b = Batch(id: 'b', name: 'b', type: BatchType.single, date: '2026-11-14', totalMinor: 3000);
    final a = Item(id: 'a', name: 'Sungho 小卡', member: 'Sungho', category: '小卡', batchId: 'b', createdAt: 1);
    s.addBatchWithItems(b, [a]);
    expect(s.copiesOf(a).length, 1);

    final c = s.addCopy(a);
    expect(s.copiesOf(a).map((i) => i.id), ['a', c.id]);
    expect(c.costCents, null);
    expect(s.batchOf(c.batchId)!.inLedger, false);
    // 記帳只有原本那 $30。
    expect(s.ledger().fold<int>(0, (t, e) => t + e.cents), -3000);

    // 賣掉的不算同款數量。
    c.status = '已售出';
    expect(s.copiesOf(a).length, 1);
  });
}
