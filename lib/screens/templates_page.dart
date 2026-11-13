import 'package:flutter/material.dart';

import '../main.dart';
import '../models2.dart';
import '../ui.dart';

/// 文案模板：文字自由改寫，會變的資料用標籤代替，複製時自動換成該團的資料。
class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key, this.sample});

  /// 用來預覽的團；沒有就只顯示模板。
  final Group? sample;
  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  String key = 'left';
  late final text = TextEditingController(text: store.templates[key]);

  void _switch(String k) => setState(() {
        store.templates[key] = text.text;
        key = k;
        text.text = store.templates[k] ?? '';
      });

  void _insert(String token) {
    final sel = text.selection;
    final at = sel.isValid ? sel.start : text.text.length;
    text.text = text.text.replaceRange(at, sel.isValid ? sel.end : at, token);
    text.selection = TextSelection.collapsed(offset: at + token.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('文案模板'),
          actions: [
            TextButton(
              onPressed: () => setState(() => text.text = kDefaultTemplates[key]!),
              child: const Text('還原預設'),
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          SegmentedButton<String>(
            segments: [
              for (final e in kTemplateNames.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {key},
            showSelectedIcon: false,
            onSelectionChanged: (v) => _switch(v.first),
          ),
          FieldLabel('我的${kTemplateNames[key]}文案（自由改寫）'),
          TextField(controller: text, maxLines: 7, onChanged: (_) => setState(() {})),
          const FieldLabel('點一下插入，複製時自動換成這個團的資料'),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final t in kTemplateTokens)
              ActionChip(
                label: Text(t.substring(1, t.length - 1)),
                onPressed: () => _insert(t),
              ),
          ]),
          if (widget.sample != null) ...[
            FieldLabel('預覽（用「${widget.sample!.name}」的資料）'),
            Card2(
              child: Text(renderTemplate(text.text, widget.sample!),
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              store.templates[key] = text.text;
              store.commit();
              Navigator.pop(context);
            },
            child: const Text('儲存模板'),
          ),
        ]),
      );
}
