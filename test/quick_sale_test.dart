import 'package:flutter_test/flutter_test.dart';
import 'package:merch_app/models.dart';
import 'package:merch_app/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('快速記出卡：記帳記收入，利潤 = 收入 − 成本，存檔再讀回來不變', () {
    SharedPreferences.setMockInitialValues({});
    final s = Store();
    s.saveQuick(QuickSale(id: 'q1', date: '2026-11-20', priceMinor: 5000, costHkd: 3000, platform: 'IG'));
    s.saveQuick(QuickSale(id: 'q2', date: '2026-11-20', priceMinor: 10000, currency: 'RMB', rate: 1.1));
    expect(s.quick.first.profit, 2000);
    expect(s.quick.last.priceHkd, 11000);
    expect(s.quick.last.profit, 11000); // 成本不明當 0

    final led = s.ledger().where((e) => e.quickId != null).toList();
    expect(led.length, 2);
    expect(led.fold<int>(0, (a, e) => a + e.cents), 16000);
    expect(led.firstWhere((e) => e.quickId == 'q1').sub, 'IG · 賺 HK\$ 20');

    final b = Store()..importJson(s.exportJson(), save: false);
    expect(b.quick.map((q) => q.id), ['q1', 'q2']);
    expect(b.quick.first.costHkd, 3000);

    s.deleteQuick('q1');
    expect(s.quick.length, 1);
  });
}
