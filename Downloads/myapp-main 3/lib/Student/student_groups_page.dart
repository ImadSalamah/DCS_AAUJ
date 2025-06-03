import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../forms/paedodontics_form.dart';

// Imports for forms and details
import 'forms/surgery_case_form.dart';
import 'forms/internal_medicine_case_form.dart';
import 'forms/pediatrics_case_form.dart';
import 'forms/default_case_form.dart';
import 'forms/paedodontics_case_form.dart';

void main() {
  runApp(const MaterialApp(
    home: StudentGroupsPage(),
  ));
}

class StudentGroupsPage extends StatefulWidget {
  const StudentGroupsPage({super.key});

  @override
  StudentGroupsPageState createState() => StudentGroupsPageState();
}

class StudentGroupsPageState extends State<StudentGroupsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _studentGroups = [];

  @override
  void initState() {
    super.initState();
    _loadStudentGroups();
  }

  Future<void> _loadStudentGroups() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _dbRef.child('studyGroups').get();
      if (snapshot.exists) {
        final allGroups = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> groups = [];

        allGroups.forEach((groupId, groupData) {
          final students =
              groupData['students'] as Map<dynamic, dynamic>? ?? {};
          if (students.containsKey(user.uid)) {
            groups.add({
              'id': groupId.toString(),
              'groupNumber':
                  groupData['groupNumber']?.toString() ?? 'غير معروف',
              'courseId': groupData['courseId']?.toString() ?? '',
              'courseName': groupData['courseName']?.toString() ?? 'غير معروف',
              'requiredCases': groupData['requiredCases'] ?? 3,
            });
          }
        });

        setState(() {
          _studentGroups = groups;
        });
      }
    } catch (e) {
      setState(() {});
    }
  }

  void _navigateToLogbook(BuildContext context, Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CasesScreen(
          groupId: group['id'],
          courseId: group['courseId'],
          courseName: group['courseName'],
          requiredCases: group['requiredCases'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شعبي الدراسية'),
        centerTitle: true,
      ),
      body: _studentGroups.isEmpty
          ? const Center(child: Text('لا توجد شعب مسجلة لك'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _studentGroups.length,
              itemBuilder: (context, index) {
                final group = _studentGroups[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(group['courseName']),
                    subtitle: Text('الشعبة ${group['groupNumber']}'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _navigateToLogbook(context, group),
                  ),
                );
              },
            ),
    );
  }
}

class _CasesScreen extends StatefulWidget {
  final String groupId;
  final String courseId;
  final String courseName;
  final int requiredCases;

  const _CasesScreen({
    required this.groupId,
    required this.courseId,
    required this.courseName,
    required this.requiredCases,
  });

