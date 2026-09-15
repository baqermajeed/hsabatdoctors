class DoctorMonthlyPaymentRow {
  const DoctorMonthlyPaymentRow({
    required this.paymentId,
    required this.invoiceId,
    required this.patientName,
    required this.phoneNumber,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.treatmentDoctor,
    required this.isRafidainInstallmentSource,
    this.installmentMonths,
    this.monthlyInstallmentAmount,
  });

  final String paymentId;
  final String invoiceId;
  final String patientName;
  final String phoneNumber;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String treatmentDoctor;
  final bool isRafidainInstallmentSource;
  final int? installmentMonths;
  final double? monthlyInstallmentAmount;
}
