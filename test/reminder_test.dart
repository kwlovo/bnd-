import 'package:flutter_test/flutter_test.dart';
import 'package:merch_app/models2.dart';
import 'package:merch_app/screens/buyers_page.dart' show buyerKey;

void main() {
  test('截團提醒：沒設日期或已下單不提醒，其餘按天數', () {
    final now = DateTime(2026, 11, 15, 20);
    final g = Group(id: 'g', name: 't');
    expect(deadlineText(g, now), null);
    g.deadline = '2026-11-15';
    expect(deadlineText(g, now), '今天截團（11/15），記得下單');
    g.deadline = '2026-11-16';
    expect(deadlineText(g, now), '明天截團（11/16）');
    g.deadline = '2026-11-20';
    expect(deadlineText(g, now), '5 天後截團（11/20）');
    g.deadline = '2026-11-13';
    expect(deadlineText(g, now), '已過截團 11/13，還沒下單！');
    g.steps['下單'] = '2026-11-13';
    expect(deadlineText(g, now), null);
  });

  test('同一個車員：不分大小寫、不理 @ 和空格', () {
    expect(buyerKey(' @Momo_123 '), buyerKey('momo_123'));
    expect(buyerKey('@@abc'), 'abc');
    expect(buyerKey('abc') == buyerKey('abd'), false);
  });
}
