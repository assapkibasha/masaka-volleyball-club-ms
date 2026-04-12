// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:convert';

String _money(Map<String, dynamic>? value) =>
    value?['formatted'] as String? ?? 'RWF 0';

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _buildRows(List<dynamic> items) {
  if (items.isEmpty) {
    return '<tr><td colspan="5">No entries</td></tr>';
  }

  return items.map((raw) {
    final item = raw as Map<String, dynamic>;
    return '''
      <tr>
        <td>${_escapeHtml(item['memberName'] as String? ?? 'Unknown')}</td>
        <td>${_escapeHtml(item['phone'] as String? ?? '-')}</td>
        <td>${_escapeHtml(item['email'] as String? ?? '-')}</td>
        <td>${_escapeHtml(_money(item['expectedAmount'] as Map<String, dynamic>?))}</td>
        <td>${_escapeHtml(_money(item['paidAmount'] as Map<String, dynamic>?))}</td>
      </tr>
    ''';
  }).join();
}

String _buildRecentPaymentRows(List<dynamic> items) {
  if (items.isEmpty) {
    return '<tr><td colspan="6">No entries</td></tr>';
  }

  return items.map((raw) {
    final item = raw as Map<String, dynamic>;
    final date = DateTime.tryParse(item['paymentDate'] as String? ?? '');
    final dateLabel = date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')} ${_monthLabel(date.month)} ${date.year}';
    final timeLabel = date == null ? '-' : _formatTime(date);
    return '''
      <tr>
        <td>${_escapeHtml(item['id'] as String? ?? '-')}</td>
        <td>${_escapeHtml(item['memberName'] as String? ?? 'Unknown')}</td>
        <td>${_escapeHtml(_money(item['amountPaid'] as Map<String, dynamic>?))}</td>
        <td>${_escapeHtml(item['status'] as String? ?? 'Paid')}</td>
        <td>${_escapeHtml(dateLabel)}</td>
        <td>${_escapeHtml(timeLabel)}</td>
      </tr>
    ''';
  }).join();
}

