import 'package:flutter_test/flutter_test.dart';
import 'package:merch_app/models2.dart';

Group sample() => Group(
      id: 'g',
      name: '測試車',
      costs: [
        CostLine(id: 'a', stage: '下單', name: '下單價格', minor: 29000, actual: true),
        CostLine(id: 'b', stage: '轉運倉', name: '入倉合箱', minor: 4700),
        CostLine(id: 'c', stage: '運回來', name: '國際運費', minor: 6500, actual: true, estHkd: 4700),
      ],
      slots: [
        Slot(id: '1', member: 'Sungho', price: 12000, buyer: '@a', paid: true, postIn: 400, postInPaid: true, postOut: 240, sent: true),
        Slot(id: '2', member: 'Riwoo', price: 12000, buyer: '@b', paid: true),
        Slot(id: '3', member: 'Jaehyun', price: 14000, buyer: '@c'),
        Slot(id: '4', member: 'Taesan', price: 14000, self: true),
        Slot(id: '5', member: 'Leehan', price: 15000, buyer: '@d', paid: true, postIn: 850, postInPaid: true, postOut: 850, pack: 380, sent: true),
        // 剩位：預設的實付郵費不應該算進郵包。
        Slot(id: '6', member: 'Woonhak', price: 13000, postOut: 240),
      ],
    );

void main() {
  test('每位平均分：總成本 402、6 位，每位 67；差價只算已賣出的位', () {
    final g = sample();
    expect(g.totalCost, 40200);
    expect(g.slotCosts(), List.filled(6, 6700));
    expect(g.margin, 5300 + 5300 + 7300 + 8300); // 262
    expect(g.marginIfFull, 6300); // 剩位 Woonhak
    expect(g.received, 39000);
    expect(g.due, 53000);
    expect(g.actualCount, 2);
    expect(g.estCount, 1);
  });

  test('郵包 = 已收補郵費 − 實付郵費 − 包材', () {
    expect(sample().postNet, 400 - 240 + 850 - 850 - 380);
  });

  test('各位原價＋平分運費：全部人都要熱門成員', () {
    final g = Group(
      id: 'g',
      name: '熱門車',
      costMode: 'own',
      costs: [CostLine(id: 'c', stage: '運回來', name: '運費', minor: 3000)],
      slots: [
        Slot(id: '1', member: 'Taesan', price: 9000, ownCost: 6000, buyer: '@a'),
        Slot(id: '2', member: 'Taesan', price: 9000, ownCost: 6000, buyer: '@b'),
        Slot(id: '3', member: 'Taesan', price: 5000, ownCost: 2000, buyer: '@c'),
      ],
    );
    expect(g.slotCosts(), [7000, 7000, 3000]);
    expect(g.totalCost, 17000);
    expect(g.margin, 2000 + 2000 + 2000);
  });

  test('文案模板：標籤換成這個團的資料', () {
    final g = sample();
    final left = renderTemplate(kDefaultTemplates['left']!, g);
    expect(left, contains('【測試車】'));
    expect(left, contains('Woonhak　HK\$ 130'));
    expect(left, isNot(contains('Sungho')));
    final dun = renderTemplate(kDefaultTemplates['dun']!, g);
    expect(dun, contains('@c　Jaehyun 位　HK\$ 140'));
    expect(dun, isNot(contains('@a')));
    final arrive = renderTemplate(kDefaultTemplates['arrive']!, g);
    expect(arrive, contains('@a　平郵　補 HK\$ 4'));
  });

  test('進度：下一步是第一個未完成的步驟', () {
    final g = sample();
    expect(g.nextStep, '開團');
    g.steps['開團'] = '2026-11-01';
    g.steps['下單'] = '2026-11-02';
    expect(g.nextStep, '到貨');
  });
}
