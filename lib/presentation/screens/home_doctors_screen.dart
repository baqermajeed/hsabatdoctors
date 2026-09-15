import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../controllers/main_dashboard_controller.dart';
import '../widgets/premium_ui.dart';

class HomeDoctorsScreen extends StatelessWidget {
  const HomeDoctorsScreen({
    super.key,
    required this.controller,
    required this.onOpenDoctor,
  });

  final MainDashboardController controller;
  final ValueChanged<String> onOpenDoctor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'لوحة الأطباء',
                              style: GoogleFonts.cairo(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'اختر الطبيب لعرض كشف التحصيل والصافي النهائي',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        busy: controller.isBusy,
                        label: controller.isBusy ? 'جاري التحميل' : 'جاهز',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: _HeaderStats(controller: controller),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: controller.activeDoctors.isEmpty
                      ? FadeSlideIn(
                          delay: const Duration(milliseconds: 120),
                          child: _EmptyDoctorsState(controller: controller),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            const minCardWidth = 136.0;
                            final calculatedCount =
                                (constraints.maxWidth / minCardWidth).floor();
                            final crossAxisCount = calculatedCount.clamp(1, 8);
                            return GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.88,
                              ),
                              itemCount: controller.activeDoctors.length,
                              itemBuilder: (context, index) {
                                final doctorName = controller.activeDoctors[index];
                                return FadeSlideIn(
                                  delay: Duration(milliseconds: 40 + (index % 12) * 35),
                                  child: _DoctorLuxuryCard(
                                    doctorName: doctorName,
                                    isOwner: controller.isOwnerDoctor(doctorName),
                                    onTap: () => onOpenDoctor(doctorName),
                                  ),
                                );
                              },
                            );
                          },
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

class _HeaderStats extends StatelessWidget {
  const _HeaderStats({required this.controller});
  final MainDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        width: 320,
        child: MetricTile(
          label: 'عدد الأطباء',
          value: '${controller.activeDoctors.length}',
          icon: Icons.groups_2_rounded,
          colors: const [Color(0xFF2DD4BF), Color(0xFF0F766E)],
        ),
      ),
    );
  }
}

class _DoctorLuxuryCard extends StatefulWidget {
  const _DoctorLuxuryCard({
    required this.doctorName,
    required this.onTap,
    this.isOwner = false,
  });

  final String doctorName;
  final VoidCallback onTap;
  final bool isOwner;

  @override
  State<_DoctorLuxuryCard> createState() => _DoctorLuxuryCardState();
}

class _DoctorLuxuryCardState extends State<_DoctorLuxuryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.doctorName.trim().isEmpty ? '?' : widget.doctorName.trim()[0];
    const colors = [Color(0xFF2DD4BF), Color(0xFF0F766E)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 130;
        return HoverLiftCard(
          onTap: widget.onTap,
          borderRadius: 22,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Color.lerp(colors.first, Colors.white, 0.88)!,
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                Positioned(
                  top: -20,
                  left: -10,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.first.withValues(alpha: 0.22),
                          colors.first.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _shine,
                  builder: (context, _) {
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.12,
                          child: Transform.translate(
                            offset: Offset((_shine.value * 220) - 80, 0),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Container(
                                width: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.9),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox.expand(
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 10 : 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: isCompact ? 48 : 58,
                          height: isCompact ? 48 : 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: colors,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.last.withValues(alpha: 0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: isCompact ? 18 : 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 8 : 12),
                        Text(
                          widget.doctorName,
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: isCompact ? 13 : 15,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        if (widget.isOwner) ...[
                          const SizedBox(height: 6),
                          Text(
                            'الطبيب المالك',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.last,
                            ),
                          ),
                        ],
                        if (!isCompact) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.first.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'فتح التقرير',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colors.last,
                              ),
                            ),
                          ),
                        ],
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

class _EmptyDoctorsState extends StatelessWidget {
  const _EmptyDoctorsState({required this.controller});
  final MainDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 560,
        child: GlassPanel(
          glow: true,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon3D(
                icon: Icons.medical_information_rounded,
                size: 72,
                colors: [Color(0xFF5EEAD4), Color(0xFF0F766E)],
              ),
              const SizedBox(height: 16),
              Text(
                controller.officialDoctors.isEmpty
                    ? 'لا توجد قائمة أطباء محملة'
                    : 'لم يتم اختيار أطباء للعرض',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.officialDoctors.isEmpty
                    ? 'اختبر الاتصال أولاً ثم حمّل الأطباء من قاعدة البيانات من صفحة الإعدادات.'
                    : 'من صفحة الإعدادات ضع علامة صح على الأطباء الذين تريد عرضهم وحساب التمويل لهم.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () => controller.refreshDoctorsFromDatabase(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث قائمة الأطباء'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
