import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'utils/color_utils.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String? _selectedProjectId;
  DateTime _startOfWeek = DateTime.now();
  String _selectedMode = 'overview';
  DateTime _selectedDate = DateTime.now();

  final List<Map<String, dynamic>> _projects = [
    {'id': '1', 'name': 'App di động', 'color': '#6366F1'},
    {'id': '2', 'name': 'Website bán hàng', 'color': '#EC4899'},
    {'id': '3', 'name': 'Dự án AI', 'color': '#F59E0B'},
  ];

  late final List<Map<String, dynamic>> _allTasks;
  List<Map<String, dynamic>> _filteredTasks = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _allTasks = _buildSampleTasks();
    _filterTasks();
  }

  List<Map<String, dynamic>> _buildSampleTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      {
        'id': '1',
        'title': 'Fix giao diện trang chủ',
        'projectId': '1',
        'projectName': 'App di động',
        'startDate': today.subtract(const Duration(days: 2)),
        'endDate': today.add(const Duration(days: 2)),
        'color': '#6366F1',
        'progress': 70,
      },
      {
        'id': '2',
        'title': 'Xây dựng API đăng nhập',
        'projectId': '1',
        'projectName': 'App di động',
        'startDate': today,
        'endDate': today.add(const Duration(days: 3)),
        'color': '#6366F1',
        'progress': 40,
      },
      {
        'id': '3',
        'title': 'Thiết kế database',
        'projectId': '2',
        'projectName': 'Website bán hàng',
        'startDate': today.add(const Duration(days: 1)),
        'endDate': today.add(const Duration(days: 4)),
        'color': '#EC4899',
        'progress': 100,
      },
      {
        'id': '4',
        'title': 'Tối ưu hiệu suất',
        'projectId': '2',
        'projectName': 'Website bán hàng',
        'startDate': today.add(const Duration(days: 2)),
        'endDate': today.add(const Duration(days: 5)),
        'color': '#EC4899',
        'progress': 20,
      },
      {
        'id': '5',
        'title': 'Training model AI',
        'projectId': '3',
        'projectName': 'Dự án AI',
        'startDate': today.add(const Duration(days: 3)),
        'endDate': today.add(const Duration(days: 7)),
        'color': '#F59E0B',
        'progress': 55,
      },
      {
        'id': '6',
        'title': 'Viết tài liệu dự án',
        'projectId': '3',
        'projectName': 'Dự án AI',
        'startDate': today.add(const Duration(days: 4)),
        'endDate': today.add(const Duration(days: 8)),
        'color': '#F59E0B',
        'progress': 10,
      },
      {
        'id': '7',
        'title': 'Deploy lên production',
        'projectId': '1',
        'projectName': 'App di động',
        'startDate': today.add(const Duration(days: 5)),
        'endDate': today.add(const Duration(days: 10)),
        'color': '#6366F1',
        'progress': 0,
      },
    ];
  }

  void _filterTasks() {
    final weekEnd = _startOfWeek.add(const Duration(days: 6));

    setState(() {
      _filteredTasks =
          _allTasks.where((task) {
            final start = task['startDate'] as DateTime;
            final end = task['endDate'] as DateTime;
            final isInSelectedProject =
                _selectedProjectId == null ||
                task['projectId'] == _selectedProjectId;
            final isInWeek =
                (start.isBefore(weekEnd.add(const Duration(days: 1))) &&
                end.isAfter(_startOfWeek.subtract(const Duration(days: 1))));

            return isInSelectedProject && isInWeek;
          }).toList()..sort(
            (a, b) => (a['startDate'] as DateTime).compareTo(
              b['startDate'] as DateTime,
            ),
          );
    });
  }

  void _changeWeek(int direction) {
    setState(() {
      _startOfWeek = _startOfWeek.add(Duration(days: direction * 7));
      _selectedDate = _selectedDate.add(Duration(days: direction * 7));
    });
    _filterTasks();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    _filterTasks();
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM').format(date);

  Color _deadlineColor(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    final daysLeft = deadlineDay.difference(today).inDays;

    if (daysLeft <= 3) return const Color(0xFFEF4444);
    if (daysLeft <= 5) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String _weekdayShort(DateTime date) {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return weekdays[date.weekday - 1];
  }

  String _weekdayFull(DateTime date) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = List.generate(
      7,
      (index) => _startOfWeek.add(Duration(days: index)),
    );
    final weekEnd = _startOfWeek.add(const Duration(days: 6));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildModeTabs(),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedMode == 'overview'
                  ? _buildOverviewContent(weekDays, weekEnd)
                  : _buildDetailContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [ 
              Icon(Icons.timeline_rounded, color: Color(0xFF6366F1), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      'Quản lý thời gian và nhiệm vụ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildModeTab('overview', 'Tổng quan', Icons.timeline_rounded),
            _buildModeTab('detail', 'Chi tiết', Icons.list_alt_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String value, String label, IconData icon) {
    final selected = _selectedMode == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedMode = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewContent(List<DateTime> weekDays, DateTime weekEnd) {
    return Column(
      children: [
        _buildOverviewControls(weekEnd),
        const SizedBox(height: 16),
        Expanded(
          child: _filteredTasks.isEmpty
              ? _buildEmptyState()
              : _buildGanttChart(weekDays),
        ),
      ],
    );
  }

  Widget _buildOverviewControls(DateTime weekEnd, {bool padded = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padded ? 20 : 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _goToToday,
                    child: Center(
                      child: Text(
                        '${_formatDate(_startOfWeek)} - ${_formatDate(weekEnd)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProjectId,
                hint: const Text('Tất cả dự án'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tất cả dự án'),
                  ),
                  ..._projects.map((project) {
                    final color = parseHexColor(project['color']);
                    return DropdownMenuItem<String>(
                      value: project['id'],
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(project['name'])),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                  });
                  _filterTasks();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent() {
    final weekEnd = _startOfWeek.add(const Duration(days: 6));
    final weekDays = List.generate(
      7,
      (index) => _startOfWeek.add(Duration(days: index)),
    );
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final tasksInSelectedDay = _filteredTasks.where((task) {
      final start = task['startDate'] as DateTime;
      final end = task['endDate'] as DateTime;
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      return !selectedDay.isBefore(startDay) && !selectedDay.isAfter(endDay);
    }).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _buildDetailControls(weekEnd, weekDays),
        const SizedBox(height: 16),
        Text(
          '${_weekdayFull(selectedDay)} - ${DateFormat('dd/MM/yyyy').format(selectedDay)}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        if (tasksInSelectedDay.isEmpty)
          _buildDetailEmptyState()
        else
          ...tasksInSelectedDay.map(_buildDetailTaskCard),
      ],
    );
  }

  Widget _buildDetailControls(DateTime weekEnd, List<DateTime> weekDays) {
    return Column(
      children: [
        _buildOverviewControls(weekEnd, padded: false),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: weekDays.map((day) => _buildSelectableDay(day)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableDay(DateTime day) {
    final selected = DateFormat('dd/MM/yyyy').format(day) ==
        DateFormat('dd/MM/yyyy').format(_selectedDate);
    final isWeekend = day.weekday == 6 || day.weekday == 7;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedDate = DateTime(day.year, day.month, day.day);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                _weekdayShort(day),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : isWeekend
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                day.day.toString(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTaskCard(Map<String, dynamic> task) {
    final color = _deadlineColor(task['endDate'] as DateTime);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(Icons.folder_rounded, size: 16, color: color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        task['projectName'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Deadline: ${DateFormat('dd/MM/yyyy').format(task['endDate'] as DateTime)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          'Ngày này chưa có nhiệm vụ nào',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 80, color: Color(0xFFCBD5E1)),
          SizedBox(height: 16),
          Text(
            'KhĂ´ng cĂ³ task trong tuáº§n nĂ y',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'HĂ£y táº¡o task má»›i Ä‘á»ƒ theo dĂµi tiáº¿n Ä‘á»™',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildGanttChart(List<DateTime> weekDays) {
    const dayWidth = 92.0;
    const chartWidth = dayWidth * 7;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: chartWidth,
          child: Column(
            children: [
              _buildWeekHeader(weekDays, dayWidth),
              const SizedBox(height: 8),
              ..._filteredTasks.map((task) {
                final start = task['startDate'] as DateTime;
                final end = task['endDate'] as DateTime;
                final color = _deadlineColor(end);

                var startIndex = 0;
                var endIndex = 6;
                for (var i = 0; i < 7; i++) {
                  final day = weekDays[i];
                  if (day.isAfter(start.subtract(const Duration(days: 1))) &&
                      day.isBefore(end.add(const Duration(days: 1)))) {
                    if (i < startIndex || startIndex == 0) startIndex = i;
                    endIndex = i;
                  }
                }

                final leftOffset = startIndex * dayWidth;
                final width = (endIndex - startIndex + 1) * dayWidth;

                return Container(
                  height: 58,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: List.generate(7, (index) {
                          final day = weekDays[index];
                          final isWeekend =
                              day.weekday == 6 || day.weekday == 7;
                          return SizedBox(
                            width: dayWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 0.5,
                                  ),
                                ),
                                color: isWeekend
                                    ? const Color(
                                        0xFFFEF2F2,
                                      ).withValues(alpha: 0.35)
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                      Positioned(
                        left: leftOffset + 6,
                        top: 10,
                        width: width - 12,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    task['title'],
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekHeader(List<DateTime> weekDays, double dayWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(7, (index) {
          final date = weekDays[index];
          final isToday =
              DateFormat('dd/MM/yyyy').format(date) ==
              DateFormat('dd/MM/yyyy').format(DateTime.now());
          final isWeekend = date.weekday == 6 || date.weekday == 7;

          return SizedBox(
            width: dayWidth,
            child: Column(
              children: [
                Text(
                  _weekdayShort(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: isWeekend
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF6366F1) : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: isToday ? Colors.white : const Color(0xFF1F2937),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/projects');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/chat');
              break;
            case 4:

              Navigator.pushReplacementNamed(context, '/profile');

              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Trang chá»§',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            activeIcon: Icon(Icons.calendar_month_rounded),
            label: 'Lá»‹ch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            activeIcon: Icon(Icons.folder_rounded),
            label: 'Dá»± Ă¡n',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_rounded),
            activeIcon: Icon(Icons.chat_rounded),
            label: 'Tin nháº¯n',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'TĂ´i',
          ),
        ],
      ),
    );
  }
}
