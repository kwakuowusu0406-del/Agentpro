// reports_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'month';
  String _format = 'pdf';
  bool _loading = false;

  Future<void> _download(String type) async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(
        '/reports/$type',
        queryParameters: {'period': _period, 'format': _format},
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getTemporaryDirectory();
      final ext = _format;
      final file = File('${dir.path}/${type}_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(res.data);
      await OpenFile.open(file.path);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate report'), backgroundColor: AppTheme.errorColor));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: LoadingOverlay(
        isLoading: _loading,
        message: 'Generating report...',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period selector
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Period', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final p in ['today', 'week', 'month', 'year'])
                    ChoiceChip(label: Text(p[0].toUpperCase() + p.substring(1)),
                      selected: _period == p, onSelected: (_) => setState(() => _period = p)),
                ]),
                const SizedBox(height: 12),
                const Text('Format', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final f in ['pdf', 'excel', 'csv'])
                    ChoiceChip(label: Text(f.toUpperCase()),
                      selected: _format == f, onSelected: (_) => setState(() => _format = f)),
                ]),
              ]),
            )),
            const SizedBox(height: 16),
            const SectionHeader(title: 'AVAILABLE REPORTS'),
            const SizedBox(height: 8),
            _ReportTile(
              icon: Icons.receipt_long_outlined, color: AppTheme.primaryColor,
              title: 'Transaction Report', subtitle: 'All transactions with status and amounts',
              onTap: () => _download('transactions'),
            ),
            _ReportTile(
              icon: Icons.payments_outlined, color: AppTheme.successColor,
              title: 'Commission Report', subtitle: 'Gross, provider share, and net commission',
              onTap: () => _download('commissions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon; final Color color;
  final String title, subtitle; final VoidCallback onTap;
  const _ReportTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.download_outlined, color: AppTheme.primaryColor),
      onTap: onTap,
    ));
  }
}
