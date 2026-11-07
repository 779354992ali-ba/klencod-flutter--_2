import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MobileIDEApp());
}

class MobileIDEApp extends StatelessWidget {
  const MobileIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bisho IDE',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1e1e1e)),
      ),
      home: const IDEScreen(),
    );
  }
}

class IDEScreen extends StatefulWidget {
  const IDEScreen({super.key});

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  final TextEditingController _codeController = TextEditingController();
  String currentFilePath = '';
  List<FileSystemEntity> _files = [];
  Directory? _projectDir;

  @override
  void initState() {
    super.initState();
    _requestStoragePermissionAndInit();
  }

  // 1. طلب أذونات التخزين وتهيئة المجلد الأساسي للمشروع
  Future<void> _requestStoragePermissionAndInit() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    final docDir = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${docDir.path}/BishoProject');
    if (!await projectDir.exists()) {
      await projectDir.create();
      final defaultFile = File('${projectDir.path}/index.html');
      await defaultFile.writeAsString('''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>مرحباً بك في Bisho IDE</title>
    <style>
        body { font-family: Tahoma, sans-serif; background: #121212; color: #fff; text-align: center; padding-top: 50px; }
        h1 { color: #ff79c6; }
        p { color: #8be9fd; }
    </style>
</head>
<body>
    <h1>مرحباً بك في محرك بيشو توب!</h1>
    <p>هذا الموقع تم كتابته وتعديله مباشرة من الهاتف المحمول.</p>
</body>
</html>''');
    }

    setState(() {
      _projectDir = projectDir;
    });
    _loadFileList();
    
    // فتح الملف الافتراضي تلقائياً
    final defaultOpen = File('${projectDir.path}/index.html');
    if (defaultOpen.existsSync()) {
      _openFile(defaultOpen);
    }
  }

  // جلب قائمة الملفات
  void _loadFileList() {
    if (_projectDir != null) {
      setState(() {
        _files = _projectDir!.listSync();
      });
    }
  }

  // قراءة الملف المحدد وعرض محتواه في محرر النصوص الأصلي
  Future<void> _openFile(File file) async {
    final content = await file.readAsString();
    setState(() {
      currentFilePath = file.path;
      _codeController.text = content;
    });
  }

  // حفظ التعديلات على الملف الحالي فوراً
  Future<void> _saveFile() async {
    if (currentFilePath.isNotEmpty) {
      await File(currentFilePath).writeAsString(_codeController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التعديلات بنجاح! 💾', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار ملف أولاً للحفظ', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // حذف ملف من المشروع مع التحديث التلقائي للقائمة
  Future<void> _deleteFile(File file) async {
    final fileName = file.path.split('/').last;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملف'),
        content: Text('هل أنت متأكد من حذف الملف "$fileName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (await file.exists()) {
                await file.delete();
              }
              Navigator.pop(context);
              _loadFileList();
              if (currentFilePath == file.path) {
                setState(() {
                  currentFilePath = '';
                  _codeController.clear();
                });
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف الملف بنجاح! 🗑️', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
              );
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // إنشاء ملف جديد
  Future<void> _createNewFile() async {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء ملف جديد'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'اسم الملف (مثال: style.css)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && _projectDir != null) {
                final newFile = File('${_projectDir!.path}/${nameController.text}');
                await newFile.writeAsString('<!-- كود جديد -->');
                Navigator.pop(context);
                _loadFileList();
                _openFile(newFile);
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  // تنسيق الكود تلقائياً (إضافة مسافات وتنظيم بسيط)
  void _formatCode() {
    String text = _codeController.text;
    // تنظيم سريع للمسافات
    text = text.replaceAll('>', '>\n  ').replaceAll(';', ';\n');
    setState(() {
      _codeController.text = text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تنسيق الكود بنجاح! ✨', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purpleAccent,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // المعاينة الحية للموقع
  void _openLivePreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(htmlContent: _codeController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String fileName = currentFilePath.isEmpty ? 'Bisho IDE' : currentFilePath.split('/').last;
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.pinkAccent),
            onPressed: _formatCode,
            tooltip: 'تنسيق الكود',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
            onPressed: _openLivePreview,
            tooltip: 'معاينة حية',
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.cyanAccent),
            onPressed: _saveFile,
            tooltip: 'حفظ الملف',
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1e1e1e)),
              accountName: const Text("محرك Bisho IDE"),
              accountEmail: Text(_projectDir?.path ?? "مجلد المشروع المحلي"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.purpleAccent,
                child: Icon(Icons.code, color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.amber),
              title: const Text('ملف جديد'),
              onTap: _createNewFile,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final name = file.path.split('/').last;
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                    title: Text(name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        if (file is File) {
                          _deleteFile(file);
                        }
                      },
                    ),
                    onTap: () {
                      if (file is File) {
                        _openFile(file);
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // محرر النصوص الأصلي السريع الذي يستجيب للكتابة فوراً
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: _codeController,
          maxLines: null,
          expands: true,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            color: Colors.greenAccent,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'اختر ملفاً من القائمة الجانبية أو انشئ ملفاً جديداً للبدء بكتابة الكود...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

// شاشة المعاينة الحية
class PreviewScreen extends StatelessWidget {
  final String htmlContent;
  const PreviewScreen({super.key, required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    final previewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المعاينة الحية (Live Preview)'),
        backgroundColor: const Color(0xFF1e1e1e),
      ),
      body: WebViewWidget(controller: previewController),
    );
  }
}
