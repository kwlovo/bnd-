/// 金額一律用整數「分」計算，避免小數誤差。
library;

/// 把 [total] 按 [weights] 的比例分給每一件，四捨五入後尾差放到最後一件，
/// 確保合計剛好等於 [total]。權重全為 0 時改為平均分。
List<int> allocate(int total, List<int> weights) {
  final n = weights.length;
  if (n == 0) return [];
  var sum = weights.fold<int>(0, (a, b) => a + b);
  var w = weights;
  if (sum <= 0) {
    w = List.filled(n, 1);
    sum = n;
  }
  final out = List<int>.filled(n, 0);
  var used = 0;
  for (var i = 0; i < n - 1; i++) {
    out[i] = (total * w[i] / sum).round();
    used += out[i];
  }
  out[n - 1] = total - used;
  return out;
}

/// 平均分。
List<int> allocateEven(int total, int count) =>
    allocate(total, List.filled(count, 1));

/// 手動分攤：[fixed] 中有數字的件保留該數字，其餘（null）平均分掉剩下的金額。
/// 全部都填了數字時原樣返回，差額由 [manualDiff] 計算。
List<int> allocateWithFixed(int total, List<int?> fixed) {
  final fixedSum = fixed.fold<int>(0, (a, b) => a + (b ?? 0));
  final blanks = fixed.where((f) => f == null).length;
  if (blanks == 0) return fixed.map((f) => f!).toList();
  final rest = allocateEven(total - fixedSum, blanks);
  var k = 0;
  return [for (final f in fixed) f ?? rest[k++]];
}

/// 手動分攤時，逐件金額合計與總價的差額（正數 = 還差多少未分）。
int manualDiff(int total, List<int?> fixed) =>
    total - fixed.fold<int>(0, (a, b) => a + (b ?? 0));

/// 外幣金額（分）按匯率換算成 HKD（分）。
int toHkd(int minor, double rate) => (minor * rate).round();

/// 顯示用：12345 -> "123.45"，整數元則不顯示小數。
String fmt(int cents) {
  final neg = cents < 0;
  final c = cents.abs();
  final d = c ~/ 100;
  final r = c % 100;
  final s = r == 0
      ? '$d'
      : '$d.${r.toString().padLeft(2, '0')}'.replaceFirst(RegExp(r'0$'), '');
  return neg ? '-$s' : s;
}

/// 把使用者輸入的文字轉成分；空白或無效返回 null。
int? parseCents(String text) {
  final t = text.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null) return null;
  return (v * 100).round();
}
