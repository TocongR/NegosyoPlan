import 'package:flutter/foundation.dart';

// OLEDIPO staff dashboard data. Everything here is SAMPLE data for the demo.
// In production this comes from the OLEDIPO server, filled by applicants who
// chose to share their Passport (consent) and by staff actions.

/// Only three statuses: Pending, Accepted, Returned for completion.
/// "Accepted" means the papers are complete; the EMBRACE TWG still decides on the loan.
enum AppStatus { pending, accepted, returned }

extension AppStatusInfo on AppStatus {
  String get label => switch (this) {
        AppStatus.pending => 'Pending',
        AppStatus.accepted => 'Accepted',
        AppStatus.returned => 'Returned for completion',
      };
}

enum DocStatus { pending, verified, newCopy }

extension DocStatusInfo on DocStatus {
  String get label => switch (this) {
        DocStatus.pending => 'Pending',
        DocStatus.verified => 'Verified',
        DocStatus.newCopy => 'New copy requested',
      };
}

/// Business permit, Annex C certificate, or training certificate.
enum DocKind { permit, annexC, training }

class Application {
  final String id;
  final String owner;
  final String business;
  final String town;
  final String type;
  final double loan;
  final int years;
  AppStatus status;
  final int completeness;
  final String submitted;
  final int? prepDays;
  final List<String> missing;
  final int trainings;

  Application(this.id, this.owner, this.business, this.town, this.type, this.loan, this.status, this.completeness, this.submitted, this.prepDays, this.missing, this.trainings)
      : years = loan > 80000 ? 2 : 1;
}

class UploadedDoc {
  final String appId;
  final String owner;
  final String doc;
  final DocKind kind;

  /// For training certificates: "Provider · Date".
  final String detail;
  final String uploaded;
  DocStatus status;
  String note;
  UploadedDoc(this.appId, this.owner, this.doc, this.kind, this.uploaded, this.status, {this.detail = '', this.note = ''});
}

class StaffMember {
  final String name;
  final String email;
  String role;
  bool active;
  bool invited;
  StaffMember(this.name, this.email, this.role, this.active, {this.invited = false});
}

class AuditEntry {
  final String time;
  final String who;
  final String action;
  AuditEntry(this.time, this.who, this.action);
}

class AdminStore extends ChangeNotifier {
  final String me = 'J. Escare';

  static const _annexC = 'Certificate of Residency and Business Operation (Annex C)';

  final List<Application> apps = [
    Application('EMB-2026-0141', 'Maria L. Santos', 'Lola Nena’s Piaya', 'Jaro', 'Food', 100000, AppStatus.pending, 81, 'Oct 13', 2, [_annexC, 'Simple Bookkeeping certificate'], 2),
    Application('EMB-2026-0138', 'Jose R. Dela Cruz', 'JR Sari-sari Store', 'Oton', 'Retail', 50000, AppStatus.pending, 100, 'Oct 11', 3, [], 1),
    Application('EMB-2026-0135', 'Ana P. Villanueva', 'Ana’s Native Weaves', 'Miagao', 'Crafts', 80000, AppStatus.accepted, 100, 'Oct 9', 4, [], 3),
    Application('EMB-2026-0133', 'Ramon T. Garcia', 'RG Motor Repair', 'Pavia', 'Service', 120000, AppStatus.returned, 72, 'Oct 8', 2, ['2024 cash flow statement', 'Training certificate'], 0),
    Application('EMB-2026-0130', 'Liza M. Torres', 'Liza’s Kakanin', 'Santa Barbara', 'Food', 40000, AppStatus.accepted, 100, 'Oct 3', 5, [], 2),
    Application('EMB-2026-0128', 'Pedro A. Ramos', 'Ramos Fish Drying', 'Dumangas', 'Food', 60000, AppStatus.pending, 94, 'Oct 2', 3, [_annexC], 1),
    Application('EMB-2026-0126', 'Grace S. Lim', 'Grace Laundry Hub', 'Leganes', 'Service', 90000, AppStatus.pending, 100, 'Oct 1', 2, [], 0),
    Application('EMB-2026-0124', 'Carlo J. Bautista', 'CJ Bamboo Furniture', 'Cabatuan', 'Crafts', 150000, AppStatus.accepted, 100, 'Sep 29', 6, [], 2),
    Application('EMB-2026-0121', 'Nora E. Aquino', 'Nora’s Banana Chips', 'Passi City', 'Food', 70000, AppStatus.accepted, 100, 'Sep 26', 4, [], 1),
    Application('EMB-2026-0119', 'Felix D. Mendoza', 'Felix Rice Retail', 'Zarraga', 'Retail', 45000, AppStatus.returned, 65, 'Sep 24', 3, ['Business permit', '2023 balance sheet'], 0),
    Application('EMB-2026-0117', 'Rosa C. Navarro', 'Rosa’s Tailoring', 'Tigbauan', 'Service', 35000, AppStatus.pending, 58, '—', null, ['Financial statements 2022–2024', 'Business permit'], 1),
    Application('EMB-2026-0115', 'Ben K. Castillo', 'Castillo Hog Feeds', 'Oton', 'Retail', 110000, AppStatus.pending, 40, '—', null, ['Products and prices', 'Financial statements', 'Loan items', _annexC], 0),
  ];

