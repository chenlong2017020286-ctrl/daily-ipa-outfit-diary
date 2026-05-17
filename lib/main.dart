import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const OutfitDiaryApp());
}

class OutfitEntry {
  final String id;
  final DateTime date;
  final String description;
  final List<String> categories;
  final String mood;
  final List<String> imagePaths;

  const OutfitEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.categories,
    required this.mood,
    required this.imagePaths,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'description': description,
        'categories': categories,
        'mood': mood,
        'imagePaths': imagePaths,
      };

  factory OutfitEntry.fromJson(Map<String, dynamic> json) => OutfitEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        description: json['description'] as String,
        categories: List<String>.from(json['categories'] as List),
        mood: json['mood'] as String,
        imagePaths: List<String>.from(json['imagePaths'] as List),
      );
}

const List<String> kCategories = [
  '休闲',
  '运动',
  '正式',
  '约会',
  '居家',
];

const List<String> kMoods = [
  '😊 开心',
  '😌 平静',
  '😎 自信',
  '😴 慵懒',
  '🥳 兴奋',
];

class OutfitDiaryApp extends StatelessWidget {
  const OutfitDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '穿搭日记',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<OutfitEntry> _outfits = [];
  int _currentTab = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOutfits();
  }

  Future<void> _loadOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('outfit_diary_data');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _outfits = jsonList
            .map((e) => OutfitEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_outfits.map((e) => e.toJson()).toList());
    await prefs.setString('outfit_diary_data', data);
  }

  void _addOutfit(OutfitEntry entry) {
    setState(() => _outfits.insert(0, entry));
    _saveOutfits();
  }

  void _updateOutfit(int index, OutfitEntry entry) {
    setState(() => _outfits[index] = entry);
    _saveOutfits();
  }

  void _deleteOutfit(int index) {
    setState(() => _outfits.removeAt(index));
    _saveOutfits();
  }

  Future<void> _navigateToAddEdit({OutfitEntry? entry, int? index}) async {
    final result = await Navigator.push<OutfitEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditScreen(entry: entry),
      ),
    );
    if (result != null) {
      if (index != null) {
        _updateOutfit(index, result);
      } else {
        _addOutfit(result);
      }
    }
  }

  void _showDayOutfits(DateTime date) {
    final dayOutfits = _outfits
        .where((o) =>
            o.date.year == date.year &&
            o.date.month == date.month &&
            o.date.day == date.day)
        .toList();
    if (dayOutfits.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DayOutfitsSheet(
        outfits: dayOutfits,
        onEdit: (outfit) {
          final idx = _outfits.indexOf(outfit);
          Navigator.pop(context);
          _navigateToAddEdit(entry: outfit, index: idx);
        },
        onDelete: (outfit) {
          final idx = _outfits.indexOf(outfit);
          if (idx != -1) _deleteOutfit(idx);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('穿搭日记'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentTab,
              children: [
                CalendarView(
                  outfits: _outfits,
                  onDayTap: _showDayOutfits,
                ),
                GalleryView(
                  outfits: _outfits,
                  onEdit: (index) =>
                      _navigateToAddEdit(entry: _outfits[index], index: index),
                  onDelete: _deleteOutfit,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('记录穿搭'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '日历'),
          NavigationDestination(icon: Icon(Icons.photo_library), label: '衣橱'),
        ],
      ),
    );
  }
}

class CalendarView extends StatefulWidget {
  final List<OutfitEntry> outfits;
  final void Function(DateTime date) onDayTap;

  const CalendarView({
    super.key,
    required this.outfits,
    required this.onDayTap,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
  }

  Set<DateTime> get _outfitDays {
    final days = <DateTime>{};
    for (final o in widget.outfits) {
      days.add(DateTime(o.date.year, o.date.month, o.date.day));
    }
    return days;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday;
    final leadBlank = startWeekday - 1;
    final totalCells = ((leadBlank + daysInMonth + 6) ~/ 7) * 7;

    const daysOfWeek = ['一', '二', '三', '四', '五', '六', '日'];

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  '$year年$month月',
                  style:
                      textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: daysOfWeek.map((d) {
                return Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: textTheme.bodySmall?.copyWith(
                        color: (d == '六' || d == '日')
                            ? colorScheme.error
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.1,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                final dayNumber = index - leadBlank + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(year, month, dayNumber);
                final hasOutfit = _outfitDays.contains(date);
                final isToday = DateTime.now().year == year &&
                    DateTime.now().month == month &&
                    DateTime.now().day == dayNumber;

                return GestureDetector(
                  onTap: hasOutfit ? () => widget.onDayTap(date) : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday
                          ? colorScheme.primaryContainer
                          : hasOutfit
                              ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
                              : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color:
                                isToday ? colorScheme.onPrimaryContainer : null,
                          ),
                        ),
                        if (hasOutfit)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryView extends StatelessWidget {
  final List<OutfitEntry> outfits;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;

  const GalleryView({
    super.key,
    required this.outfits,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (outfits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom,
                size: 80, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '还没有穿搭记录',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮开始记录',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: outfits.length,
      itemBuilder: (context, index) {
        final outfit = outfits[index];
        return OutfitCard(
          outfit: outfit,
          onTap: () => onEdit(index),
          onLongPress: () => _showDeleteDialog(context, index),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条穿搭记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onDelete(index);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class OutfitCard extends StatelessWidget {
  final OutfitEntry outfit;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const OutfitCard({
    super.key,
    required this.outfit,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = '${outfit.date.month}/${outfit.date.day}';

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: outfit.imagePaths.isNotEmpty
                  ? Image.file(
                      File(outfit.imagePaths.first),
                      width: double.infinity,
                      fit: BoxFit.cover,
errorBuilder: (_, _, _) => const _OutfitPlaceholder(),
                    )
                    : const _OutfitPlaceholder(),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(dateStr,
                            style: Theme.of(context).textTheme.labelMedium),
                        const Spacer(),
                        Text(outfit.mood.split(' ').first,
                            style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outfit.description.isEmpty ? '无描述' : outfit.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 4,
                      children: outfit.categories.take(2).map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutfitPlaceholder extends StatelessWidget {
  const _OutfitPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.checkroom,
            size: 48, color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class DayOutfitsSheet extends StatelessWidget {
  final List<OutfitEntry> outfits;
  final void Function(OutfitEntry entry) onEdit;
  final void Function(OutfitEntry entry) onDelete;

  const DayOutfitsSheet({
    super.key,
    required this.outfits,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${outfits.first.date.month}月${outfits.first.date.day}日 穿搭',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...outfits.map((outfit) => _DayOutfitTile(
                  outfit: outfit,
                  onEdit: () => onEdit(outfit),
                  onDelete: () => onDelete(outfit),
                )),
          ],
        ),
      ),
    );
  }
}

class _DayOutfitTile extends StatelessWidget {
  final OutfitEntry outfit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DayOutfitTile({
    required this.outfit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 80,
                child: outfit.imagePaths.isNotEmpty
                    ? Image.file(
                        File(outfit.imagePaths.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.checkroom,
                            color: colorScheme.outline),
                      )
                    : Icon(Icons.checkroom, color: colorScheme.outline),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.description.isEmpty ? '无描述' : outfit.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(outfit.mood,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: outfit.categories.map((c) {
                      return Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: onEdit,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 20, color: colorScheme.error),
                  onPressed: onDelete,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddEditScreen extends StatefulWidget {
  final OutfitEntry? entry;

  const AddEditScreen({super.key, this.entry});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  late DateTime _selectedDate;
  late List<String> _selectedCategories;
  late String _selectedMood;
  late List<String> _imagePaths;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _selectedDate = e?.date ?? DateTime.now();
    _selectedCategories = List<String>.from(e?.categories ?? []);
    _selectedMood = e?.mood ?? kMoods.first;
    _imagePaths = List<String>.from(e?.imagePaths ?? []);
    _descriptionController.text = e?.description ?? '';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _imagePaths.addAll(images.map((e) => e.path));
        });
      }
    } on Exception {
      // User cancelled or permission denied
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo =
          await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() => _imagePaths.add(photo.path));
      }
    } on Exception {
      // User cancelled or permission denied
    }
  }

  void _save() {
    final entry = OutfitEntry(
      id: _isEditing
          ? widget.entry!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDate,
      description: _descriptionController.text.trim(),
      categories: List<String>.from(_selectedCategories),
      mood: _selectedMood,
      imagePaths: List<String>.from(_imagePaths),
    );
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr =
        '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑穿搭' : '记录穿搭'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('日期'),
              subtitle: Text(dateStr),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: colorScheme.surfaceContainerLow,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '描述',
                hintText: '描述今天的穿搭...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.edit_note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text('分类标签', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: kCategories.map((cat) {
                final selected = _selectedCategories.contains(cat);
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedCategories.add(cat);
                      } else {
                        _selectedCategories.remove(cat);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('心情', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: kMoods.map((mood) {
                final selected = _selectedMood == mood;
                return ChoiceChip(
                  label: Text(mood),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedMood = mood);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('照片', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._imagePaths.map(
                  (path) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(path),
                          width: 80,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 80,
                            height: 100,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: IconButton(
                          icon: Icon(Icons.cancel,
                              color: colorScheme.error, size: 20),
                          onPressed: () {
                            setState(() => _imagePaths.remove(path));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 100,
                  child: OutlinedButton(
                    onPressed: _pickImages,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 28),
                        SizedBox(height: 4),
                        Text('相册', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 100,
                  child: OutlinedButton(
                    onPressed: _takePhoto,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 28),
                        SizedBox(height: 4),
                        Text('拍照', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
