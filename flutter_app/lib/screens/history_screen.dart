import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('uid', isEqualTo: uid)
            .orderBy('created_at', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            );
          }
          if (snap.hasError) {
            return _ErrorState(error: snap.error.toString());
          }
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) return const _EmptyState();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text('${docs.length} report${docs.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A0A14),
                          )),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 13, color: Color(0xFF6C63FF)),
                            const SizedBox(width: 4),
                            Text(
                              '${docs.where((d) => (d.data() as Map)['status'] == 'done').length} done',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ReportCard(data: d, jobId: docs[i].id),
                    );
                  },
                  childCount: docs.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EEFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 52, color: Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 20),
          const Text('No reports yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A0A14))),
          const SizedBox(height: 8),
          Text(
            'Hit "Generate" to create your first\n94-page project report.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Could not load reports',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String jobId;
  const _ReportCard({required this.data, required this.jobId});

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts as Timestamp).toDate();
    return DateFormat('d MMM yyyy · h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final status      = data['status'] as String? ?? 'pending';
    final isDone      = status == 'done';
    final isFailed    = status == 'failed';
    final isExpired   = status == 'expired';
    final isProcessing = status == 'processing';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EEFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded,
                      size: 20, color: Color(0xFF6C63FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? 'Untitled',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0A0A14),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        data['client'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
              ],
            ),
          ),

          // ── Meta chips ───────────────────────────────────────────
          if ((data['tech_stack'] ?? '').toString().isNotEmpty ||
              (data['domain'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if ((data['domain'] ?? '').toString().isNotEmpty)
                    _MetaChip(data['domain'] as String),
                  ...((data['tech_stack'] ?? '') as String)
                      .split(', ')
                      .where((s) => s.isNotEmpty)
                      .take(4)
                      .map((t) => _MetaChip(t)),
                ],
              ),
            ),
          ],

          // ── Date ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _formatDate(data['created_at']),
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),

          // ── Processing indicator ─────────────────────────────────
          if (isProcessing) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFFEDE9FF),
                  valueColor: AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                ),
              ),
            ),
          ],

          // ── Done action ──────────────────────────────────────────
          if (isDone) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Text('${data['pages'] ?? 94} pages ready',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          )),
                      const Spacer(),
                      Builder(builder: (context) {
                        final url = (data['download_url'] as String? ?? '').isNotEmpty
                            ? data['download_url'] as String
                            : (data['drive_url'] as String? ?? '');
                        return GestureDetector(
                          onTap: url.isNotEmpty
                              ? () async {
                                  await launchUrl(Uri.parse(url),
                                      mode: LaunchMode.externalApplication);
                                  FirebaseFirestore.instance
                                      .collection('jobs')
                                      .doc(jobId)
                                      .update({'downloaded_at': FieldValue.serverTimestamp()});
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: url.isNotEmpty
                                  ? const LinearGradient(
                                      colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                                    )
                                  : null,
                              color: url.isEmpty ? Colors.grey[300] : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.download_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 5),
                                Text('Download ZIP',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('Link expires 24 hours after generation',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                      if (data['downloaded_at'] != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.download_done_rounded,
                            size: 12, color: Color(0xFF16A34A)),
                        const SizedBox(width: 3),
                        const Text('Downloaded',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ── Expired ──────────────────────────────────────────────
          if (isExpired) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_off_rounded, size: 15, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text('Download link expired',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ],

          // ── Failed ───────────────────────────────────────────────
          if (isFailed) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 15, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  const Text('Generation failed. Please try again.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFDC2626))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF555566))),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (status) {
      'done'       => (bg: const Color(0xFFF0FDF4), fg: const Color(0xFF16A34A),
                       label: 'Ready',       icon: Icons.check_circle_outline),
      'processing' => (bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB),
                       label: 'Generating',  icon: Icons.hourglass_top_rounded),
      'queued'     => (bg: const Color(0xFFFFF7ED), fg: const Color(0xFFD97706),
                       label: 'Queued',      icon: Icons.queue_rounded),
      'failed'     => (bg: const Color(0xFFFFF1F2), fg: const Color(0xFFDC2626),
                       label: 'Failed',      icon: Icons.error_outline),
      'expired'    => (bg: const Color(0xFFF9FAFB), fg: const Color(0xFF9CA3AF),
                       label: 'Expired',     icon: Icons.link_off_rounded),
      _            => (bg: const Color(0xFFF9FAFB), fg: const Color(0xFF6B7280),
                       label: 'Pending',     icon: Icons.schedule_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 12, color: cfg.fg),
          const SizedBox(width: 4),
          Text(cfg.label,
              style: TextStyle(
                  color: cfg.fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
