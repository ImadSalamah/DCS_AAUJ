import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaedodonticsForm extends StatefulWidget {
  final String groupId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final String? courseId;
  final Function()? onSave;
  final String? caseType; // NEW: type (history/fissure)
  const PaedodonticsForm({
    super.key,
    required this.groupId,
    required this.caseNumber,
    required this.patient,
    this.courseId,
    this.onSave,
    this.caseType,
  });

  @override
  State<PaedodonticsForm> createState() => _PaedodonticsFormState();
}

class _PaedodonticsFormState extends State<PaedodonticsForm> {
  bool isSubmitting = false;
  String? lastSubmittedCaseKey;
  String? lastCaseStatus;
  int? lastCaseMark;
  String? lastDoctorComment;

  // New fields
  String guardianName = '';
  String patientAddress = '';
  String patientPhone = '';

  // Translation map
  final Map<String, Map<String, String>> _translations = {
    'clinical_requirements': {'ar': 'المتطلبات السريرية', 'en': 'Clinical Requirements'},
    'history_title': {'ar': 'أخذ التاريخ والفحص والتخطيط', 'en': 'History taking, examination, & treatment planning'},
    'history_required': {'ar': 'المطلوب: 3 حالات', 'en': 'Required: 3 cases'},
    'fissure_title': {'ar': 'سد الشقوق', 'en': 'Fissure sealants'},
    'fissure_required': {'ar': 'المطلوب: 6 حالات', 'en': 'Required: 6 cases'},
    'guardian_name': {'ar': 'اسم ولي الأمر', 'en': "Guardian's Name"},
    'patient_address': {'ar': 'عنوان المريض', 'en': 'Patient Address'},
    'patient_phone': {'ar': 'رقم هاتف المريض', 'en': 'Patient Phone'},
    'send_case': {'ar': 'إرسال الحالة', 'en': 'Submit Case'},
    'last_case_graded': {'ar': 'تم تقييم آخر حالة', 'en': 'Last case graded'},
    'last_case_pending': {'ar': 'آخر حالة قيد المراجعة من الدكتور', 'en': 'Last case pending review'},
    'last_case_rejected': {'ar': 'آخر حالة بحاجة لتعديل', 'en': 'Last case needs revision'},
    'mark': {'ar': 'العلامة', 'en': 'Mark'},
    'doctor_note': {'ar': 'ملاحظة الدكتور', 'en': 'Doctor Note'},
    'no_mark': {'ar': 'بدون علامة', 'en': 'No mark'},
    'submit_success': {'ar': 'تم إرسال الحالة للدكتور المشرف', 'en': 'Case submitted to supervisor'},
    'must_login': {'ar': 'يجب تسجيل الدخول', 'en': 'You must login'},
  };

  String _translate(String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return _translations[key]?[locale] ?? _translations[key]?['en'] ?? key;
  }

