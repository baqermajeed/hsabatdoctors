import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/doctor_monthly_payment_row.dart';

class DoctorReportWordExportResult {
  const DoctorReportWordExportResult({
    required this.filePath,
  });

  final String filePath;
}

/// Exports a Farah Center–styled editable Word report (summary + payments).
class DoctorReportWordExporter {
  static final _titleBlue = DocxColor('#1E3A8A');
  static final _mutedText = DocxColor('#334155');
  static const _yellowFill = 'F6D24A';
  static const _headerSoftFill = 'EEF4FF';
  static const _doctorChipFill = 'EAF2FF';
  static const _zebraFill = 'F8FAFC';
  static const _font = 'Arial';
  static const _headerLineColor = '1F2937';

  Future<DoctorReportWordExportResult> export({
    required String doctorName,
    required String periodLabel,
    required List<DoctorMonthlyPaymentRow> rows,
    required double totalAmount,
    required double doctorPercent,
    required double doctorAmount,
    required double appliedTarakeebAmount,
    required double appliedTamweelAmount,
    required double finalDoctorAmount,
    bool revealInExplorer = true,
  }) async {
    final downloadsDir = await _downloadsDirectory();
    final fileName = _buildSuggestedFileName(doctorName, periodLabel);
    final path = p.join(downloadsDir.path, fileName);

    final logoBytes = await _loadLogoPng();

    final amountFormat = NumberFormat('#,##0');
    final percentFormat = NumberFormat('0.##');
    final dateFormat = DateFormat('yyyy/MM/dd');
    final generatedAt = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
    final dateRange = _deriveDateRange(rows, dateFormat);

    final doctorDisplay = doctorName.trim().isEmpty ? doctorName : doctorName.trim();

    final builder = docx()
      ..section(
        pageSize: DocxPageSize.a4,
        marginTop: 0,
        marginBottom: 0,
        marginLeft: 0,
        marginRight: 0,
        header: _buildRepeatingHeader(logoBytes, dateRange.fromDate, dateRange.toDate),
        footer: _buildRepeatingFooter(generatedAt),
      );

    // Body starts under repeated header.
    builder.add(_doctorNameBlock(doctorDisplay));

    final summaryPairs = <(String, String, bool)>[
      ('الفترة', periodLabel, false),
      ('المبلغ الكلي (التحصيل)', amountFormat.format(totalAmount.round()), false),
      (
        '% نسبة الطبيب',
        '${percentFormat.format(doctorPercent)}%',
        false,
      ),
      ('المبلغ بعد النسبة', amountFormat.format(doctorAmount.round()), false),
      (
        'أجور التراكيب المخصومة',
        amountFormat.format(appliedTarakeebAmount.round()),
        false,
      ),
      (
        'أجور التمويل المخصومة',
        amountFormat.format(appliedTamweelAmount.round()),
        false,
      ),
      (
        'المبلغ الصافي النهائي',
        amountFormat.format(finalDoctorAmount.round()),
        true,
      ),
    ];

    builder.add(
      _centeredText(
        "MONTHLY DOCTOR'S STATISTICS",
        fontSize: 16,
        bold: true,
        color: DocxColor.black,
        spacingAfter: 20,
      ),
    );
    builder.add(
      _centeredText(
        'الإحصائيات الشهرية للأطباء',
        fontSize: 13,
        bold: true,
        color: _titleBlue,
        spacingAfter: 80,
      ),
    );
    builder.add(_buildSummaryTable(summaryPairs));
    builder.pageBreak();
    builder.add(_buildUnregisteredAdjustmentsTitle());
    builder.add(
      _buildUnregisteredAdjustmentsTable(
        totalAmount: appliedTarakeebAmount + appliedTamweelAmount,
        amountFormat: amountFormat,
      ),
    );
    builder.pageBreak();
    builder.add(_buildPaymentsTable(rows, dateFormat, amountFormat));

    final doc = builder.build();
    final file = File(path);
    await file.parent.create(recursive: true);
    final bytes = await DocxExporter().exportToBytes(doc);
    final normalizedBytes = _removeTopHeaderSpace(bytes);
    await file.writeAsBytes(normalizedBytes, flush: true);

    if (revealInExplorer) {
      await _revealInExplorer(path);
    }
    return DoctorReportWordExportResult(filePath: p.normalize(path));
  }

