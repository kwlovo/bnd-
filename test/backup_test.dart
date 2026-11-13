import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:merch_app/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('連相片的備份可以還原相片；文字備份不動現有相片', () {
    SharedPreferences.setMockInitialValues({});
    final a = Store();
    a.photos['x'] = Uint8List.fromList([1, 2, 3]);
    final full = a.exportJson(withPhotos: true);
    final text = a.exportJson();

    final b = Store();
    b.photos['old'] = Uint8List.fromList([9]);
    b.importJson(text, save: false);
    expect(b.photos.keys, ['old']);
    b.importJson(full, save: false);
    expect(b.photos.keys, ['x']);
    expect(b.photos['x'], [1, 2, 3]);
  });

  test('備份提醒：沒資料不提醒，超過 7 天沒備份才提醒', () {
    SharedPreferences.setMockInitialValues({});
    final s = Store();
    expect(s.backupOverdueDays(DateTime(2026, 11, 20)), null);
    s.firstUse = '2026-11-01';
    s.lastBackup = '';
    expect(s.backupOverdueDays(DateTime(2026, 11, 5), hasData: true), null);
    expect(s.backupOverdueDays(DateTime(2026, 11, 20), hasData: true), 19);
    s.lastBackup = '2026-11-18';
    expect(s.backupOverdueDays(DateTime(2026, 11, 20), hasData: true), null);
    expect(s.backupOverdueDays(DateTime(2026, 11, 30), hasData: true), 12);
  });
}
