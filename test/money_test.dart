import 'package:flutter_test/flutter_test.dart';
import 'package:merch_app/core/money.dart';

void main() {
  test('按參考價比例：規格例子，參考價 40/250、總價 200 分到 32', () {
    final r = allocate(20000, [4000, 6000, 5000, 7000, 3000]);
    expect(r, [3200, 4800, 4000, 5600, 2400]);
    expect(r.reduce((a, b) => a + b), 20000);
  });

  test('平均分：尾差放最後一件，合計等於總價', () {
    final r = allocateEven(10000, 3);
    expect(r, [3333, 3333, 3334]);
    expect(r.reduce((a, b) => a + b), 10000);
  });

  test('按比例：12 張 300，熱門 3 張參考價 50、其餘 9 張 20', () {
    final r = allocate(30000, [...List.filled(3, 5000), ...List.filled(9, 2000)]);
    expect(r.take(3).toSet(), {4545});
    expect(r.reduce((a, b) => a + b), 30000);
  });

  test('權重全 0 時改為平均分', () {
    expect(allocate(900, [0, 0, 0]), [300, 300, 300]);
  });

  test('盤出收入按成本比例：5 件成本 98、盤價 150，成本 18 的分到約 28', () {
    final r = allocate(15000, [1800, 2200, 2000, 2400, 1400]);
    expect(r[0], 2755);
    expect(r.reduce((a, b) => a + b), 15000);
  });

  test('手動：記得的保留，其餘平均分剩下的', () {
    final r = allocateWithFixed(30000, [8000, null, null, 4000]);
    expect(r, [8000, 9000, 9000, 4000]);
  });

  test('手動全部填了：返回原數字並算出差額', () {
    expect(allocateWithFixed(1000, [300, 300]), [300, 300]);
    expect(manualDiff(1000, [300, 300]), 400);
  });

  test('匯率換算和顯示', () {
    expect(toHkd(18500, 1.08), 19980);
    expect(fmt(3200), '32');
    expect(fmt(4550), '45.5');
    expect(fmt(-80), '-0.8');
    expect(parseCents('2.4'), 240);
    expect(parseCents(''), null);
  });
}