  Future<void> _loadLastCase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final db = FirebaseDatabase.instance.ref();
    final snapshot = await db.child('paedodonticsCases').orderByChild('studentId').equalTo(user.uid).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final sorted = data.entries.toList()
        ..sort((a, b) => (b.value['submittedAt'] ?? 0).compareTo(a.value['submittedAt'] ?? 0));
      final last = sorted.first.value;
      lastSubmittedCaseKey = sorted.first.key;
      lastCaseStatus = last['status'];
      lastCaseMark = last['mark'];
      lastDoctorComment = last['doctorComment'];
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLastCase();
  }

  // Add a helper for type label
  String get _caseTypeLabel {
    switch (widget.caseType) {
      case 'history':
        return _translate('history_title');
      case 'fissure':
        return _translate('fissure_title');
      default:
        return widget.caseType ?? '';
    }
  }

  Future<void> submitCase() async {
    setState(() => isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translate('must_login'))));
      setState(() => isSubmitting = false);
      return;
    }
    try {
      print('Submitting case...');
      final DatabaseReference db = FirebaseDatabase.instance.ref();
      // جلب اسم الطالب من جدول users
      String studentName = '';
      final userSnapshot = await db.child('users').child(user.uid).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        studentName = userData['fullName'] ?? userData['name'] ?? user.displayName ?? '';
      } else {
        studentName = user.displayName ?? '';
      }
      final caseData = {
        'studentId': user.uid,
        'studentName': studentName, // حفظ اسم الطالب
        'guardianName': guardianName,
        'patientAddress': patientAddress,
        'patientPhone': patientPhone,
        'groupId': widget.groupId,
        'caseNumber': widget.caseNumber,
        'patient': widget.patient,
        if (widget.courseId != null) 'courseId': widget.courseId,
        'caseType': widget.caseType, // NEW: save type
        'status': 'pending',
        'mark': null,
        'doctorComment': null,
        'submittedAt': DateTime.now().millisecondsSinceEpoch,
      };
      print('Writing to paedodonticsCases...');
      await db.child('paedodonticsCases').push().set(caseData);
      print('Case written. Loading last case...');
      await _loadLastCase();
      print('Last case loaded.');
      setState(() => isSubmitting = false);
      if (widget.onSave != null) widget.onSave!();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translate('submit_success'))));
    } catch (e, stack) {
      print('Error submitting case:');
      print(e);
      print(stack);
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال الحالة: ' + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_caseTypeLabel} ${widget.caseNumber}')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show type in UI
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('نوع الحالة: ${_caseTypeLabel}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    // معلومات المريض
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معلومات المريض:',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('الاسم: ${widget.patient['fullName'] ?? ''}'),
                            Text('رقم الهوية: ${widget.patient['idNumber'] ?? ''}'),
                            if (widget.patient['studentId'] != null)
                              Text('الرقم الجامعي: ${widget.patient['studentId']}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // حقول النموذج
                    TextFormField(
                      decoration: InputDecoration(labelText: _translate('guardian_name')),
                      onChanged: (v) => setState(() => guardianName = v),
                      enabled: lastCaseStatus != 'pending' && lastCaseStatus != 'graded',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: InputDecoration(labelText: _translate('patient_address')),
                      onChanged: (v) => setState(() => patientAddress = v),
                      enabled: lastCaseStatus != 'pending' && lastCaseStatus != 'graded',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: InputDecoration(labelText: _translate('patient_phone')),
                      keyboardType: TextInputType.phone,
                      onChanged: (v) => setState(() => patientPhone = v),
                      enabled: lastCaseStatus != 'pending' && lastCaseStatus != 'graded',
                    ),
                    const SizedBox(height: 20),
                    if (lastCaseStatus == 'graded') ...[
                      Card(
                        color: Colors.green[50],
                        child: ListTile(
                          title: Text(_translate('last_case_graded')),
                          subtitle: Text(
                            _translate('mark') + ': ' + (lastCaseMark?.toString() ?? _translate('no_mark')) +
                            '\n' + _translate('doctor_note') + ': ' + (lastDoctorComment ?? '-')
                          ),
                        ),
                      ),
                    ] else if (lastCaseStatus == 'pending') ...[
                      Card(
                        color: Colors.orange[50],
                        child: ListTile(
                          title: Text(_translate('last_case_pending')),
                        ),
                      ),
                    ] else if (lastCaseStatus == 'rejected') ...[
                      Card(
                        color: Colors.red[50],
                        child: ListTile(
                          title: Text(_translate('last_case_rejected')),
                          subtitle: Text(_translate('doctor_note') + ': ' + (lastDoctorComment ?? '-')),
                        ),
                      ),
                    ],
                    Expanded(child: Container()),
                    Center(
                      child: ElevatedButton(
                        onPressed: (isSubmitting || lastCaseStatus == 'pending' || lastCaseStatus == 'graded') ? null : submitCase,
                        child: isSubmitting ? const CircularProgressIndicator() : Text(_translate('send_case')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
