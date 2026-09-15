import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../controllers/main_dashboard_controller.dart';
import '../widgets/premium_ui.dart';
import 'doctor_details_screen.dart';
import 'home_doctors_screen.dart';
import 'settings_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen>
    with SingleTickerProviderStateMixin {
  late final MainDashboardController _controller;
  late final AnimationController _brandPulse;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = MainDashboardController();
    _controller.initialize();
    _brandPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _brandPulse.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeDoctorsScreen(
        controller: _controller,
        onOpenDoctor: (doctorName) {
          Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 420),
              reverseTransitionDuration: const Duration(milliseconds: 280),
              pageBuilder: (context, animation, secondaryAnimation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: DoctorDetailsScreen(
                      controller: _controller,
                      doctorName: doctorName,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      SettingsScreen(controller: _controller),
    ];

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _PremiumSidebar(
                  selectedIndex: _selectedIndex,
                  brandPulse: _brandPulse,
                  onSelect: (index) => setState(() => _selectedIndex = index),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey(_selectedIndex),
                      child: pages[_selectedIndex],
                    ),
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

class _PremiumSidebar extends StatelessWidget {
  const _PremiumSidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.brandPulse,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AnimationController brandPulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.ink, AppColors.inkSoft, AppColors.slate],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: AppColors.tealBright.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: brandPulse,
                  builder: (context, child) {
                    final glow = 0.25 + brandPulse.value * 0.25;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.tealBright.withValues(alpha: glow),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: const Icon3D(
                    icon: Icons.health_and_safety_rounded,
                    size: 48,
                    colors: [Color(0xFF5EEAD4), Color(0xFF0F766E)],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dental Pro',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'نظام نسب الأطباء',
                        style: GoogleFonts.cairo(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _NavItem(
            selected: selectedIndex == 0,
            label: 'الرئيسية',
            icon: Icons.grid_view_rounded,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            selected: selectedIndex == 1,
            label: 'الإعدادات',
            icon: Icons.tune_rounded,
            onTap: () => onSelect(1),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.tealBright,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.tealBright.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Xanthus',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'قراءة فقط · آمن',
                    style: GoogleFonts.cairo(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.selected
                ? const LinearGradient(
                    colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
                  )
                : null,
            color: widget.selected
                ? null
                : (_hovered ? Colors.white.withValues(alpha: 0.06) : Colors.transparent),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: AppColors.tealBright.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
            border: Border.all(
              color: widget.selected
                  ? AppColors.tealBright.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.label,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
