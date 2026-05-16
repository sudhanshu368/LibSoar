import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/profile_model.dart';

class PdfHelper {
  static Future<void> generatePaymentReceipt({
    required PaymentModel payment,
    required LibraryModel? library,
    required String? receivedBy,
    bool isDownload = true,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("PAYMENT RECEIPT",
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 24,
                                color: PdfColors.indigo)),
                        pw.Text("Receipt No: ${payment.receiptNo ?? 'REC-${payment.id.substring(0, 8).toUpperCase()}'}",
                            style: pw.TextStyle(font: font, fontSize: 12)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(library?.name ?? "Library Name",
                            style: pw.TextStyle(font: fontBold, fontSize: 16)),
                        pw.Text(library?.address ?? "Address",
                            style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text(library?.phone ?? "Phone",
                            style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoItem("Student Name", payment.studentName, font, fontBold),
                        _pdfInfoItem("Payment Date", payment.paymentDate.split('T')[0], font, fontBold),
                        _pdfInfoItem("Payment Method", payment.paymentMethod, font, fontBold),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoItem("Received By", receivedBy ?? "-", font, fontBold),
                        _pdfInfoItem("Status", payment.status.toUpperCase(), font, fontBold),
                        _pdfInfoItem("Remarks", "", font, fontBold),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("TOTAL AMOUNT",
                          style: pw.TextStyle(font: fontBold, fontSize: 14)),
                      pw.Text("₹${payment.amount.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 24,
                              color: PdfColors.indigo)),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text("LibSoar",
                          style: pw.TextStyle(font: fontBold, fontSize: 14)),
                      pw.Text("Smart library management",
                          style: pw.TextStyle(font: font, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (isDownload) {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'receipt-${payment.receiptNo ?? payment.id}.pdf');
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    }
  }

  static pw.Widget _pdfInfoItem(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 11)),
        ],
      ),
    );
  }
}
