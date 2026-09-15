import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/database_config.dart';
import '../../core/theme/app_colors.dart';
import '../controllers/main_dashboard_controller.dart';
import '../widgets/premium_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
  });

  final MainDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: ListView(
              children: [
                FadeSlideIn(
                  child: Text(
                    'الإعدادات والاتصال',
                    style: GoogleFonts.cairo(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: Text(
                    'اتصال آمن بقراءة فقط مع XanthusClinicsData',
                    style: GoogleFonts.cairo(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: GlassPanel(
                    glow: true,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                          title: 'قاعدة البيانات',
                          subtitle: 'SQL Server · Windows / SQL Auth',
                          icon: Icons.storage_rounded,
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 280,
                              child: TextField(
                                controller: controller.serverController,
                                decoration: const InputDecoration(labelText: 'SQL Server'),
                              ),
                            ),
                            SizedBox(
                              width: 240,
                              child: TextField(
                                controller: controller.databaseController,
                                decoration: const InputDecoration(labelText: 'Database'),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: TextField(
                                controller: controller.portController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Port'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<SqlAuthMode>(
                          segments: const [
                            ButtonSegment<SqlAuthMode>(
                              value: SqlAuthMode.windows,
                              label: Text('Windows Auth'),
                              icon: Icon(Icons.desktop_windows_rounded),
                            ),
                            ButtonSegment<SqlAuthMode>(
                              value: SqlAuthMode.sqlServer,
                              label: Text('SQL Auth'),
                              icon: Icon(Icons.lock_outline_rounded),
                            ),
                          ],
                          selected: <SqlAuthMode>{controller.authMode},
                          showSelectedIcon: false,
                          onSelectionChanged: controller.isBusy
                              ? null
                              : (selection) {
                                  if (selection.isNotEmpty) {
                                    controller.setAuthMode(selection.first);
                                  }
                                },
                        ),
                        if (controller.authMode == SqlAuthMode.sqlServer) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 240,
                                child: TextField(
                                  controller: controller.usernameController,
                                  decoration: const InputDecoration(labelText: 'Username'),
                                ),
                              ),
                              SizedBox(
                                width: 240,
                                child: TextField(
                                  controller: controller.passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(labelText: 'Password'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: controller.isBusy ? null : controller.testConnection,
                              icon: const Icon(Icons.link_rounded),
                              label: const Text('اختبار الاتصال'),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.isBusy ? null : controller.loadPaymentSample,
                              icon: const Icon(Icons.dataset_linked_outlined),
                              label: const Text('تحميل عينة الدفعات'),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.isBusy
                                  ? null
                                  : () => controller.refreshDoctorsFromDatabase(),
                              icon: const Icon(Icons.person_search_outlined),
                              label: const Text('تحميل الأطباء'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: GlassPanel(
                    glow: true,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                          title: 'نسخ احتياطي لخطط الأقساط (VPS)',
                          subtitle:
                              'نسخة شاملة: الأقساط + إعدادات المحاسبة المحلية · رفع يومي تلقائي عبر Windows حتى لو التطبيق مغلق',
                          icon: Icons.cloud_done_rounded,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline_rounded, color: AppColors.teal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'إعدادات الخادم مُثبتة داخل التطبيق · الاتصال والرفع يتمان تلقائياً.',
                                  style: GoogleFonts.cairo(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          controller.lastPlansBackupLabel,
                          style: GoogleFonts.cairo(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.autoBackupStatusLabel,
                          style: GoogleFonts.cairo(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: controller.isBusy
                                  ? null
                                  : controller.enableAutomaticDailyBackup,
                              icon: const Icon(Icons.schedule_rounded),
                              label: const Text('إعادة تهيئة الرفع التلقائي'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: controller.isBusy
                                  ? null
                                  : controller.backupPlansToServer,
                              icon: const Icon(Icons.cloud_upload_rounded),
                              label: const Text('رفع باك أب الآن'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: controller.isBusy
                                  ? null
                                  : controller.restorePlansFromServer,
                              icon: const Icon(Icons.cloud_download_rounded),
                              label: const Text('استعادة من السيرفر'),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.isBusy
                                  ? null
                                  : controller.testPlansApiConnection,
                              icon: const Icon(Icons.wifi_tethering_rounded),
                              label: const Text('اختبار الاتصال'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: GlassPanel(
                    glow: true,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                          title: 'الأطباء المشمولون بالحساب',
                          subtitle:
                              'ضع علامة على الأطباء للعرض في الصفحة الرئيسية وحساب التمويل · حدّد المالك لـ 75%',
                          icon: Icons.checklist_rtl_rounded,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: controller.totalTamweelController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'إجمالي أجور التمويل',
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: controller.isBusy
                                  ? null
                                  : controller.saveTotalTamweelAmount,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('حفظ المبلغ'),
                            ),
                            FilledButton.icon(
                              onPressed: controller.isBusy
                                  ? null
                                  : controller.recalculateTamweelDistribution,
                              icon: const Icon(Icons.account_balance_rounded),
                              label: const Text('توزيع التمويل على المختارين'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'المختارون: ${controller.activeDoctors.length} من ${controller.officialDoctors.length}'
                          '${controller.ownerDoctorName == null ? ' · لم يُحدد المالك' : ' · المالك: ${controller.ownerDoctorName}'}',
                          style: GoogleFonts.cairo(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (controller.officialDoctors.isEmpty)
                          Text(
                            'حمّل قائمة الأطباء من قاعدة البيانات أولاً.',
                            style: GoogleFonts.cairo(color: AppColors.textSecondary),
                          )
                        else
                          _DoctorsSelectionTable(controller: controller),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon3D(
                          icon: controller.isBusy
                              ? Icons.hourglass_top_rounded
                              : Icons.check_circle_rounded,
                          size: 52,
                          colors: controller.isBusy
                              ? const [Color(0xFFFBBF24), Color(0xFFB45309)]
                              : const [Color(0xFF34D399), Color(0xFF047857)],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.statusMessage,
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الأطباء المحمّلون: ${controller.officialDoctors.length} · المعروضون: ${controller.activeDoctors.length}',
                                style: GoogleFonts.cairo(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DoctorsSelectionTable extends StatelessWidget {
  const _DoctorsSelectionTable({required this.controller});

  final MainDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong.withValues(alpha: 0.55)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width > 720
                ? MediaQuery.sizeOf(context).width - 120
                : 640,
          ),
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            columns: [
              DataColumn(
                label: Text(
                  'عرض / حساب',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
              DataColumn(
                label: Text(
                  'المالك (75%)',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
              DataColumn(
                label: Text(
                  'اسم الطبيب',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
              DataColumn(
                label: Text(
                  'حصة التمويل',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            ],
            rows: [
              for (final doctorName in controller.officialDoctors)
                DataRow(
                  cells: [
                    DataCell(
                      Checkbox(
                        value: controller.isDoctorSelected(doctorName),
                        onChanged: controller.isBusy
                            ? null
                            : (value) => controller.toggleDoctorSelection(
                                  doctorName,
                                  value ?? false,
                                ),
                      ),
                    ),
                    DataCell(
                      Radio<String>(
                        value: doctorName,
                        groupValue: controller.ownerDoctorName,
                        toggleable: true,
                        onChanged: controller.isBusy
                            ? null
                            : (value) => controller.setOwnerDoctor(value),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Text(
                            doctorName,
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                          ),
                          if (controller.isOwnerDoctor(doctorName)) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'مالك',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F766E),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        controller.isDoctorSelected(doctorName)
                            ? controller.tamweelShareFor(doctorName).toStringAsFixed(0)
                            : '—',
                        style: GoogleFonts.cairo(
                          color: controller.isDoctorSelected(doctorName)
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
