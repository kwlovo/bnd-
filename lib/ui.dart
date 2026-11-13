import 'dart:typed_data';

import 'package:flutter/cupertino.dart'
    show CupertinoActionSheet, CupertinoActionSheetAction, CupertinoIcons, showCupertinoModalPopup;
import 'package:flutter/material.dart';

import 'core/money.dart';
import 'models.dart';

const cBg = Color(0xFFF3F5F9);
const cInk = Color(0xFF171C26);
const cSub = Color(0xFF556070);
const cLine = Color(0xFFDDE2EA);
const cAccent = Color(0xFF2B55D9);
const cAccentTint = Color(0xFFE6ECFC);

/// 深藍：和亮藍分開用，避免兩個藍色元素撞色。
const cNavy = Color(0xFF1B2F6E);
const cWarn = Color(0xFF8A4200);
const cWarnTint = Color(0xFFFFEEDC);
const cGood = Color(0xFF116B3F);
const cGoodTint = Color(0xFFE2F3EA);

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: cAccent, primary: cAccent),
      scaffoldBackgroundColor: cBg,
      // 只有文字用深色，圖示、按鈕、色塊一律不用純黑。
      iconTheme: const IconThemeData(color: cAccent),
      appBarTheme: const AppBarTheme(
        backgroundColor: cBg,
        foregroundColor: cInk,
        iconTheme: IconThemeData(color: cAccent),
        actionsIconTheme: IconThemeData(color: cAccent),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle:
            TextStyle(color: cInk, fontSize: 17, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cLine),
        ),
      ),
    );

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.fg = cSub, this.bg = const Color(0xFFEBEEF3), this.dashed = false});
  final String text;
  final Color fg;
  final Color bg;
  final bool dashed;

  factory Tag.status(String s) => switch (s) {
        '待售' => const Tag('待售', fg: Color(0xFF1F45B8), bg: cAccentTint),
        '已預留' => const Tag('已預留', fg: cWarn, bg: cWarnTint),
        '已售出' => const Tag('已售出', fg: cGood, bg: cGoodTint),
        '準備盤' => const Tag('準備盤', fg: cInk, bg: Colors.white, dashed: true),
        _ => Tag(s),
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: dashed ? Border.all(color: fg) : null,
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );
}

/// iOS 樣式的選單：點一下從底部彈出選項，選了就關閉。
class PickField extends StatefulWidget {
  const PickField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labels,
    this.label,
    this.plain = false,
    this.fontSize = 15,
  });
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  /// 選項顯示的文字（不給就直接顯示選項本身）。
  final Map<String, String>? labels;
  final String? label;

  /// true：不要外框，放在已有框的列裡用。
  final bool plain;
  final double fontSize;

  @override
  State<PickField> createState() => _PickFieldState();
}

class _PickFieldState extends State<PickField> {
  late String v = widget.value;

  @override
  void didUpdateWidget(PickField old) {
    super.didUpdateWidget(old);
    v = widget.value;
  }

  String _text(String o) => widget.labels?[o] ?? o;

  Future<void> _open() async {
    FocusScope.of(context).unfocus();
    final r = await showCupertinoModalPopup<String>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: widget.label == null ? null : Text(widget.label!),
        actions: [
          for (final o in widget.options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(c, o),
              isDefaultAction: o == v,
              child: Text(o == v ? '✓ ${_text(o)}' : _text(o)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(c),
          child: const Text('取消'),
        ),
      ),
    );
    if (r == null || r == v || !mounted) return;
    setState(() => v = r);
    widget.onChanged(r);
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      Expanded(
        child: Text(_text(v),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: widget.fontSize, color: cInk)),
      ),
      const Icon(CupertinoIcons.chevron_up_chevron_down, size: 16, color: cAccent),
    ]);
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(10),
      child: widget.plain
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: row)
          : InputDecorator(
              decoration: InputDecoration(labelText: widget.label),
              child: row,
            ),
    );
  }
}

/// 周邊縮圖：有相片就顯示相片，沒有就顯示成員名 + 類別。
class ItemThumb extends StatelessWidget {
  const ItemThumb(this.member, this.category, {super.key, this.size = 56, this.photo});
  final String member;
  final String category;
  final double size;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) => photo != null
      ? ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(photo!,
              width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
        )
      : Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFDCE5FB),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(member,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2A3A5E))),
          Text(category,
              style: const TextStyle(fontSize: 10, color: Color(0xFF2A3A5E))),
        ]),
      );
}

/// 成本顯示：確實 "HK$ 32"、大概 "≈ HK$ 25"、不明則顯示標籤。
Widget costLabel(Item i) {
  // 已售出：顯示利潤。成本不明的當成本 0，整筆實收都是利潤。
  final sold = i.soldCents;
  if (sold != null) {
    final p = sold - (i.costCents ?? 0);
    return Text('${p >= 0 ? '+' : '−'}HK\$ ${fmt(p.abs())}',
        style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: p >= 0 ? cGood : cWarn));
  }
  if (i.costCents == null) {
    return const Tag('成本不明', fg: cWarn, bg: Colors.white, dashed: true);
  }
  final prefix = i.costKind == CostKind.approx ? '≈ ' : '';
  return Text('${prefix}HK\$ ${fmt(i.costCents!)}',
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));
}

class Card2 extends StatelessWidget {
  const Card2({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: cLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cSub)),
      );
}

/// 橫向滑動的單選按鈕列。
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.options, required this.value, required this.onChanged, this.labels});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final Map<String, String>? labels;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: options.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, k) {
            final o = options[k];
            final on = o == value;
            return Center(
              child: Material(
                color: on ? cAccent : Colors.white,
                shape: StadiumBorder(side: BorderSide(color: on ? cAccent : cLine)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      labels?[o] ?? o,
                      softWrap: false,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: on ? Colors.white : cInk,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = '確定'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}