  final List<UploadedDoc> docs = [
    UploadedDoc('EMB-2026-0141', 'Maria L. Santos', 'Business permit', DocKind.permit, 'Oct 13', DocStatus.pending),
    UploadedDoc('EMB-2026-0141', 'Maria L. Santos', 'Training certificate: Food Safety and Handling', DocKind.training, 'Oct 13', DocStatus.pending, detail: 'DTI Negosyo Center · Mar 2025'),
    UploadedDoc('EMB-2026-0141', 'Maria L. Santos', 'Training certificate: Costing and Pricing', DocKind.training, 'Oct 13', DocStatus.pending, detail: 'DOST · Aug 2025'),
    UploadedDoc('EMB-2026-0138', 'Jose R. Dela Cruz', _annexC, DocKind.annexC, 'Oct 11', DocStatus.pending),
    UploadedDoc('EMB-2026-0138', 'Jose R. Dela Cruz', 'Business permit', DocKind.permit, 'Oct 11', DocStatus.verified),
    UploadedDoc('EMB-2026-0138', 'Jose R. Dela Cruz', 'Training certificate: Simple Bookkeeping', DocKind.training, 'Oct 11', DocStatus.pending, detail: 'OLEDIPO · May 2025'),
    UploadedDoc('EMB-2026-0135', 'Ana P. Villanueva', 'Training certificate: Natural Dyeing', DocKind.training, 'Oct 9', DocStatus.verified, detail: 'DOST · Nov 2024'),
    UploadedDoc('EMB-2026-0126', 'Grace S. Lim', 'Business permit', DocKind.permit, 'Oct 1', DocStatus.pending),
    UploadedDoc('EMB-2026-0126', 'Grace S. Lim', _annexC, DocKind.annexC, 'Oct 1', DocStatus.pending),
    UploadedDoc('EMB-2026-0133', 'Ramon T. Garcia', 'Business permit', DocKind.permit, 'Oct 8', DocStatus.newCopy, note: 'Photo is blurry'),
    UploadedDoc('EMB-2026-0128', 'Pedro A. Ramos', 'Business permit', DocKind.permit, 'Oct 2', DocStatus.verified),
    UploadedDoc('EMB-2026-0128', 'Pedro A. Ramos', 'Training certificate: Fish Processing', DocKind.training, 'Oct 2', DocStatus.newCopy, detail: 'BFAR · Feb 2025', note: 'Photo is blurry'),
  ];

