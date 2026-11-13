import 'package:flutter_test/flutter_test.dart';
import 'package:merch_app/models2.dart';
import 'package:merch_app/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('車裡的位按成員順序排，同成員保持加入先後', () {
    SharedPreferences.setMockInitialValues({});
    final s = Store();
    final g = Group(id: 'g', name: 't', slots: [
      Slot(id: 'a', member: 'Woonhak'),
      Slot(id: 'b', member: 'Sungho'),
      Slot(id: 'c', member: '不在名單'),
      Slot(id: 'd', member: 'Leehan'),
      Slot(id: 'e', member: 'Sungho'),
      Slot(id: 'f', member: 'Riwoo'),
    ]);
    s.sortSlots(g);
    expect([for (final x in g.slots) x.id], ['b', 'e', 'f', 'd', 'a', 'c']);
  });
}
