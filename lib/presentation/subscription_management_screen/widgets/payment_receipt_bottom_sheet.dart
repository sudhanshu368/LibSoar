import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';

class PaymentReceiptBottomSheet extends StatelessWidget {
  final String receiptNo;
  final String date;
  final String planName;
  final String libraryName;
  final String paymentMethod;
  final String remarks;
  final int amount;

  const PaymentReceiptBottomSheet({
    super.key,
    required this.receiptNo,
    required this.date,
    required this.planName,
    required this.libraryName,
    required this.paymentMethod,
    required this.remarks,
    required this.amount,
  });

  static void show(BuildContext context, {
    required String receiptNo,
    required String date,
    required String planName,
    required String libraryName,
    required String paymentMethod,
    required String remarks,
    required int amount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentReceiptBottomSheet(
        receiptNo: receiptNo,
        date: date,
        planName: planName,
        libraryName: libraryName,
        paymentMethod: paymentMethod,
        remarks: remarks,
        amount: amount,
      ),
    );
  }

  String _formatAmount(int amt) {
    if (amt >= 10000) {
      return '₹${amt.toString().replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+$)"), (m) => "${m[1]},")}';
    } else if (amt >= 1000) {
      final s = amt.toString();
      return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return '₹$amt';
  }

  Future<void> _handlePrint() async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await _generatePdf(format);
      },
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    await downloadReceipt(
      context,
      receiptNo: receiptNo,
      date: date,
      planName: planName,
      libraryName: libraryName,
      paymentMethod: paymentMethod,
      remarks: remarks,
      amount: amount,
      popContext: true,
    );
  }

  static Future<void> downloadReceipt(BuildContext context, {
    required String receiptNo,
    required String date,
    required String planName,
    required String libraryName,
    required String paymentMethod,
    required String remarks,
    required int amount,
    bool popContext = false,
  }) async {
    try {
      final sheet = PaymentReceiptBottomSheet(
        receiptNo: receiptNo,
        date: date,
        planName: planName,
        libraryName: libraryName,
        paymentMethod: paymentMethod,
        remarks: remarks,
        amount: amount,
      );

      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          var manage = await Permission.manageExternalStorage.request();
          if (!manage.isGranted) {
            final pdfBytes = await sheet._generatePdf(PdfPageFormat.a4);
            await Printing.sharePdf(bytes: pdfBytes, filename: 'Receipt_$receiptNo.pdf');
            if (context.mounted && popContext) Navigator.pop(context);
            return;
          }
        }

        final pdfBytes = await sheet._generatePdf(PdfPageFormat.a4);
        final dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        
        final file = File('${dir.path}/Receipt_$receiptNo.pdf');
        await file.writeAsBytes(pdfBytes);
        
        if (context.mounted) {
          if (popContext) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt downloaded to Downloads folder!'),
              backgroundColor: Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final sheet = PaymentReceiptBottomSheet(
          receiptNo: receiptNo, date: date, planName: planName, libraryName: libraryName, paymentMethod: paymentMethod, remarks: remarks, amount: amount,
        );
        final pdfBytes = await sheet._generatePdf(PdfPageFormat.a4);
        await Printing.sharePdf(bytes: pdfBytes, filename: 'Receipt_$receiptNo.pdf');
        if (context.mounted && popContext) Navigator.pop(context);
      }
    } catch (e) {
      try {
        final sheet = PaymentReceiptBottomSheet(
          receiptNo: receiptNo, date: date, planName: planName, libraryName: libraryName, paymentMethod: paymentMethod, remarks: remarks, amount: amount,
        );
        final pdfBytes = await sheet._generatePdf(PdfPageFormat.a4);
        await Printing.sharePdf(bytes: pdfBytes, filename: 'Receipt_$receiptNo.pdf');
      } catch (_) {}
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                color: PdfColor.fromHex('#4F46E5'),
                padding: const pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Vin Library Patna', style: pw.TextStyle(color: PdfColors.white, fontSize: 32, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('LibSoar · Subscription', style: pw.TextStyle(color: PdfColors.white, fontSize: 16)),
                    pw.SizedBox(height: 16),
                    pw.Text('+91 98765 43210 | contact@libsoar.com', style: pw.TextStyle(color: PdfColor.fromHex('#E0E7FF'), fontSize: 14)),
                  ]
                )
              ),
              
              // Body
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Center Title
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.Text('PAYMENT RECEIPT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                            pw.SizedBox(height: 4),
                            pw.Container(width: 60, height: 3, color: PdfColor.fromHex('#4F46E5')),
                          ]
                        )
                      ),
                      pw.SizedBox(height: 40),
                      
                      // Two-column layout
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Receipt No', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12)),
                              pw.SizedBox(height: 4),
                              pw.Text(receiptNo, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            ]
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('Date', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12)),
                              pw.SizedBox(height: 4),
                              pw.Text(date, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            ]
                          ),
                        ]
                      ),
                      pw.SizedBox(height: 32),
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 24),
                      
                      // Subscription Details
                      pw.Text('SUBSCRIPTION DETAILS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Plan', style: pw.TextStyle(color: PdfColors.grey700)),
                          pw.Text(planName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                      
                      pw.SizedBox(height: 24),
                      
                      // Payment Details
                      pw.Text('PAYMENT DETAILS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Payment Method', style: pw.TextStyle(color: PdfColors.grey700)),
                          pw.Text(paymentMethod, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Channel', style: pw.TextStyle(color: PdfColors.grey700)),
                          pw.Text('Online', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                      
                      pw.SizedBox(height: 24),
                      
                      // Remarks
                      pw.Text('REMARKS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                      pw.SizedBox(height: 8),
                      pw.Text(remarks, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 13, lineSpacing: 2)),
                      
                      pw.SizedBox(height: 40),
                      
                      // Highlight Box
                      pw.Center(
                        child: pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(vertical: 24),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F3F4F6'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text('Total Amount Paid', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 14)),
                              pw.SizedBox(height: 8),
                              pw.Text(_formatAmount(amount), style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4F46E5'))),
                            ]
                          )
                        )
                      ),
                      
                      pw.Spacer(),
                      
                      // Footer
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 16),
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.Text('Thank you for your payment!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                            pw.SizedBox(height: 4),
                            pw.Text('LibSoar', style: pw.TextStyle(color: PdfColors.grey600)),
                            pw.Text('Smart library management', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
                            pw.SizedBox(height: 16),
                            pw.Text('This is a computer-generated receipt and does not require a signature.', style: pw.TextStyle(color: PdfColors.grey400, fontSize: 9, fontStyle: pw.FontStyle.italic)),
                            pw.SizedBox(height: 4),
                            pw.Text('Generated: ${DateTime.now().toLocal().toString().split('.')[0]}', style: pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                          ]
                        )
                      )
                    ]
                  )
                )
              )
            ]
          );
        }
      )
    );
    
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title and Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment receipt',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Center Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                libraryName,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4F46E5),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'LibSoar · Subscription',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Divider
          const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 1),
          const SizedBox(height: 20),

          // Details Section
          _buildDetailRowUI('Receipt No', receiptNo),
          _buildDetailRowUI('Date', date),
          _buildDetailRowUI('Plan', planName),
          _buildDetailRowUI('Library', libraryName),
          _buildDetailRowUI('Payment method', paymentMethod),
          _buildDetailRowUI('Remarks', remarks),
          const SizedBox(height: 8),

          // Divider
          const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 1),
          const SizedBox(height: 20),

          // Amount Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Amount',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              Text(
                _formatAmount(amount),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Bottom Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handlePrint,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text(
                    'Print',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleDownload(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    'Download',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowUI(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