  @override
  State<_CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<_CasesScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _submittedCases = [];
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Map<String, dynamic>? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _loadSubmittedCases();
  }

  Future<void> _loadSubmittedCases() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      // For paedodontics, fetch from paedodonticsCases, else from pendingCases
      if (widget.courseId == '080114140') {
        final snapshot = await _dbRef.child('paedodonticsCases').orderByChild('studentId').equalTo(user.uid).get();
        final List<Map<String, dynamic>> cases = [];
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            cases.add({'id': key, ...Map<String, dynamic>.from(value as Map)});
          });
        }
        setState(() {
          _submittedCases = cases;
        });
      } else {
        final snapshot = await _dbRef
            .child('pendingCases')
            .child(widget.groupId)
            .child(user.uid)
            .get();
        final List<Map<String, dynamic>> cases = [];
        if (snapshot.exists) {
          for (var element in snapshot.children) {
            cases.add({
              'id': element.key,
              ...Map<String, dynamic>.from(element.value as Map),
            });
          }
        }
        setState(() {
          _submittedCases = cases;
        });
      }
    } catch (e) {
      setState(() {});
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Fetch users only (since all users are in 'users')
      final usersSnap = await _dbRef.child('users').get();
      final results = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      if (usersSnap.exists) {
        final allUsers = usersSnap.value as Map<dynamic, dynamic>;
        allUsers.forEach((userId, userData) {
          final user = Map<String, dynamic>.from(userData as Map);
          // جلب الاسم الكامل من الحقول الجزئية إذا كان fullName غير موجود أو فارغ
          String fullName = user['fullName']?.toString() ?? '';
          if (fullName.trim().isEmpty) {
            final firstName = user['firstName']?.toString() ?? '';
            final fatherName = user['fatherName']?.toString() ?? '';
            final grandfatherName = user['grandfatherName']?.toString() ?? '';
            final familyName = user['familyName']?.toString() ?? '';
            fullName = [firstName, fatherName, grandfatherName, familyName]
                .where((part) => part.isNotEmpty)
                .join(' ');
          }
          final idNumber = user['idNumber']?.toString() ?? '';
          final studentId = user['studentId']?.toString() ?? '';
          if (fullName.toLowerCase().contains(query.toLowerCase()) ||
              idNumber.contains(query) ||
              studentId.contains(query)) {
            if (!seenIds.contains(idNumber)) {
              results.add({'id': userId, ...user, 'fullName': fullName});
              seenIds.add(idNumber);
            }
          }
        });
      }

      setState(() => _searchResults = results);
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatient = patient;
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPatient = null;
    });
  }

  // --- NEW: Paedodontics case logic ---
  List<Map<String, dynamic>> get _paedoCaseList {
    // 3 history, 6 fissure
    final List<Map<String, dynamic>> cases = [];
    for (int i = 1; i <= 3; i++) {
      cases.add({'type': 'history', 'number': i});
    }
    for (int i = 1; i <= 6; i++) {
      cases.add({'type': 'fissure', 'number': i});
    }
    return cases;
  }

  Map<String, Map<int, Map<String, dynamic>>> get _submittedPaedoCasesByTypeAndNumber {
    // Map: type -> number -> case
    final map = <String, Map<int, Map<String, dynamic>>>{};
    for (final c in _submittedCases) {
      final type = c['caseType'] ?? c['type'];
      final number = c['caseNumber'];
      if (type != null && number != null) {
        map[type] ??= {};
        map[type]![number] = c;
      }
    }
    return map;
  }

  void _addNewPaedoCase(String type, int number) {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار مريض أولاً')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaedodonticsForm(
          groupId: widget.groupId,
          caseNumber: number,
          patient: _selectedPatient!,
          courseId: widget.courseId,
          onSave: _loadSubmittedCases,
          caseType: type, // Pass type
        ),
      ),
    ).then((_) => _clearSelection());
  }

  void _viewPaedoCaseDetails(Map<String, dynamic> caseData) {
    // You can implement a details screen if needed
  }

  @override
  Widget build(BuildContext context) {
    if (widget.courseId == '080114140') {
      // Paedodontics: show 9 cards (3 history, 6 fissure)
      final paedoCases = _paedoCaseList;
      final submittedMap = _submittedPaedoCasesByTypeAndNumber;
      return Scaffold(
        appBar: AppBar(title: Text(widget.courseName)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'ابحث عن مريض (بالاسم أو رقم الهوية)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching ? const CircularProgressIndicator() : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: _searchPatients,
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      height: 200,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final patient = _searchResults[index];
                          return ListTile(
                            title: Text(patient['fullName'] ?? 'غير معروف'),
                            subtitle: Text('هوية: ${patient['idNumber'] ?? 'غير معروف'} - جامعي: ${patient['studentId'] ?? 'غير معروف'}'),
                            onTap: () => _selectPatient(patient),
                          );
                        },
                      ),
                    ),
                  if (_selectedPatient != null)
                    Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'المريض المختار:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  Text(_selectedPatient!['fullName'] ?? ''),
                                  Text('هوية: ${_selectedPatient!['idNumber'] ?? 'غير معروف'}'),
                                  if (_selectedPatient!['studentId'] != null)
                                    Text('جامعي: ${_selectedPatient!['studentId']}'),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSelection,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: paedoCases.length,
                itemBuilder: (context, index) {
                  final item = paedoCases[index];
                  final type = item['type'] as String;
                  final number = item['number'] as int;
                  final submitted = submittedMap[type]?[number];
                  final isCompleted = submitted != null && (submitted['status'] == 'graded');
                  final isPending = submitted != null && submitted['status'] == 'pending';
                  return Card(
                    elevation: 3,
                    color: isCompleted
                        ? Colors.blue[50]
                        : isPending
                            ? Colors.orange[50]
                            : Colors.grey[100],
                    child: InkWell(
                      onTap: isCompleted
                          ? () => _viewPaedoCaseDetails(submitted)
                          : isPending
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('الحالة قيد المراجعة من الدكتور')),
                                  );
                                }
                              : () => _addNewPaedoCase(type, number),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.assignment_turned_in
                                  : isPending
                                      ? Icons.hourglass_top
                                      : Icons.assignment,
                              size: 40,
                              color: isCompleted
                                  ? Colors.green
                                  : isPending
                                      ? Colors.orange
                                      : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              type == 'history'
                                  ? 'حالة تاريخ وفحص #$number'
                                  : 'حالة سد شقوق #$number',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isCompleted
                                  ? 'مكتملة'
                                  : isPending
                                      ? 'قيد المراجعة'
                                      : 'غير مكتملة',
                              style: TextStyle(
                                color: isCompleted
                                    ? Colors.green
                                    : isPending
                                        ? Colors.orange
                                        : Colors.grey,
                              ),
                            ),
                            if (submitted != null && submitted['patientName'] != null)
                              Text('المريض: ${submitted['patientName']}'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    } else if (widget.courseId == '080114141') {
      // Internal Medicine: استخدم الفورم الجاهز
      return InternalMedicineCaseForm(
        groupId: widget.groupId,
        courseId: widget.courseId,
        caseNumber: 1, // يمكنك تخصيص الرقم حسب الحاجة
        patient: _selectedPatient ?? {},
        onSave: _loadSubmittedCases,
      );
    }
    // ...existing code for other courses...
    // If no course matched, fallback:
    throw UnimplementedError('Unknown courseId:  ${widget.courseId}');
  }
  // ...existing code...
}
