import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../core/theme/app_colors.dart';
import '../../domain/entities/rafidain_installment_plan.dart';
import '../controllers/main_dashboard_controller.dart';
import '../widgets/premium_ui.dart';

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({
    super.key,
    required this.controller,
    required this.doctorName,
  });

  final MainDashboardController controller;
  final String doctorName;

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  static const int _rowsPerPage = 50;
  final TextEditingController _tableSearchController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.setDoctor(widget.doctorName, notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.generateMonthlyReport();
      }
    });
    widget.controller.doctorPercentController.addListener(_refresh);
    widget.controller.tarakeebController.addListener(_refresh);
    widget.controller.tamweelController.addListener(_refresh);
    _tableSearchController.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    widget.controller.doctorPercentController.removeListener(_refresh);
    widget.controller.tarakeebController.removeListener(_refresh);
    widget.controller.tamweelController.removeListener(_refresh);
    _tableSearchController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _generateReportWithFeedback() async {
    await widget.controller.generateMonthlyReport();
    if (!mounted) {
      return;
    }
    final success = !widget.controller.statusMessage.startsWith('فشل') &&
        !widget.controller.statusMessage.contains('الرجاء');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم تحديث التقرير على الشاشة (${widget.controller.reportRows.length} صف). للتنزيل اضغط «تنزيل Word».'
              : widget.controller.statusMessage,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _downloadWordWithFeedback() async {
    final path = await widget.controller.exportDoctorReportWord();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            path == null ? 'لم يتم التنزيل' : 'تم حفظ ملف Word',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          content: Text(
            path == null
                ? widget.controller.statusMessage
                : 'تم حفظ التقرير في مجلد التنزيلات:\n\n$path',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        );
      },
    );
  }

  void _changePagePreservingScroll(int newPage) {
    final previousOffset =
        _pageScrollController.hasClients ? _pageScrollController.offset : 0.0;
    setState(() {
      _currentPage = newPage;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageScrollController.hasClients) {
        return;
      }
      final max = _pageScrollController.position.maxScrollExtent;
      final safeOffset = previousOffset.clamp(0.0, max);
      _pageScrollController.jumpTo(safeOffset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final amountFormat = NumberFormat.decimalPattern('ar');
    final monthItems = List.generate(12, (index) => index + 1);
    final yearItems = List.generate(7, (index) => DateTime.now().year - 2 + index);

    return AuroraBackground(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              centerTitle: true,
              toolbarHeight: 72,
              titleSpacing: 0,
              automaticallyImplyLeading: false,
              leadingWidth: 56,
              leading: const SizedBox(width: 56),
              title: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'تفاصيل الطبيب: ${widget.doctorName}',
                  textAlign: TextAlign.center,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8, top: 10),
                  child: IconButton(
                    tooltip: 'رجوع',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: ListView(
                controller: _pageScrollController,
                children: [
                  FadeSlideIn(
                    child: _DoctorHeroHeader(
                      doctorName: widget.doctorName,
                      statusMessage: widget.controller.statusMessage,
                      busy: widget.controller.isBusy,
                      reportRows: widget.controller.reportRows.length,
                      pendingRafidain: widget.controller.pendingRafidain.length,
                      periodLabel: widget.controller.periodMode == ReportPeriodMode.monthly
                          ? 'شهر ${widget.controller.selectedMonth}/${widget.controller.selectedYear}'
                          : 'من ${DateFormat('yyyy/MM/dd').format(widget.controller.rangeFrom)} إلى ${DateFormat('yyyy/MM/dd').format(widget.controller.rangeTo)}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: _buildFiltersCard(monthItems, yearItems),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: _buildMonthlyTable(dateFormat, amountFormat),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: _buildSummaryCard(amountFormat),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: _buildPendingInstallmentsCard(dateFormat, amountFormat),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFiltersCard(List<int> months, List<int> years) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final monthNames = const [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final isMonthly = widget.controller.periodMode == ReportPeriodMode.monthly;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFFFFF), Color(0xFFEFFAF8)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              left: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealBright.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon3D(
                        icon: Icons.event_note_rounded,
                        size: 52,
                        colors: [Color(0xFF5EEAD4), Color(0xFF0F766E)],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'فترة التقرير',
                              style: GoogleFonts.cairo(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'إنشاء التقرير = عرض على الشاشة · تنزيل Word = حفظ الملف',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7F6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PeriodModeChip(
                            selected: isMonthly,
                            icon: Icons.calendar_month_rounded,
                            label: 'تقرير شهري',
                            onTap: widget.controller.isBusy
                                ? null
                                : () {
                                    widget.controller
                                        .setPeriodMode(ReportPeriodMode.monthly);
                                    widget.controller.generateMonthlyReport();
                                  },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PeriodModeChip(
                            selected: !isMonthly,
                            icon: Icons.date_range_rounded,
                            label: 'من — إلى',
                            onTap: widget.controller.isBusy
                                ? null
                                : () {
                                    widget.controller
                                        .setPeriodMode(ReportPeriodMode.dateRange);
                                    widget.controller.generateMonthlyReport();
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isMonthly)
                    Row(
                      children: [
                        Expanded(
                          child: _FilterFieldShell(
                            label: 'الشهر',
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: widget.controller.selectedMonth,
                                items: months
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m,
                                        child: Text('${monthNames[m - 1]} ($m)'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: widget.controller.isBusy
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          widget.controller.setMonth(value);
                                          widget.controller.generateMonthlyReport();
                                        }
                                      },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterFieldShell(
                            label: 'السنة',
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: widget.controller.selectedYear,
                                items: years
                                    .map(
                                      (y) => DropdownMenuItem(
                                        value: y,
                                        child: Text(y.toString()),
                                      ),
                                    )
                                    .toList(),
                                onChanged: widget.controller.isBusy
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          widget.controller.setYear(value);
                                          widget.controller.generateMonthlyReport();
                                        }
                                      },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _GenerateReportButton(
                          busy: widget.controller.isBusy,
                          onPressed: _generateReportWithFeedback,
                        ),
                        const SizedBox(width: 10),
                        _DownloadWordButton(
                          busy: widget.controller.isBusy,
                          onPressed: _downloadWordWithFeedback,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickShell(
                            label: 'من تاريخ',
                            value: dateFormat.format(widget.controller.rangeFrom),
                            enabled: !widget.controller.isBusy,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: widget.controller.rangeFrom,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                widget.controller.setRangeFrom(picked);
                                await _generateReportWithFeedback();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DatePickShell(
                            label: 'إلى تاريخ',
                            value: dateFormat.format(widget.controller.rangeTo),
                            enabled: !widget.controller.isBusy,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: widget.controller.rangeTo,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                widget.controller.setRangeTo(picked);
                                await _generateReportWithFeedback();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        _GenerateReportButton(
                          busy: widget.controller.isBusy,
                          onPressed: _generateReportWithFeedback,
                        ),
                        const SizedBox(width: 10),
                        _DownloadWordButton(
                          busy: widget.controller.isBusy,
                          onPressed: _downloadWordWithFeedback,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTable(DateFormat dateFormat, NumberFormat amountFormat) {
    final rawQuery = _tableSearchController.text.trim().toLowerCase();
    final allRows = widget.controller.reportRows.where((row) {
      if (rawQuery.isEmpty) {
        return true;
      }
      final amountText = amountFormat.format(row.amount).toLowerCase();
      return row.patientName.toLowerCase().contains(rawQuery) ||
          row.phoneNumber.toLowerCase().contains(rawQuery) ||
          row.paymentMethod.toLowerCase().contains(rawQuery) ||
          amountText.contains(rawQuery);
    }).toList();

    final totalRows = allRows.length;
    final totalPages = math.max(1, (totalRows / _rowsPerPage).ceil());
    final safePage = _currentPage.clamp(1, totalPages);
    final start = totalRows == 0 ? 0 : ((safePage - 1) * _rowsPerPage) + 1;
    final end = totalRows == 0 ? 0 : math.min(safePage * _rowsPerPage, totalRows);
    final pageRows = allRows.skip((safePage - 1) * _rowsPerPage).take(_rowsPerPage).toList();

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'جدول المرضى والمدفوعات',
            subtitle: 'كشف يومي للمرضى والمدفوعات للفترة المحددة',
            icon: Icons.receipt_long_rounded,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tealBright.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'عدد الصفوف: $totalRows',
                style: GoogleFonts.cairo(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildPagerControls(safePage: safePage, totalPages: totalPages),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: widget.controller.isBusy
                        ? null
                        : _downloadWordWithFeedback,
                    icon: const Icon(Icons.download_rounded, color: AppColors.teal),
                    label: const Text('تنزيل Word'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: Color(0xFF99F6E4)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _tableSearchController,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن مريض، هاتف، مبلغ ...',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.teal),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (pageRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'لا توجد بيانات للفترة المحددة.',
                style: GoogleFonts.cairo(color: AppColors.textSecondary),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 48,
                    columns: const [
                      DataColumn(label: _SortHeader(text: '#')),
                      DataColumn(label: _SortHeader(text: 'المريض')),
                      DataColumn(label: _SortHeader(text: 'الهاتف')),
                      DataColumn(label: _SortHeader(text: 'المبلغ المدفوع')),
                      DataColumn(label: _SortHeader(text: 'تاريخ الدفع')),
                      DataColumn(label: _SortHeader(text: 'طريقة الدفع')),
                      DataColumn(label: _SortHeader(text: 'الشهر')),
                      DataColumn(label: _SortHeader(text: 'القسط الشهري')),
                      DataColumn(label: SizedBox(width: 18)),
                    ],
                    rows: pageRows.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      final rowNumber = start + index;
                      return DataRow(
                        color: WidgetStatePropertyAll(
                          rowNumber.isEven ? const Color(0xFFF3FBFA) : Colors.white,
                        ),
                        cells: [
                          DataCell(Text(rowNumber.toString())),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_outline_rounded,
                                    size: 16, color: AppColors.teal),
                                const SizedBox(width: 6),
                                Text(row.patientName),
                              ],
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.call_outlined,
                                    size: 16, color: Color(0xFF0EA5E9)),
                                const SizedBox(width: 6),
                                Text(row.phoneNumber),
                              ],
                            ),
                          ),
                          DataCell(Text('${amountFormat.format(row.amount)} د.ع')),
                          DataCell(Text(dateFormat.format(row.paymentDate))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(row.paymentMethod),
                                const SizedBox(width: 6),
                                Icon(
                                  row.paymentMethod.contains('بطاقة')
                                      ? Icons.credit_card_rounded
                                      : Icons.payments_outlined,
                                  size: 16,
                                  color: row.paymentMethod.contains('بطاقة')
                                      ? AppColors.teal
                                      : AppColors.slate,
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(row.paymentDate.month.toString())),
                          DataCell(
                            row.monthlyInstallmentAmount == null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.emeraldSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '-',
                                      style: GoogleFonts.cairo(
                                        color: AppColors.emerald,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : Text(
                                    '${amountFormat.format(row.monthlyInstallmentAmount)} د.ع',
                                  ),
                          ),
                          const DataCell(
                            Icon(Icons.more_vert_rounded,
                                size: 18, color: AppColors.textMuted),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'عرض $start إلى $end من أصل $totalRows صف',
            style: GoogleFonts.cairo(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPagerControls({
    required int safePage,
    required int totalPages,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: safePage > 1
                ? () => _changePagePreservingScroll(safePage - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          ...List.generate(totalPages.clamp(1, 6), (i) {
            final page = i + 1;
            final selected = page == safePage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => _changePagePreservingScroll(page),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFF2DD4BF), Color(0xFF0F766E)],
                          )
                        : null,
                    color: selected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? Colors.transparent : AppColors.borderStrong,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.tealBright.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    page.toString(),
                    style: GoogleFonts.cairo(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (totalPages > 6) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('...'),
            ),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Text(totalPages.toString()),
            ),
          ],
          IconButton(
            onPressed: safePage < totalPages
                ? () => _changePagePreservingScroll(safePage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(NumberFormat amountFormat) {
    final doctorName = widget.controller.selectedDoctor ?? '';
    final tamweelShare = widget.controller.appliedTamweelAmount;

    return GlassPanel(
      glow: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'ملخص الحساب',
            subtitle: 'النسبة · التمويل · التراكيب · الصافي',
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MoneyChip(
                title: 'المبلغ الكلي',
                value: '${amountFormat.format(widget.controller.monthlyTotal)} د.ع',
                colors: const [Color(0xFF38BDF8), Color(0xFF0369A1)],
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: widget.controller.doctorPercentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'نسبة الطبيب %'),
                ),
              ),
              _MoneyChip(
                title: 'المبلغ الصافي بعد النسبة',
                value: '${amountFormat.format(widget.controller.doctorAmount)} د.ع',
                colors: const [Color(0xFF2DD4BF), Color(0xFF0F766E)],
              ),
              _MoneyChip(
                title: widget.controller.isOwnerDoctor(doctorName)
                    ? 'أجور التمويل (حصة المالك)'
                    : 'أجور التمويل',
                value: '${amountFormat.format(tamweelShare)} د.ع',
                colors: const [Color(0xFFFB7185), Color(0xFFBE123C)],
              ),
              _MoneyChip(
                title: 'المبلغ الصافي بعد التمويل',
                value: '${amountFormat.format(widget.controller.amountAfterTamweel)} د.ع',
                colors: const [Color(0xFFF472B6), Color(0xFF9D174D)],
              ),
              _FeeApplyField(
                controller: widget.controller.tarakeebController,
                label: 'أجور التراكيب',
                onApply: widget.controller.applyTarakeebFee,
              ),
              SizedBox(
                width: 360,
                child: Row(
                  children: [
                    Expanded(
                      child: _MoneyChip(
                        title: 'المبلغ الصافي النهائي',
                        value:
                            '${amountFormat.format(widget.controller.finalDoctorAmount)} د.ع',
                        colors: const [Color(0xFF34D399), Color(0xFF047857)],
                        emphasized: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'إلغاء خصم التراكيب',
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.tealBright.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton.filled(
                          onPressed: widget.controller.clearAppliedDeductions,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
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

  Widget _buildPendingInstallmentsCard(
    DateFormat dateFormat,
    NumberFormat amountFormat,
  ) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'دفعات الرافدين المعلقة',
            subtitle: 'حدّد عدد الأشهر واحفظ خطة التقسيط',
            icon: Icons.credit_score_rounded,
          ),
          const SizedBox(height: 12),
          if (widget.controller.pendingRafidain.isEmpty)
            Text(
              'لا توجد دفعات رافدين معلقة لهذا الطبيب/الشهر.',
              style: GoogleFonts.cairo(color: AppColors.textSecondary),
            )
          else
            ...widget.controller.pendingRafidain.map((payment) {
              final monthsController =
                  widget.controller.pendingMonthsControllers[payment.paymentId]!;
              final platformFee =
                  RafidainInstallmentPlan.platformFeeFrom(payment.amount);
              final netAmount =
                  RafidainInstallmentPlan.netAfterPlatformFee(payment.amount);
              final feePercent =
                  (RafidainInstallmentPlan.platformFeeRate * 100)
                      .toStringAsFixed(0);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      AppColors.champagneSoft.withValues(alpha: 0.45),
                    ],
                  ),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.patientName,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المبلغ الكلي: ${amountFormat.format(payment.amount)} د.ع',
                      style: GoogleFonts.cairo(color: AppColors.textSecondary),
                    ),
                    Text(
                      'اقتطاع منصة الرافدين ($feePercent%): ${amountFormat.format(platformFee)} د.ع',
                      style: GoogleFonts.cairo(color: AppColors.textSecondary),
                    ),
                    Text(
                      'المبلغ بعد الاقتطاع: ${amountFormat.format(netAmount)} د.ع',
                      style: GoogleFonts.cairo(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'تاريخ الدفع: ${dateFormat.format(payment.paymentDate)}',
                      style: GoogleFonts.cairo(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: monthsController,
                      builder: (context, value, _) {
                        final months =
                            int.tryParse(value.text.trim()) ?? 0;
                        final previewMonthly = months > 0
                            ? netAmount / months
                            : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: TextField(
                                    controller: monthsController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'عدد الأشهر',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton(
                                  onPressed: widget.controller.isBusy
                                      ? null
                                      : () => widget.controller
                                          .savePendingPlan(payment),
                                  child: const Text('حفظ خطة التقسيط'),
                                ),
                              ],
                            ),
                            if (previewMonthly != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'القسط الشهري المتوقع: ${amountFormat.format(previewMonthly)} د.ع',
                                style: GoogleFonts.cairo(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 10),
          _buildLocalInstallmentEntryCard(dateFormat, amountFormat),
        ],
      ),
    );
  }

  Widget _buildLocalInstallmentEntryCard(
    DateFormat dateFormat,
    NumberFormat amountFormat,
  ) {
    final firstInstallmentDate = widget.controller.localPlanFirstInstallmentDate;
    final amount =
        double.tryParse(widget.controller.localPlanAmountController.text.trim()) ?? 0;
    final months =
        int.tryParse(widget.controller.localPlanMonthsController.text.trim()) ?? 0;
    final net = RafidainInstallmentPlan.netAfterPlatformFee(amount);
    final previewMonthly = (amount > 0 && months > 0) ? (net / months) : null;
    final feePercent =
        (RafidainInstallmentPlan.platformFeeRate * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDFA), Color(0xFFFFFFEE)],
        ),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إضافة مريض أقساط محلي (داخل التطبيق فقط)',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'لا يتم الإضافة إلى SQL ولا تعديلها.',
            style: GoogleFonts.cairo(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller.localPlanPatientNameController,
                  decoration: const InputDecoration(labelText: 'اسم المريض'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller.localPlanPhoneController,
                  decoration: const InputDecoration(labelText: 'الهاتف (اختياري)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller.localPlanAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ الكلي'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: widget.controller.localPlanMonthsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد الأشهر'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller.localPlanInvoiceController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الفاتورة (اختياري)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.controller.isBusy
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: firstInstallmentDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            widget.controller.setLocalPlanFirstInstallmentDate(picked);
                          }
                        },
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    'أول قسط: ${dateFormat.format(firstInstallmentDate)}',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.saveLocalOnlyInstallmentPlan,
                icon: const Icon(Icons.add_rounded),
                label: const Text('حفظ محلي'),
              ),
            ],
          ),
          if (amount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'اقتطاع منصة الرافدين ($feePercent%): ${amountFormat.format(RafidainInstallmentPlan.platformFeeFrom(amount))} د.ع',
              style: GoogleFonts.cairo(color: AppColors.textSecondary),
            ),
            Text(
              'المبلغ بعد الاقتطاع: ${amountFormat.format(net)} د.ع',
              style: GoogleFonts.cairo(
                color: AppColors.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (previewMonthly != null)
              Text(
                'القسط الشهري المتوقع: ${amountFormat.format(previewMonthly)} د.ع',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DoctorHeroHeader extends StatelessWidget {
  const _DoctorHeroHeader({
    required this.doctorName,
    required this.statusMessage,
    required this.busy,
    required this.reportRows,
    required this.pendingRafidain,
    required this.periodLabel,
  });

  final String doctorName;
  final String statusMessage;
  final bool busy;
  final int reportRows;
  final int pendingRafidain;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final initial = doctorName.trim().isEmpty ? '?' : doctorName.trim()[0];
    final colors = doctorGradient(doctorName);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white,
            Color.lerp(colors.first, Colors.white, 0.88)!,
            const Color(0xFFF8FBFC),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              left: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.first.withValues(alpha: 0.28),
                      colors.first.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.last.withValues(alpha: 0.45),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctorName,
                              style: GoogleFonts.cairo(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                periodLabel,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              statusMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        busy: busy,
                        label: busy ? 'جاري التحميل' : 'جاهز',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStatMini(
                          icon: Icons.table_rows_rounded,
                          label: 'صفوف التقرير',
                          value: '$reportRows',
                          colors: const [Color(0xFF38BDF8), Color(0xFF0369A1)],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroStatMini(
                          icon: Icons.pending_actions_rounded,
                          label: 'رافدين معلقة',
                          value: '$pendingRafidain',
                          colors: const [Color(0xFFFBBF24), Color(0xFFB45309)],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroStatMini(
                          icon: Icons.verified_rounded,
                          label: 'الحالة',
                          value: busy ? 'تحميل' : 'جاهز',
                          colors: busy
                              ? const [Color(0xFFFBBF24), Color(0xFFB45309)]
                              : const [Color(0xFF34D399), Color(0xFF047857)],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatMini extends StatelessWidget {
  const _HeroStatMini({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.first.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon3D(icon: icon, size: 36, colors: colors),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodModeChip extends StatelessWidget {
  const _PeriodModeChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
              )
            : null,
        color: selected ? null : Colors.transparent,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.tealBright.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterFieldShell extends StatelessWidget {
  const _FilterFieldShell({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DatePickShell extends StatelessWidget {
  const _DatePickShell({
    required this.label,
    required this.value,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderStrong),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: enabled ? AppColors.teal : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateReportButton extends StatelessWidget {
  const _GenerateReportButton({
    required this.busy,
    required this.onPressed,
  });

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealBright.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(150, 58),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(
          'إنشاء التقرير',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _DownloadWordButton extends StatelessWidget {
  const _DownloadWordButton({
    required this.busy,
    required this.onPressed,
  });

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF15803D).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF15803D),
          foregroundColor: Colors.white,
          minimumSize: const Size(150, 58),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.download_rounded),
        label: Text(
          'تنزيل Word',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip({
    required this.title,
    required this.value,
    required this.colors,
    this.emphasized = false,
  });

  final String title;
  final String value;
  final List<Color> colors;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: emphasized ? 210 : 190),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: emphasized
              ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
              : [Colors.white, Color.lerp(colors.first, Colors.white, 0.9)!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasized
              ? const Color(0xFF6EE7B7)
              : colors.first.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: emphasized ? 0.22 : 0.12),
            blurRadius: emphasized ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon3D(icon: Icons.payments_rounded, size: 28, colors: colors),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              fontSize: emphasized ? 16 : 14,
              color: emphasized ? AppColors.emerald : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeApplyField extends StatelessWidget {
  const _FeeApplyField({
    required this.controller,
    required this.label,
    required this.onApply,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: label),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onApply,
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w800,
            color: AppColors.slate,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.unfold_more_rounded, size: 14, color: AppColors.textMuted),
      ],
    );
  }
}
