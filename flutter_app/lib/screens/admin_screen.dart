import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _statsUrl      = 'https://us-central1-projdoc-aab8e.cloudfunctions.net/admin_get_stats';
  static const _addCreditUrl  = 'https://us-central1-projdoc-aab8e.cloudfunctions.net/admin_add_credit';

  List<Map<String, dynamic>> _jobs     = [];
  Map<String, dynamic>       _counts   = {};
  int                        _total    = 0;
  bool                       _loading  = true;
  String?                    _error;
  String                     _filter   = 'all';

  final _creditEmailCtrl = TextEditingController();
  bool   _creditLoading  = false;
  String _creditMessage  = '';

  @override
  void dispose() {
    _creditEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _grantCredit() async {
    final email = _creditEmailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _creditLoading = true; _creditMessage = ''; });
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
      final res = await http.post(
        Uri.parse(_addCreditUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'email': email}),
      );
      if (res.statusCode == 200) {
        setState(() { _creditMessage = 'Credit granted to $email'; });
        _creditEmailCtrl.clear();
      } else {
        final body = json.decode(res.body);
        setState(() { _creditMessage = 'Error: ${body['error'] ?? res.body}'; });
      }
    } catch (e) {
      setState(() { _creditMessage = 'Error: $e'; });
    } finally {
      setState(() { _creditLoading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
      final res   = await http.get(
        Uri.parse(_statsUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        setState(() {
          _jobs   = List<Map<String, dynamic>>.from(body['jobs'] as List);
          _counts = Map<String, dynamic>.from(body['counts'] as Map);
          _total  = body['total'] as int;
        });
      } else {
        setState(() => _error = 'HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _jobs;
    return _jobs.where((j) => j['status'] == _filter).toList();
  }

  String _fmt(dynamic val) {
    if (val == null) return '—';
    final s = val.toString();
    if (s.length > 19) return s.substring(0, 16);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x1A000000),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Admin Dashboard',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF0A0A14))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            tooltip: 'Sign out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _SummaryCards(counts: _counts, total: _total)),
                      SliverToBoxAdapter(child: _FilterBar(
                        current: _filter,
                        counts: _counts,
                        onChanged: (f) => setState(() => _filter = f),
                      )),
                      SliverToBoxAdapter(child: _JobsTable(
                        jobs: _filtered,
                        fmtDate: _fmt,
                      )),
                      SliverToBoxAdapter(child: _GrantCreditCard(
                        emailCtrl: _creditEmailCtrl,
                        loading: _creditLoading,
                        message: _creditMessage,
                        onGrant: _grantCredit,
                      )),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
    );
  }
}

// ── Summary cards ─────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> counts;
  final int total;
  const _SummaryCards({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CardData('Total',      total.toString(),                     const Color(0xFF6C63FF), Icons.list_alt_rounded),
      _CardData('Done',       (counts['done']       ?? 0).toString(), const Color(0xFF16A34A), Icons.check_circle_outline),
      _CardData('Processing', (counts['processing'] ?? 0).toString(), const Color(0xFF2563EB), Icons.hourglass_top_rounded),
      _CardData('Failed',     (counts['failed']     ?? 0).toString(), const Color(0xFFDC2626), Icons.error_outline),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: cards
            .map((c) => Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SummaryCard(data: c),
                )))
            .toList(),
      ),
    );
  }
}

class _CardData {
  final String label, value;
  final Color  color;
  final IconData icon;
  const _CardData(this.label, this.value, this.color, this.icon);
}

class _SummaryCard extends StatelessWidget {
  final _CardData data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.color, size: 18),
          const SizedBox(height: 8),
          Text(data.value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: data.color)),
          Text(data.label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String current;
  final Map<String, dynamic> counts;
  final ValueChanged<String> onChanged;
  const _FilterBar(
      {required this.current, required this.counts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('all',        'All'),
      ('done',       'Done'),
      ('queued',     'Queued'),
      ('processing', 'Processing'),
      ('failed',     'Failed'),
      ('pending',    'Pending'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filters.map((f) {
          final selected = current == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: selected,
              onSelected: (_) => onChanged(f.$1),
              selectedColor: const Color(0xFFEDE9FF),
              checkmarkColor: const Color(0xFF6C63FF),
              labelStyle: TextStyle(
                color: selected
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF6B7280),
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Jobs table ────────────────────────────────────────────────────────────────

class _JobsTable extends StatelessWidget {
  final List<Map<String, dynamic>> jobs;
  final String Function(dynamic) fmtDate;
  const _JobsTable({required this.jobs, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('No jobs found.',
              style: TextStyle(color: Color(0xFF6B7280))),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${jobs.length} jobs',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A0A14),
                    fontSize: 15)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEF8)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                      const Color(0xFFF7F7FB)),
                  headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF6B7280)),
                  dataTextStyle: const TextStyle(
                      fontSize: 12, color: Color(0xFF0A0A14)),
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('Student')),
                    DataColumn(label: Text('Branch')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Downloaded')),
                  ],
                  rows: jobs.asMap().entries.map((e) {
                    final i   = e.key + 1;
                    final job = e.value;
                    final status = job['status'] as String? ?? 'pending';
                    final downloaded = job['downloaded_at'] != null;
                    return DataRow(cells: [
                      DataCell(Text('$i',
                          style: const TextStyle(
                              color: Color(0xFF6B7280)))),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          job['title'] as String? ?? '—',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      DataCell(Text(
                          job['student_name'] as String? ?? '—')),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          (job['domain'] as String? ?? '—')
                              .split(' ')[0],
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      DataCell(_StatusPill(status: status)),
                      DataCell(Text(fmtDate(job['created_at']),
                          style: const TextStyle(
                              color: Color(0xFF6B7280)))),
                      DataCell(downloaded
                          ? const Icon(Icons.download_done_rounded,
                              size: 16, color: Color(0xFF16A34A))
                          : const Text('—',
                              style: TextStyle(color: Color(0xFF6B7280)))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'done'       => (const Color(0xFFF0FDF4), const Color(0xFF16A34A), 'Done'),
      'processing' => (const Color(0xFFEFF6FF), const Color(0xFF2563EB), 'Processing'),
      'queued'     => (const Color(0xFFFFF7ED), const Color(0xFFD97706), 'Queued'),
      'failed'     => (const Color(0xFFFFF1F2), const Color(0xFFDC2626), 'Failed'),
      'expired'    => (const Color(0xFFF9FAFB), const Color(0xFF9CA3AF), 'Expired'),
      _            => (const Color(0xFFF9FAFB), const Color(0xFF6B7280), 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Grant credit card ─────────────────────────────────────────────────────────

class _GrantCreditCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final bool loading;
  final String message;
  final VoidCallback onGrant;
  const _GrantCreditCard({
    required this.emailCtrl,
    required this.loading,
    required this.message,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final isError = message.startsWith('Error');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEF8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grant Credit',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0A0A14))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Student email',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDDDDEE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDDDDEE)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: loading ? null : onGrant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Grant 1 Credit',
                            style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message,
                  style: TextStyle(
                      fontSize: 12,
                      color: isError
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                      fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
