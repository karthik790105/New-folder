import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates and prints/shares a branded Go Fresh bill for a single order.
/// This bill shows ONLY the item price (not delivery fee) — the rider
/// hands this to the restaurant when collecting the order.
class BillService {
  static final _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String _fmt(num amount) => _currencyFmt.format(amount);

  /// Generates a PDF [Uint8List] for the given [order] map.
  static Future<Uint8List> generateBill(Map<String, dynamic> order) async {
    final pdf = pw.Document();

    // Load Go Fresh logo from assets
    final logoData = await rootBundle.load('assets/images/gofresh_logo.jpg');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final items = (order['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final customerInfo = order['customerInfo'] as Map<String, dynamic>? ?? {};
    final pricing = order['pricing'] as Map<String, dynamic>? ?? {};

    // Item subtotal only (not delivery fee — rider gives this to restaurant)
    final itemsTotal = (pricing['itemsTotal'] as num?)?.toDouble() ?? 0;
    final orderId = (order['_id'] as String? ?? '').toUpperCase();
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final orangeColor = PdfColor.fromHex('#FF6B00');
    final greenColor = PdfColor.fromHex('#2E7D32');
    final lightGray = PdfColor.fromHex('#F5F5F5');
    final darkText = PdfColor.fromHex('#1A1A1A');
    final mutedText = PdfColor.fromHex('#757575');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 56,
                    height: 56,
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(28),
                    ),
                    child: pw.ClipOval(child: pw.Image(logoImage)),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Go Fresh',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: orangeColor,
                        ),
                      ),
                      pw.Text(
                        'From Our Store to Your Door ❤',
                        style: pw.TextStyle(fontSize: 9, color: greenColor),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('RESTAURANT BILL',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: mutedText)),
                      pw.SizedBox(height: 2),
                      pw.Text('#$shortId',
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: darkText)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColor.fromHex('#EEEEEE'), thickness: 1),
              pw.SizedBox(height: 4),

              // ── Info row ──────────────────────────────────────────────
              pw.Row(children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Date', style: pw.TextStyle(fontSize: 9, color: mutedText)),
                      pw.Text(now, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer', style: pw.TextStyle(fontSize: 9, color: mutedText)),
                      pw.Text(customerInfo['name'] ?? 'Customer',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(customerInfo['phone'] ?? '',
                          style: pw.TextStyle(fontSize: 9, color: mutedText)),
                    ],
                  ),
                ),
              ]),

              pw.SizedBox(height: 12),

              // ── Items table ───────────────────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: orangeColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: pw.Row(children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11)),
                  ),
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text('Qty',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
                        textAlign: pw.TextAlign.center),
                  ),
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text('Rate',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
                        textAlign: pw.TextAlign.right),
                  ),
                  pw.SizedBox(
                    width: 55,
                    child: pw.Text('Amount',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
                        textAlign: pw.TextAlign.right),
                  ),
                ]),
              ),

              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                final price = (item['price'] as num?)?.toDouble() ?? 0;
                final total = qty * price;
                return pw.Container(
                  color: i.isEven ? lightGray : PdfColors.white,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: pw.Row(children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(item['name'] ?? '',
                          style: pw.TextStyle(fontSize: 10, color: darkText)),
                    ),
                    pw.SizedBox(
                      width: 30,
                      child: pw.Text('$qty',
                          style: pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.SizedBox(
                      width: 50,
                      child: pw.Text(_fmt(price),
                          style: pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right),
                    ),
                    pw.SizedBox(
                      width: 55,
                      child: pw.Text(_fmt(total),
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                  ]),
                );
              }),

              pw.Divider(color: PdfColor.fromHex('#DDDDDD')),

              // ── Totals ─────────────────────────────────────────────────
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(children: [
                          pw.Text('Items Total:  ',
                              style: pw.TextStyle(fontSize: 10, color: mutedText)),
                          pw.Text(_fmt(itemsTotal),
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkText)),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ── Total box ──────────────────────────────────────────────
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: orangeColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('AMOUNT TO COLLECT',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11)),
                    pw.Text(_fmt(itemsTotal),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ── Note ──────────────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E8F5E9'),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: greenColor, width: 0.5),
                ),
                child: pw.Text(
                  '📌 Note: This bill covers item cost only. Delivery charges are collected separately by Go Fresh.',
                  style: pw.TextStyle(fontSize: 9, color: greenColor),
                ),
              ),

              pw.Spacer(),

              // ── Footer ────────────────────────────────────────────────
              pw.Divider(color: PdfColor.fromHex('#EEEEEE')),
              pw.Center(
                child: pw.Column(children: [
                  pw.Text('Thank you for partnering with Go Fresh!',
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: mutedText,
                          fontStyle: pw.FontStyle.italic)),
                  pw.Text('www.gofresh.in  |  support@gofresh.in',
                      style: pw.TextStyle(fontSize: 8, color: mutedText)),
                ]),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Previews the bill using the system print/share dialog.
  static Future<void> printBill(Map<String, dynamic> order) async {
    final bytes = await generateBill(order);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  /// Shares the bill (WhatsApp, email, etc.) via system share sheet.
  static Future<void> shareBill(Map<String, dynamic> order) async {
    final bytes = await generateBill(order);
    final orderId = (order['_id'] as String? ?? 'order').substring(0, 8);
    await Printing.sharePdf(bytes: bytes, filename: 'GoFresh_Bill_$orderId.pdf');
  }
}
