import 'package:flutter_test/flutter_test.dart';

import 'package:hsabat/domain/services/tamweel_distribution_service.dart';

void main() {
  const service = TamweelDistributionService();

  test('owner gets 75 percent and others split 25 by net', () {
    final shares = service.distribute(
      totalTamweel: 10000,
      selectedDoctors: const ['Owner', 'A', 'B'],
      ownerDoctor: 'Owner',
      doctorNetAmounts: const {
        'Owner': 1000,
        'A': 4000,
        'B': 1000,
      },
    );

    expect(shares['Owner'], 7500);
    expect(shares['A'], 2000);
    expect(shares['B'], 500);
  });

  test('owner alone gets full amount', () {
    final shares = service.distribute(
      totalTamweel: 10000,
      selectedDoctors: const ['Owner'],
      ownerDoctor: 'Owner',
      doctorNetAmounts: const {'Owner': 5000},
    );

    expect(shares['Owner'], 10000);
  });
}
