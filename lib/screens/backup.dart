import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../ui.dart';
import 'item_form.dart' show today;
import 'supplies_page.dart';
import 'templates_page.dart';

/// 備份：把全部資料複製成一段文字，或貼上之前的備份來還原。
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final paste = TextEditingController();
  final member = TextEditingController();

  void _say(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('備份和設定')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          const FieldLabel('工具'),
          Wrap(spacing: 8, children: [
            OutlinedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SuppliesPage())),
              child: const Text('包材庫存'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TemplatesPage())),
              child: const Text('文案模板'),
            ),
          ]),
          const FieldLabel('匯率（換算成 HKD）'),
          for (final c in store.rates.keys.where((c) => c != 'HKD'))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 56, child: Text(c)),
                Expanded(
                  child: TextFormField(
                    initialValue: '${store.rates[c]}',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final r = double.tryParse(v.trim());
                      if (r != null && r > 0) {
                        store.rates[c] = r;
                        store.commit();
                      }
                    },
                  ),
                ),
              ]),
            ),
          const Text('改匯率只影響之後的新紀錄，舊帳保留當時的匯率。',
              style: TextStyle(fontSize: 12, color: cSub)),
          const FieldLabel('備份成檔案（包括相片）'),
          Text(
            '目前有 ${store.items.length} 件周邊、${store.batches.length} 個批次、'
            '${store.series.length} 個系列、${store.photos.length} 張相片。'
            '存成一個檔案，放到「檔案」、iCloud 或傳給自己保存。',
            style: const TextStyle(fontSize: 13, color: cSub),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              final name = 'merch-backup-${today()}.json';
              try {
                await SharePlus.instance.share(ShareParams(
                  files: [
                    XFile.fromData(
                      Uint8List.fromList(utf8.encode(store.exportJson(withPhotos: true))),
                      mimeType: 'application/json',
                      name: name,
                    ),
                  ],
                  fileNameOverrides: [name],
                ));
                store.markBackup();
              } catch (_) {
                _say('存不到檔案，請再試一次');
              }
            },
            icon: const Icon(Icons.save_alt, color: Colors.white),
            label: const Text('存成檔案'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final f = await FilePicker.pickFile();
                if (f == null || !context.mounted) return;
                final raw = utf8.decode(await f.readAsBytes());
                if (!context.mounted) return;
                if (!await confirm(context, '用這個檔案取代目前資料？',
                    '目前的全部資料和相片會被「${f.name}」的內容取代，不能復原。', ok: '取代')) {
                  return;
                }
                store.importJson(raw);
                setState(() {});
                _say('已還原');
              } catch (_) {
                _say('這個檔案不是有效的備份，資料沒有變動');
              }
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('從檔案還原'),
          ),
          const FieldLabel('只備份文字（不包括相片）'),
          const Text('複製全部資料成一段文字，貼到備忘錄保存。用它還原時，現有的相片會保留。',
              style: TextStyle(fontSize: 13, color: cSub)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: store.exportJson()));
              store.markBackup();
              _say('已複製備份');
            },
            icon: const Icon(Icons.copy),
            label: const Text('複製備份'),
          ),
          const FieldLabel('用文字還原'),
          TextField(
            controller: paste,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '把之前複製的備份貼在這裡'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              if (paste.text.trim().isEmpty) return;
              if (!await confirm(context, '用備份取代目前資料？',
                  '目前的全部資料會被備份內容取代，不能復原。', ok: '取代')) {
                return;
              }
              try {
                store.importJson(paste.text.trim());
                _say('已還原');
              } catch (_) {
                _say('這段文字不是有效的備份，資料沒有變動');
              }
            },
            child: const Text('還原'),
          ),
          const FieldLabel('加成員或團體'),
          Row(children: [
            Expanded(child: TextField(controller: member)),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                store.addMember(member.text.trim());
                member.clear();
                setState(() {});
              },
              child: const Text('加入'),
            ),
          ]),
          const SizedBox(height: 8),
          Text('目前：${store.members.join('、')}',
              style: const TextStyle(fontSize: 13, color: cSub)),
        ]),
      );
}