String _monthLabel(int month) {
  const labels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return labels[month - 1];
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

void _openPrintableHtml(String htmlContent) {
  final blob = html.Blob([utf8.encode(htmlContent)], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

Future<void> printMonthlyReport(Map<String, dynamic> report) async {
  final period = report['period'] as String? ?? 'Monthly Report';
  final paidMembers = report['paidMembers'] as List<dynamic>? ?? const [];
  final peopleToPay = report['peopleToPay'] as List<dynamic>? ?? const [];
  final generatedAt = report['generatedAt'] as String? ?? '';

  final htmlContent =
      '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>MVCS Monthly Report</title>
    <style>
      :root {
        --mvcs-yellow: #FFC107;
        --mvcs-black: #1E1E1E;
        --mvcs-bg: #F4F6F8;
        --mvcs-white: #FFFFFF;
        --mvcs-border: #E0E0E0;
        --mvcs-text-secondary: #757575;
        --mvcs-green: #4CAF50;
        --mvcs-red: #F44336;
      }
      body {
        font-family: Arial, sans-serif;
        padding: 32px;
        color: var(--mvcs-black);
        background: linear-gradient(180deg, #fffdf7 0%, var(--mvcs-bg) 100%);
      }
      .page {
        background: var(--mvcs-white);
        border: 1px solid var(--mvcs-border);
        border-radius: 18px;
        overflow: hidden;
        box-shadow: 0 10px 28px rgba(30, 30, 30, 0.08);
      }
      .hero {
        background: var(--mvcs-black);
        color: var(--mvcs-white);
        padding: 28px 32px 22px;
      }
      .hero-bar {
        width: 72px;
        height: 6px;
        border-radius: 999px;
        background: var(--mvcs-yellow);
        margin-bottom: 14px;
      }
      h1, h2, h3 { margin: 0 0 12px 0; }
      h1 { font-size: 28px; letter-spacing: 0.02em; }
      .hero-subtitle { color: rgba(255,255,255,0.7); font-size: 13px; }
      .content { padding: 28px 32px 32px; }
      .meta {
        margin-bottom: 24px;
        color: var(--mvcs-text-secondary);
        background: #fffaf0;
        border: 1px solid #ffe29a;
        border-radius: 14px;
        padding: 14px 16px;
      }
      .summary, .counts { display: flex; gap: 12px; margin-bottom: 24px; }
      .card {
        flex: 1;
        border: 1px solid var(--mvcs-border);
        border-radius: 14px;
        padding: 16px;
        background: var(--mvcs-white);
      }
      .card.highlight {
        background: #fffaf0;
        border-color: #ffe29a;
      }
      .card.success {
        background: #f4fbf5;
        border-color: #b9dec0;
      }
      .card.danger {
        background: #fff5f5;
        border-color: #f3c0c0;
      }
      .card h3 {
        font-size: 12px;
        color: var(--mvcs-text-secondary);
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }
      .card .value { font-size: 24px; font-weight: 700; margin-top: 8px; }
      .green { color: var(--mvcs-green); }
      .red { color: var(--mvcs-red); }
      .section-title {
        font-size: 16px;
        font-weight: 700;
        margin: 0 0 12px 0;
        padding-left: 12px;
        border-left: 4px solid var(--mvcs-yellow);
      }
      table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 24px;
        overflow: hidden;
        border-radius: 14px;
        border: 1px solid var(--mvcs-border);
      }
      th, td { padding: 10px 12px; text-align: left; font-size: 13px; }
      th {
        background: var(--mvcs-black);
        color: var(--mvcs-white);
        font-weight: 700;
        letter-spacing: 0.03em;
      }
      tr:nth-child(even) td { background: #fafafa; }
      td { border-top: 1px solid #efefef; }
      footer {
        margin-top: 32px;
        padding-top: 16px;
        border-top: 1px solid var(--mvcs-border);
        color: var(--mvcs-text-secondary);
        font-size: 12px;
        text-align: center;
      }
      @media print {
        body { padding: 0; background: #fff; }
        .page { box-shadow: none; border: none; border-radius: 0; }
      }
    </style>
  </head>
  <body>
    <div class="page">
    <div class="hero">
      <div class="hero-bar"></div>
      <h1>MVCS Monthly Contribution Report</h1>
      <div class="hero-subtitle">Masaka Volleyball Club reporting snapshot</div>
    </div>
    <div class="content">
    <div class="meta">
      <div><strong>Period:</strong> ${_escapeHtml(period)}</div>
      <div><strong>Generated At:</strong> ${_escapeHtml(generatedAt)}</div>
    </div>
    <div class="summary">
      <div class="card highlight">
        <h3>Expected Amount</h3>
        <div class="value">${_escapeHtml(_money(report['expectedTotal'] as Map<String, dynamic>?))}</div>
      </div>
      <div class="card success">
        <h3>Total Collected</h3>
        <div class="value green">${_escapeHtml(_money(report['collectedTotal'] as Map<String, dynamic>?))}</div>
      </div>
      <div class="card danger">
        <h3>Outstanding</h3>
        <div class="value red">${_escapeHtml(_money(report['outstandingTotal'] as Map<String, dynamic>?))}</div>
      </div>
    </div>
    <div class="counts">
      <div class="card success">
        <h3>Paid People</h3>
        <div class="value green">${report['paidPeopleCount'] ?? 0}</div>
      </div>
      <div class="card danger">
        <h3>People To Pay</h3>
        <div class="value red">${report['peopleToPayCount'] ?? 0}</div>
      </div>
    </div>
    <h2 class="section-title">Paid Members</h2>
    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th>Phone</th>
          <th>Email</th>
          <th>Expected</th>
          <th>Paid</th>
        </tr>
      </thead>
      <tbody>${_buildRows(paidMembers)}</tbody>
    </table>
    <h2 class="section-title">People To Pay</h2>
    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th>Phone</th>
          <th>Email</th>
          <th>Expected</th>
          <th>Paid</th>
        </tr>
      </thead>
      <tbody>${_buildRows(peopleToPay)}</tbody>
    </table>
    <footer>Generated by MVCS, a product of Higura Ventures</footer>
    </div>
    </div>
    <script>window.print();</script>
  </body>
</html>
''';

  _openPrintableHtml(htmlContent);
}

Future<void> printRecentPaymentsReport(Map<String, dynamic> report) async {
  final generatedAtRaw = report['generatedAt'] as String? ?? '';
  final generatedAt = DateTime.tryParse(generatedAtRaw);
  final dateLabel = generatedAt == null
      ? '-'
      : '${generatedAt.day.toString().padLeft(2, '0')} ${_monthLabel(generatedAt.month)} ${generatedAt.year}';
  final payments = report['payments'] as List<dynamic>? ?? const [];

  final htmlContent =
      '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>MVCS Recent Payments Report</title>
    <style>
      :root {
        --mvcs-yellow: #FFC107;
        --mvcs-black: #1E1E1E;
        --mvcs-bg: #F4F6F8;
        --mvcs-white: #FFFFFF;
        --mvcs-border: #E0E0E0;
        --mvcs-text-secondary: #757575;
        --mvcs-green: #4CAF50;
      }
      body {
        font-family: Arial, sans-serif;
        padding: 32px;
        color: var(--mvcs-black);
        background: linear-gradient(180deg, #fffdf7 0%, var(--mvcs-bg) 100%);
      }
      .page {
        background: var(--mvcs-white);
        border: 1px solid var(--mvcs-border);
        border-radius: 18px;
        overflow: hidden;
        box-shadow: 0 10px 28px rgba(30, 30, 30, 0.08);
      }
      .hero {
        background: var(--mvcs-black);
        color: var(--mvcs-white);
        padding: 28px 32px 22px;
      }
      .hero-bar {
        width: 72px;
        height: 6px;
        border-radius: 999px;
        background: var(--mvcs-yellow);
        margin-bottom: 14px;
      }
      h1 { margin: 0 0 10px 0; font-size: 28px; }
      .hero-subtitle { color: rgba(255,255,255,0.7); font-size: 13px; }
      .content { padding: 28px 32px 32px; }
      .meta {
        margin-bottom: 20px;
        line-height: 1.7;
        background: #fffaf0;
        border: 1px solid #ffe29a;
        border-radius: 14px;
        padding: 14px 16px;
      }
      .meta strong { display: inline-block; width: 110px; }
      table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 12px;
        border: 1px solid var(--mvcs-border);
        border-radius: 14px;
        overflow: hidden;
      }
      th, td { padding: 10px 12px; text-align: left; font-size: 13px; }
      th {
        background: var(--mvcs-black);
        color: var(--mvcs-white);
        font-weight: 700;
      }
      tr:nth-child(even) td { background: #fafafa; }
      td { border-top: 1px solid #efefef; }
      .total { margin-top: 24px; width: 360px; }
      .section-title {
        margin-top: 24px;
        font-size: 16px;
        font-weight: 700;
        padding-left: 12px;
        border-left: 4px solid var(--mvcs-yellow);
      }
      .amount { color: var(--mvcs-green); font-weight: 700; }
      footer {
        margin-top: 32px;
        padding-top: 16px;
        border-top: 1px solid var(--mvcs-border);
        color: var(--mvcs-text-secondary);
        font-size: 12px;
        text-align: center;
      }
      @media print {
        body { padding: 0; background: #fff; }
        .page { box-shadow: none; border: none; border-radius: 0; }
      }
    </style>
  </head>
  <body>
    <div class="page">
    <div class="hero">
      <div class="hero-bar"></div>
      <h1>RECENT PAYMENTS REPORT</h1>
      <div class="hero-subtitle">Latest recorded payments summary</div>
    </div>
    <div class="content">
    <div class="meta">
      <div><strong>Date:</strong> ${_escapeHtml(dateLabel)}</div>
      <div><strong>Organization:</strong> ${_escapeHtml(report['organization'] as String? ?? 'Masaka Volleyball Club')}</div>
    </div>
    <div class="section-title">Payments</div>
    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Member Name</th>
          <th>Amount (RWF)</th>
          <th>Status</th>
          <th>Date</th>
          <th>Time</th>
        </tr>
      </thead>
      <tbody>${_buildRecentPaymentRows(payments)}</tbody>
    </table>
    <div class="section-title">TOTAL</div>
    <table class="total">
      <thead>
        <tr>
          <th>Metric</th>
          <th>Value</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Total Payments</td>
          <td>${report['totalPayments'] ?? 0}</td>
        </tr>
        <tr>
          <td>Total Amount Collected</td>
          <td class="amount">${_escapeHtml(_money(report['totalAmountCollected'] as Map<String, dynamic>?))}</td>
        </tr>
      </tbody>
    </table>
    <footer>Generated by MVCS, a product of Higura Ventures</footer>
    </div>
    </div>
    <script>window.print();</script>
  </body>
</html>
''';

  _openPrintableHtml(htmlContent);
}
