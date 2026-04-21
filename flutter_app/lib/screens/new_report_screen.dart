import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _title             = TextEditingController();
  final _description       = TextEditingController();
  final _client            = TextEditingController();
  final _studentName       = TextEditingController();
  final _batchYear         = TextEditingController();
  final _semester          = TextEditingController();
  final _guiderName        = TextEditingController();
  final _modules           = TextEditingController();
  final _notificationEmail = TextEditingController();

  String       _domain        = 'CSE / IT';
  List<String> _selectedStack = [];
  String       _docTheme      = 'ocean_blue';
  String       _docColorHex   = '#1A4B8C';
  bool         _isLoading     = false;

  static const _branches = [
    'CSE / IT',
    'ECE — Electronics & Communication',
    'EXTC — Electronics & Telecommunication',
    'EEE — Electrical & Electronics',
    'Mechanical Engineering',
    'Civil Engineering',
  ];

  static const _branchStacks = <String, List<String>>{
    'CSE / IT': [
      'Python', 'Flask', 'Django', 'FastAPI', 'React', 'Node.js',
      'MySQL', 'MongoDB', 'Firebase', 'TensorFlow', 'Java', 'Spring Boot',
      'Flutter', 'PostgreSQL', 'Redis', 'Docker',
    ],
    'ECE — Electronics & Communication': [
      'Arduino', 'Raspberry Pi', 'ESP32', 'MATLAB', 'Simulink',
      'LabVIEW', 'Proteus', 'KiCad', 'VHDL', 'Verilog',
      'Python', 'C/C++', 'OpenCV', 'IoT/MQTT',
    ],
    'EXTC — Electronics & Telecommunication': [
      'Arduino', 'MATLAB', 'Simulink', 'FPGA', 'Verilog',
      'VHDL', 'Proteus', 'PCB Design', 'Python', 'C/C++',
      'NS2/NS3', 'Xilinx ISE',
    ],
    'EEE — Electrical & Electronics': [
      'MATLAB', 'Simulink', 'PLC', 'SCADA', 'AutoCAD Electrical',
      'ETAP', 'Python', 'Arduino', 'PSIM', 'PSCAD', 'Power BI',
    ],
    'Mechanical Engineering': [
      'CATIA', 'SolidWorks', 'AutoCAD', 'ANSYS', 'MATLAB',
      '3D Printing', 'CNC Machining', 'Python', 'ProE/Creo', 'Abaqus',
    ],
    'Civil Engineering': [
      'AutoCAD', 'STAAD Pro', 'ETABS', 'Revit', 'GIS/ArcGIS',
      'MATLAB', 'Python', 'SAP2000', 'Primavera', 'MS Project',
    ],
  };

  static const _colorPalettes = <Map<String, dynamic>>[
    {'key': 'ocean_blue',      'label': 'Ocean Blue',      'hex': '#1A4B8C', 'heading': Color(0xFF1A4B8C), 'accent': Color(0xFF2E86AB)},
    {'key': 'forest_green',    'label': 'Forest Green',    'hex': '#1B5E20', 'heading': Color(0xFF1B5E20), 'accent': Color(0xFF388E3C)},
    {'key': 'classic_maroon',  'label': 'Classic Maroon',  'hex': '#7B1113', 'heading': Color(0xFF7B1113), 'accent': Color(0xFFC62828)},
    {'key': 'midnight_purple', 'label': 'Midnight Purple', 'hex': '#4A148C', 'heading': Color(0xFF4A148C), 'accent': Color(0xFF7B1FA2)},
    {'key': 'slate_gray',      'label': 'Slate Gray',      'hex': '#263238', 'heading': Color(0xFF263238), 'accent': Color(0xFF455A64)},
    {'key': 'warm_amber',      'label': 'Warm Amber',      'hex': '#E65100', 'heading': Color(0xFFE65100), 'accent': Color(0xFFF57C00)},
  ];

  @override
  void dispose() {
    _title.dispose(); _description.dispose(); _client.dispose();
    _studentName.dispose(); _batchYear.dispose(); _semester.dispose();
    _guiderName.dispose(); _modules.dispose(); _notificationEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final user     = FirebaseAuth.instance.currentUser!;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      await FirebaseFirestore.instance.collection('jobs').add({
        'uid'                : user.uid,
        'title'              : _title.text.trim(),
        'description'        : _description.text.trim(),
        'domain'             : _domain,
        'tech_stack'         : _selectedStack.join(', '),
        'client'             : _client.text.trim(),
        'student_name'       : _studentName.text.trim(),
        'batch_year'         : _batchYear.text.trim(),
        'semester'           : _semester.text.trim(),
        'guider_name'        : _guiderName.text.trim(),
        'modules'            : _modules.text.trim(),
        'fcm_token'          : fcmToken,
        'notification_email' : _notificationEmail.text.trim(),
        'doc_theme'          : _docTheme,
        'doc_color_hex'      : _docColorHex,
        'status'             : 'pending',
        'created_at'         : FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showSuccessSheet();
        _formKey.currentState!.reset();
        setState(() {
          _selectedStack = [];
          _domain        = 'CSE / IT';
          _docTheme      = 'ocean_blue';
          _docColorHex   = '#1A4B8C';
        });
        _title.clear();
        _description.clear();
        _client.clear();
        _studentName.clear();
        _batchYear.clear();
        _semester.clear();
        _guiderName.clear();
        _modules.clear();
        _notificationEmail.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showConfirmDialog() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one technology.')),
      );
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Confirm your details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Review everything — this will use your 1 credit.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              _ConfirmRow(label: 'Title',       value: _title.text.trim()),
              _ConfirmRow(label: 'Description', value: _description.text.trim()),
              _ConfirmRow(label: 'Branch',      value: _domain),
              _ConfirmRow(label: 'Tech Stack',  value: _selectedStack.join(', ')),
              _ConfirmRow(label: 'Modules',     value: _modules.text.trim()),
              _ConfirmRow(label: 'Student',     value: _studentName.text.trim()),
              _ConfirmRow(label: 'Batch',       value: _batchYear.text.trim()),
              _ConfirmRow(label: 'Semester',    value: _semester.text.trim()),
              _ConfirmRow(label: 'Guide',       value: _guiderName.text.trim()),
              _ConfirmRow(label: 'College',     value: _client.text.trim()),
              if (_notificationEmail.text.trim().isNotEmpty)
                _ConfirmRow(label: 'Email', value: _notificationEmail.text.trim()),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm & Generate',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await _submit();
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF0EEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  size: 40, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 16),
            const Text('Report queued!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Your report is being generated.\nCheck "My Reports" to track progress.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Got it', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [

            // ── Hero banner ────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hey ${(user.displayName ?? 'there').split(' ').first} 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fill in your project details\nand we\'ll handle the rest.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),

            // ── Project details ────────────────────────────────────
            const _SectionHeader(icon: Icons.folder_outlined, label: 'Project Details'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Project title',
                hintText: 'e.g. Library Management System',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Project description',
                hintText: 'What does your project do? (2–3 lines)',
                prefixIcon: Icon(Icons.notes_rounded),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              minLines: 3,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _domain,
              decoration: const InputDecoration(
                labelText: 'Engineering Branch',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              borderRadius: BorderRadius.circular(12),
              isExpanded: true,
              items: _branches
                  .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() {
                _domain        = v!;
                _selectedStack = [];
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modules,
              decoration: const InputDecoration(
                labelText: 'Key modules / features',
                hintText: 'e.g. Login, Book Issue, Return, Fine Management\nAdmin Panel, Reports, Notifications',
                prefixIcon: Icon(Icons.view_module_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              minLines: 3,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),

            // ── Tech stack ─────────────────────────────────────────
            const SizedBox(height: 20),
            const _SectionHeader(icon: Icons.code_rounded, label: 'Tech Stack'),
            const SizedBox(height: 4),
            Text('Select all that apply',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_branchStacks[_domain] ?? _branchStacks['CSE / IT']!).map((tech) {
                final selected = _selectedStack.contains(tech);
                return GestureDetector(
                  onTap: () => setState(() => selected
                      ? _selectedStack.remove(tech)
                      : _selectedStack.add(tech)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6C63FF) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFFDDDDEE),
                      ),
                    ),
                    child: Text(
                      tech,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : const Color(0xFF444455),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Document style ─────────────────────────────────────
            const SizedBox(height: 20),
            const _SectionHeader(icon: Icons.palette_outlined, label: 'Document Style'),
            const SizedBox(height: 4),
            Text('Choose a color theme for your report headings',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorPalettes.map((palette) {
                final isSelected = _docTheme == palette['key'];
                final headingColor = palette['heading'] as Color;
                final accentColor  = palette['accent'] as Color;
                return GestureDetector(
                  onTap: () => setState(() {
                    _docTheme    = palette['key'] as String;
                    _docColorHex = palette['hex'] as String;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 88,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? headingColor.withValues(alpha: 0.10)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? headingColor : const Color(0xFFDDDDEE),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(radius: 8, backgroundColor: headingColor),
                            const SizedBox(width: 4),
                            CircleAvatar(radius: 8, backgroundColor: accentColor),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          palette['label'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: headingColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Student info ───────────────────────────────────────
            const SizedBox(height: 20),
            const _SectionHeader(icon: Icons.school_outlined, label: 'Student Info'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _studentName,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _batchYear,
                  decoration: const InputDecoration(
                    labelText: 'Batch year',
                    hintText: '2024-25',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _semester,
                  decoration: const InputDecoration(
                    labelText: 'Semester / Class',
                    hintText: '6th Sem / TE',
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _guiderName,
                  decoration: const InputDecoration(
                    labelText: 'Guide Name',
                    hintText: 'Prof. Sharma',
                    prefixIcon: Icon(Icons.supervisor_account_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _client,
              decoration: const InputDecoration(
                labelText: 'College / University',
                hintText: 'e.g. VTU, SPPU, GTU',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notificationEmail,
              decoration: const InputDecoration(
                labelText: 'Notification email (optional)',
                hintText: 'Get an email when your report is ready',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$')
                    .hasMatch(v.trim());
                return ok ? null : 'Enter a valid email';
              },
            ),

            // ── Payment gate + Submit ──────────────────────────────
            const SizedBox(height: 32),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snap) {
                final data    = snap.data?.data() ?? {};
                final credits = (data['generate_credits'] as num?)?.toInt() ?? 0;

                if (credits > 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EEFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF6C63FF), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '$credits generation credit${credits > 1 ? 's' : ''} available',
                              style: const TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GradientButton(
                        onTap: _isLoading ? null : _showConfirmDialog,
                        isLoading: _isLoading,
                      ),
                    ],
                  );
                }

                return _PayButton(loading: snap.connectionState == ConnectionState.waiting);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF),
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF222233))),
          const Divider(height: 18),
        ],
      ),
    );
  }
}


class _PayButton extends StatelessWidget {
  final bool loading;
  const _PayButton({this.loading = false});

  static const _upiId = '9929225263@ybl';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EEFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDDDEE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_rounded, color: Color(0xFF6C63FF), size: 18),
                  SizedBox(width: 8),
                  Text('Pay to generate your report',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF6C63FF),
                      )),
                ],
              ),
              const SizedBox(height: 14),
              const Text('UPI ID',
                  style: TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(_upiId,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A0A14),
                      )),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: _upiId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('UPI ID copied!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Copy', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Amount: ₹799',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333344))),
              const SizedBox(height: 10),
              Text(
                'After payment, your credit will be added within a few hours. '
                'Contact us on WhatsApp with the payment screenshot.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top_rounded, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text('Generate — awaiting payment',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C63FF),
              letterSpacing: 0.3,
            )),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  const _GradientButton({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)]),
          color: onTap == null ? Colors.grey[300] : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Generate my report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
        ),
      ),
    );
  }
}