  final List<StaffMember> staff = [
    StaffMember('John Peter S. Escare', 'jescare@oledipo.example', 'Admin', true),
    StaffMember('Reviewer A', 'reviewer.a@oledipo.example', 'Reviewer', true),
    StaffMember('Reviewer B', 'reviewer.b@oledipo.example', 'Reviewer', true),
    StaffMember('Training focal', 'training@oledipo.example', 'Trainer', false),
  ];

  final List<AuditEntry> audit = [
    AuditEntry('Today 9:12', 'J. Escare', 'Viewed EMB-2026-0141 (Lola Nena’s Piaya)'),
    AuditEntry('Yesterday 4:40', 'Reviewer A', 'Verified Business permit for EMB-2026-0138'),
    AuditEntry('Yesterday 2:05', 'Reviewer A', 'Returned EMB-2026-0133 for completion: 2024 cash flow and training certificate'),
    AuditEntry('Oct 12 10:30', 'J. Escare', 'Accepted EMB-2026-0135 (Ana’s Native Weaves)'),
    AuditEntry('Oct 10 3:15', 'J. Escare', 'Accepted EMB-2026-0130 (Liza’s Kakanin)'),
    AuditEntry('Oct 9 11:00', 'Reviewer B', 'Requested new copy of Business permit for EMB-2026-0133'),
  ];

  // ---- derived ----
  int count(AppStatus s) => apps.where((a) => a.status == s).length;
  List<UploadedDoc> docsFor(Application a) => docs.where((d) => d.appId == a.id).toList();
  Application? appFor(UploadedDoc d) {
    for (final a in apps) {
      if (a.id == d.appId) return a;
    }
    return null;
  }

  List<Application> get submittedLike => apps.where((a) => a.prepDays != null).toList();
  double get avgPrep {
    final s = submittedLike;
    return s.isEmpty ? 0 : s.fold<int>(0, (a, x) => a + x.prepDays!) / s.length;
  }

  Map<String, int> get byTown {
    final m = <String, int>{};
    for (final a in apps) {
      m[a.town] = (m[a.town] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> get commonMissing {
    final m = <String, int>{};
    for (final a in apps) {
      for (final x in a.missing) {
        m[x] = (m[x] ?? 0) + 1;
      }
    }
    return m;
  }

  // ---- actions (each one is logged) ----
  void _log(String action) => audit.insert(0, AuditEntry('Just now', me, action));

  void setStatus(Application a, AppStatus s, String verb) {
    a.status = s;
    _log('$verb ${a.id} (${a.business})');
    notifyListeners();
  }

  void viewed(Application a) {
    _log('Viewed ${a.id} (${a.business})');
    notifyListeners();
  }

  void checkedRequirements(Application a) {
    _log('Checked requirements of ${a.id} (${a.business})');
    notifyListeners();
  }

  void openedDoc(UploadedDoc d) {
    _log('Opened ${d.doc} for ${d.appId}');
    notifyListeners();
  }

  void printedDoc(UploadedDoc d) {
    _log('Printed ${d.doc} for ${d.appId}');
    notifyListeners();
  }

  void setDoc(UploadedDoc d, DocStatus s, {String note = ''}) {
    d.status = s;
    d.note = note;
    _log('${s == DocStatus.verified ? 'Verified' : s == DocStatus.newCopy ? 'Requested new copy of' : 'Reopened'} ${d.doc} for ${d.appId}');
    notifyListeners();
  }

  void setRole(StaffMember m, String role) {
    m.role = role;
    _log('Changed role of ${m.name} to $role');
    notifyListeners();
  }

  void toggleStaff(StaffMember m) {
    m.active = !m.active;
    m.invited = false;
    _log('${m.active ? 'Turned on' : 'Turned off'} access for ${m.name}');
    notifyListeners();
  }

  void invite(String name, String email, String role) {
    staff.add(StaffMember(name, email, role, false, invited: true));
    _log('Invited $name as $role');
    notifyListeners();
  }
}