  DocxHeader _buildRepeatingHeader(
    Uint8List logoBytes,
    String fromDate,
    String toDate,
  ) {
    return DocxHeader(
      children: [
        _buildPageHeaderTable(logoBytes, fromDate, toDate),
        _headerDivider(),
      ],
    );
  }

  DocxFooter _buildRepeatingFooter(String generatedAt) {
    return DocxFooter(
      children: [
        DocxParagraph(
          align: DocxAlign.center,
          spacingAfter: 0,
          borderBottomSide: DocxBorderSide(
            style: DocxBorder.single,
            color: DocxColor('CBD5E1'),
            size: 6,
          ),
          children: const [DocxText('')],
        ),
        DocxParagraph(
          align: DocxAlign.center,
          spacingAfter: 0,
          children: [
            DocxText(
              'تم إنشاء التقرير: $generatedAt  |  Page ',
              fontFamily: _font,
              fontSize: 8,
              color: _mutedText,
            ),
            const DocxPageNumber(),
            DocxText(
              ' of ',
              fontFamily: _font,
              fontSize: 8,
              color: _mutedText,
            ),
            const DocxPageCount(),
          ],
        ),
      ],
    );
  }

  DocxTable _buildPageHeaderTable(
    Uint8List logoBytes,
    String fromDate,
    String toDate,
  ) {
    const none = DocxBorderSide.none();
    return DocxTable(
      hasHeader: false,
      alignment: DocxAlign.center,
      width: 11200,
      widthType: DocxWidthType.dxa,
      gridColumns: const [3000, 5200, 3000],
      style: const DocxTableStyle(
        border: DocxBorder.none,
        borderWidth: 0,
      ),
      rows: [
        DocxTableRow(
          cells: [
            DocxTableCell(
              verticalAlign: DocxVerticalAlign.center,
              shadingFill: _headerSoftFill,
              borderTop: none,
              borderBottom: none,
              borderLeft: none,
              borderRight: none,
              children: [
                DocxParagraph(
                  align: DocxAlign.left,
                  children: [
                    DocxInlineImage(
                      bytes: logoBytes,
                      extension: 'png',
                      width: 68,
                      height: 68,
                    ),
                  ],
                ),
              ],
            ),
            DocxTableCell(
              verticalAlign: DocxVerticalAlign.center,
              shadingFill: _headerSoftFill,
              borderTop: none,
              borderBottom: none,
              borderLeft: none,
              borderRight: none,
              children: [
                DocxParagraph(
                  align: DocxAlign.center,
                  spacingAfter: 2,
                  children: [
                    DocxText(
                      'FARAH CENTER',
                      fontFamily: _font,
                      fontSize: 13,
                      fontWeight: DocxFontWeight.bold,
                      color: DocxColor.black,
                    ),
                  ],
                ),
                DocxParagraph(
                  align: DocxAlign.center,
                  spacingAfter: 0,
                  children: [
                    DocxText(
                      'مركز فرح التخصصي لطب الاسنان',
                      fontFamily: _font,
                      fontSize: 10,
                      fontWeight: DocxFontWeight.bold,
                      color: _titleBlue,
                    ),
                  ],
                ),
              ],
            ),
            DocxTableCell(
              verticalAlign: DocxVerticalAlign.center,
              shadingFill: _headerSoftFill,
              borderTop: none,
              borderBottom: none,
              borderLeft: none,
              borderRight: none,
              children: [
                DocxParagraph(
                  align: DocxAlign.right,
                  indentRight: 220,
                  spacingAfter: 0,
                  children: [
                    DocxText(
                      'من تاريخ: $fromDate',
                      fontFamily: _font,
                      fontSize: 11,
                      fontWeight: DocxFontWeight.bold,
                      color: DocxColor.black,
                    ),
                  ],
                ),
                DocxParagraph(
                  align: DocxAlign.right,
                  indentRight: 220,
                  spacingAfter: 0,
                  children: [
                    DocxText(
                      'الى تاريخ: $toDate',
                      fontFamily: _font,
                      fontSize: 11,
                      fontWeight: DocxFontWeight.bold,
                      color: DocxColor.black,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  DocxParagraph _headerDivider() {
    return DocxParagraph(
      align: DocxAlign.center,
      indentLeft: 1500,
      indentRight: 1500,
      spacingAfter: 6,
      borderBottomSide: DocxBorderSide(
        style: DocxBorder.single,
        color: DocxColor(_headerLineColor),
        size: 10,
      ),
      children: const [DocxText('')],
    );
  }

  DocxTable _doctorNameBlock(String doctorName) {
    const border = DocxBorderSide(
      style: DocxBorder.single,
      color: DocxColor.black,
      size: 8,
    );
    return DocxTable(
      hasHeader: false,
      alignment: DocxAlign.center,
      width: 11200,
      widthType: DocxWidthType.dxa,
      gridColumns: const [11200],
      style: const DocxTableStyle(
        border: DocxBorder.none,
      ),
      rows: [
        DocxTableRow(
          cells: [
            DocxTableCell(
              shadingFill: _doctorChipFill,
              borderTop: border,
              borderBottom: border,
              borderLeft: border,
              borderRight: border,
              children: [
                DocxParagraph(
                  align: DocxAlign.center,
                  spacingAfter: 80,
                  children: [
                    DocxText(
                      'اسم الطبيب: $doctorName',
                      fontFamily: _font,
                      fontSize: 16,
                      fontWeight: DocxFontWeight.bold,
                      color: DocxColor.black,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  DocxTable _buildSummaryTable(List<(String, String, bool)> pairs) {
    const blackBorder = DocxBorderSide(
      style: DocxBorder.single,
      color: DocxColor.black,
      size: 12,
    );

    DocxTableCell cell(
      String text, {
      required bool highlight,
      String? fill,
    }) {
      return DocxTableCell(
        verticalAlign: DocxVerticalAlign.center,
        shadingFill: highlight ? _yellowFill : fill,
        borderTop: blackBorder,
        borderBottom: blackBorder,
        borderLeft: blackBorder,
        borderRight: blackBorder,
        width: 3600,
        children: [
          DocxParagraph(
            align: DocxAlign.center,
            children: [
              DocxText(
                text,
                fontFamily: _font,
                fontSize: 13,
                fontWeight: DocxFontWeight.bold,
                color: DocxColor.black,
              ),
            ],
          ),
        ],
      );
    }

    return DocxTable(
      hasHeader: false,
      alignment: DocxAlign.center,
      width: 9000,
      widthType: DocxWidthType.dxa,
      gridColumns: const [4500, 4500],
      style: const DocxTableStyle(
        border: DocxBorder.single,
        borderColor: '000000',
        borderWidth: 8,
        cellPadding: 95,
      ),
      rows: [
        for (var i = 0; i < pairs.length; i++)
          DocxTableRow(
            cells: [
              cell(
                pairs[i].$1,
                highlight: pairs[i].$3,
                fill: i == 0 ? _headerSoftFill : null,
              ),
              cell(
                pairs[i].$2,
                highlight: pairs[i].$3,
                fill: i == 0 ? _headerSoftFill : null,
              ),
            ],
          ),
      ],
    );
  }

  DocxParagraph _buildUnregisteredAdjustmentsTitle() {
    return DocxParagraph(
      align: DocxAlign.center,
      spacingAfter: 60,
      children: [
        DocxText(
          'الاستقطاعات والاسترجاعات والتراكيب الغير مسجلة',
          fontFamily: _font,
          fontSize: 16,
          fontWeight: DocxFontWeight.bold,
          color: _titleBlue,
        ),
      ],
    );
  }

  DocxTable _buildUnregisteredAdjustmentsTable({
    required double totalAmount,
    required NumberFormat amountFormat,
  }) {
    const border = DocxBorderSide(
      style: DocxBorder.single,
      color: DocxColor.black,
      size: 8,
    );
    const headerFill = 'F6D24A';
    const totalFill = 'B9FF63';

    DocxTableCell cell(
      String text, {
      String? fill,
      bool bold = false,
      double fontSize = 13,
    }) {
      return DocxTableCell(
        borderTop: border,
        borderBottom: border,
        borderLeft: border,
        borderRight: border,
        shadingFill: fill,
        verticalAlign: DocxVerticalAlign.center,
        children: [
          DocxParagraph(
            align: DocxAlign.center,
            spacingAfter: 0,
            children: [
              DocxText(
                text,
                fontFamily: _font,
                fontSize: fontSize,
                fontWeight: bold ? DocxFontWeight.bold : DocxFontWeight.normal,
                color: DocxColor.black,
              ),
            ],
          ),
        ],
      );
    }

    return DocxTable(
      hasHeader: true,
      alignment: DocxAlign.center,
      width: 7200,
      widthType: DocxWidthType.dxa,
      gridColumns: const [2200, 1800, 3200], // amount, status, name
      style: const DocxTableStyle(
        border: DocxBorder.single,
        borderColor: '000000',
        borderWidth: 8,
        cellPadding: 70,
      ),
      rows: [
        DocxTableRow(
          cells: [
            cell('المبلغ', fill: headerFill, bold: true, fontSize: 14),
            cell('الحالة', fill: headerFill, bold: true, fontSize: 14),
            cell('الاسم', fill: headerFill, bold: true, fontSize: 14),
          ],
        ),
        for (var i = 0; i < 5; i++)
          DocxTableRow(
            cells: [
              cell(''),
              cell(''),
              cell(''),
            ],
          ),
        DocxTableRow(
          cells: [
            cell(amountFormat.format(totalAmount.round()), fill: totalFill, bold: true),
            cell('مجموع', fill: totalFill, bold: true, fontSize: 15),
            cell(''),
          ],
        ),
      ],
    );
  }

  DocxTable _buildPaymentsTable(
    List<DoctorMonthlyPaymentRow> rows,
    DateFormat dateFormat,
    NumberFormat amountFormat,
  ) {
    const headers = <String>[
      '#',
      'المريض',
      'الهاتف',
      'المبلغ المدفوع',
      'تاريخ الدفع',
      'طريقة الدفع',
      'الشهر',
      'عدد أشهر التقسيط',
      'القسط الشهري',
    ];

    // Widths tuned for A4, full-page with zero margins.
    const widths = <int>[500, 2050, 1500, 1350, 1150, 1900, 700, 1100, 1100];

    const blackBorder = DocxBorderSide(
      style: DocxBorder.single,
      color: DocxColor.black,
      size: 8,
    );

    DocxTableCell dataCell(
      String text,
      int width, {
      bool bold = false,
      String? fill,
      double fontSize = 9,
    }) {
      return DocxTableCell(
        verticalAlign: DocxVerticalAlign.center,
        width: width,
        shadingFill: fill,
        borderTop: blackBorder,
        borderBottom: blackBorder,
        borderLeft: blackBorder,
        borderRight: blackBorder,
        children: [
          DocxParagraph(
            align: DocxAlign.center,
            children: [
              DocxText(
                text,
                fontFamily: _font,
                fontSize: fontSize,
                fontWeight: bold ? DocxFontWeight.bold : DocxFontWeight.normal,
                color: DocxColor.black,
              ),
            ],
          ),
        ],
      );
    }

    String dashOr(Object? value) {
      if (value == null) {
        return '-';
      }
      if (value is num) {
        if (value is double) {
          return amountFormat.format(value.round());
        }
        return value.toString();
      }
      final s = value.toString().trim();
      return s.isEmpty ? '-' : s;
    }

    final tableRows = <DocxTableRow>[
      DocxTableRow(
        cells: [
          for (var i = 0; i < headers.length; i++)
            dataCell(
              headers[i],
              widths[i],
              bold: true,
              fill: _headerSoftFill,
              fontSize: 9.5,
            ),
        ],
      ),
      for (var i = 0; i < rows.length; i++)
        DocxTableRow(
          cells: [
            dataCell('${i + 1}', widths[0], fill: i.isOdd ? _zebraFill : null),
            dataCell(rows[i].patientName, widths[1], fill: i.isOdd ? _zebraFill : null),
            dataCell(rows[i].phoneNumber, widths[2], fill: i.isOdd ? _zebraFill : null),
            dataCell(
              amountFormat.format(rows[i].amount.round()),
              widths[3],
              fill: i.isOdd ? _zebraFill : null,
            ),
            dataCell(
              dateFormat.format(rows[i].paymentDate),
              widths[4],
              fill: i.isOdd ? _zebraFill : null,
            ),
            dataCell(
              rows[i].paymentMethod,
              widths[5],
              fill: i.isOdd ? _zebraFill : null,
              fontSize: 8.5,
            ),
            dataCell(
              '${rows[i].paymentDate.month}',
              widths[6],
              fill: i.isOdd ? _zebraFill : null,
            ),
            dataCell(
              dashOr(rows[i].installmentMonths),
              widths[7],
              fill: i.isOdd ? _zebraFill : null,
            ),
            dataCell(
              dashOr(rows[i].monthlyInstallmentAmount),
              widths[8],
              fill: i.isOdd ? _zebraFill : null,
            ),
          ],
        ),
    ];

    return DocxTable(
      hasHeader: true,
      alignment: DocxAlign.center,
      width: 11350,
      widthType: DocxWidthType.dxa,
      gridColumns: widths,
      style: const DocxTableStyle(
        border: DocxBorder.single,
        borderColor: '000000',
        borderWidth: 6,
        cellPadding: 55,
      ),
      rows: tableRows,
    );
  }

  DocxParagraph _centeredText(
    String text, {
    required double fontSize,
    required bool bold,
    required DocxColor color,
    int spacingAfter = 0,
  }) {
    return DocxParagraph(
      align: DocxAlign.center,
      spacingAfter: spacingAfter,
      children: [
        DocxText(
          text,
          fontFamily: _font,
          fontSize: fontSize,
          fontWeight: bold ? DocxFontWeight.bold : DocxFontWeight.normal,
          color: color,
        ),
      ],
    );
  }

  ({String fromDate, String toDate}) _deriveDateRange(
    List<DoctorMonthlyPaymentRow> rows,
    DateFormat dateFormat,
  ) {
    if (rows.isEmpty) {
      final now = dateFormat.format(DateTime.now());
      return (fromDate: now, toDate: now);
    }

    var minDate = rows.first.paymentDate;
    var maxDate = rows.first.paymentDate;
    for (final row in rows.skip(1)) {
      if (row.paymentDate.isBefore(minDate)) {
        minDate = row.paymentDate;
      }
      if (row.paymentDate.isAfter(maxDate)) {
        maxDate = row.paymentDate;
      }
    }

    return (
      fromDate: dateFormat.format(minDate),
      toDate: dateFormat.format(maxDate),
    );
  }

  Future<Uint8List> _loadLogoPng() async {
    // Prefer prepared transparent logo; fallback to original.
    for (final candidate in [
      'assets/brand/farah_logo_export.png',
      'assets/brand/farahapplogo.png',
    ]) {
      try {
        return await _loadAssetBytes(candidate);
      } catch (_) {
        // try next
      }
    }
    throw StateError('تعذر تحميل لوقو Farah من assets/brand.');
  }

  /// Some Word generators keep a default header distance (0.5 inch).
  /// This forces top/header/footer/gutter page margins to zero in document.xml.
  Uint8List _removeTopHeaderSpace(Uint8List docxBytes) {
    final archive = ZipDecoder().decodeBytes(docxBytes);
    final out = Archive();

    for (final file in archive.files) {
      if (!file.isFile) continue;
      var data = file.content as List<int>;

      if (file.name == 'word/document.xml') {
        var xml = utf8.decode(data);
        xml = xml.replaceAllMapped(RegExp(r'<w:pgMar\b[^>]*/>'), (match) {
          var tag = match.group(0)!;
          tag = _setXmlAttribute(tag, 'w:top', '0');
          tag = _setXmlAttribute(tag, 'w:bottom', '0');
          tag = _setXmlAttribute(tag, 'w:left', '0');
          tag = _setXmlAttribute(tag, 'w:right', '0');
          tag = _setXmlAttribute(tag, 'w:header', '0');
          tag = _setXmlAttribute(tag, 'w:footer', '0');
          tag = _setXmlAttribute(tag, 'w:gutter', '0');
          return tag;
        });
        data = utf8.encode(xml);
      }

      out.addFile(ArchiveFile(file.name, data.length, data));
    }

    final encoded = ZipEncoder().encode(out);
    return Uint8List.fromList(encoded);
  }

  String _setXmlAttribute(String tag, String attr, String value) {
    final attrPattern = RegExp('$attr="[^"]*"');
    if (attrPattern.hasMatch(tag)) {
      return tag.replaceFirst(attrPattern, '$attr="$value"');
    }
    return tag.replaceFirst('/>', ' $attr="$value"/>');
  }

  Future<Uint8List> _loadAssetBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      final file = await _resolveAssetFile(assetPath);
      if (file != null) {
        return file.readAsBytes();
      }
      rethrow;
    }
  }

  Future<File?> _resolveAssetFile(String assetPath) async {
    final candidates = <String>[
      assetPath,
      p.join(Directory.current.path, assetPath),
      p.normalize(p.join(Directory.current.path, '..', assetPath)),
      p.normalize(p.join(Directory.current.path, '..', '..', assetPath)),
    ];

    // When running a Windows release/debug exe, assets may sit beside the binary.
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates.addAll([
        p.join(exeDir, 'data', 'flutter_assets', assetPath),
        p.join(exeDir, assetPath),
      ]);
    } catch (_) {}

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
    }
    return null;
  }

  Future<Directory> _downloadsDirectory() async {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      final downloads = Directory(p.join(userProfile, 'Downloads'));
      if (await downloads.exists()) {
        return downloads;
      }
      await downloads.create(recursive: true);
      return downloads;
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      final downloads = Directory(p.join(home, 'Downloads'));
      await downloads.create(recursive: true);
      return downloads;
    }

    final fallback = Directory(p.join(Directory.systemTemp.path, 'hsabat_exports'));
    await fallback.create(recursive: true);
    return fallback;
  }

  Future<void> _revealInExplorer(String filePath) async {
    if (!Platform.isWindows) {
      return;
    }
    try {
      await Process.run('explorer.exe', ['/select,', filePath]);
    } catch (_) {
      // Ignore explorer failures; file is already saved.
    }
  }

  String _buildSuggestedFileName(String doctorName, String periodLabel) {
    final safeDoctor = doctorName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final safePeriod = periodLabel
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'doctor_report_${safeDoctor}_${safePeriod}_$stamp.docx';
  }
}
