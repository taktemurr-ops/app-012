import 'dart:math' as math;

String validateName(String text) {
  final value = text.trim();
  if (value.isEmpty || value.length > 90 || value.contains(RegExp(r'[\x00-\x1F]'))) {
    throw const FormatException('Invalid name');
  }
  return value;
}

int parseMoney(String input) {
  var value = input.trim();
  const digitSets = ['٠١٢٣٤٥٦٧٨٩', '۰۱۲۳۴۵۶۷۸۹'];
  for (final set in digitSets) {
    for (var i = 0; i < 10; i++) {
      value = value.replaceAll(set[i], '$i');
    }
  }
  value = value.replaceAll('٫', '.').replaceAll('٬', ',').replaceAll(' ', '');
  if (value.isEmpty || value.length > 25 || !RegExp(r'^[0-9.,]+$').hasMatch(value)) {
    throw const FormatException('Invalid amount');
  }
  final comma = value.lastIndexOf(',');
  final dot = value.lastIndexOf('.');
  final decimalIndex = math.max(comma, dot);
  final hasFraction = decimalIndex >= 0 && value.length - decimalIndex - 1 <= 2;
  final whole = (hasFraction ? value.substring(0, decimalIndex) : value)
      .replaceAll(',', '').replaceAll('.', '');
  final fraction = hasFraction ? value.substring(decimalIndex + 1).padRight(2, '0') : '00';
  if (whole.isEmpty || !RegExp(r'^\d+$').hasMatch(whole) || !RegExp(r'^\d{2}$').hasMatch(fraction)) {
    throw const FormatException('Invalid amount');
  }
  final amount = int.tryParse(whole);
  final cents = int.tryParse(fraction);
  if (amount == null || cents == null || amount > 100000000000) {
    throw const FormatException('Amount exceeds limit');
  }
  return amount * 100 + cents;
}

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';

class Debt {
  const Debt({required this.id, required this.name, required this.principalMinor,
    required this.currency, required this.aprBasisPoints, required this.created,
    this.due, this.note = '', this.kind = 'owe'});
  final String id, name, currency, note, kind;
  final int principalMinor, aprBasisPoints;
  final DateTime created;
  final DateTime? due;

  factory Debt.fromJson(Map<String, dynamic> x) {
    final debt = Debt(id: x['id'] as String, name: validateName(x['name'] as String),
      principalMinor: x['principalMinor'] as int, currency: x['currency'] as String,
      aprBasisPoints: x['aprBasisPoints'] as int,
      created: DateTime.parse(x['created'] as String),
      due: x['due'] == null ? null : DateTime.parse(x['due'] as String),
      note: (x['note'] ?? '') as String, kind: (x['kind'] ?? 'owe') as String);
    debt.validate();
    return debt;
  }
  void validate() {
    validateName(name);
    if (id.isEmpty || id.length > 100 || principalMinor <= 0 || principalMinor > 10000000000000 ||
        !['TRY','USD','EUR','GBP'].contains(currency) || aprBasisPoints < 0 || aprBasisPoints > 100000 ||
        !['owe','owed'].contains(kind) || note.length > 400 ||
        (due != null && due!.isBefore(DateTime(created.year, created.month, created.day)))) {
      throw const FormatException('Invalid debt');
    }
  }
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'principalMinor': principalMinor,
    'currency': currency, 'aprBasisPoints': aprBasisPoints, 'created': created.toIso8601String(),
    'due': due?.toIso8601String(), 'note': note, 'kind': kind};
}

class Payment {
  const Payment({required this.id, required this.debtId, required this.amountMinor,
    required this.date, this.note = ''});
  final String id, debtId, note;
  final int amountMinor;
  final DateTime date;
  factory Payment.fromJson(Map<String,dynamic> x) {
    final payment = Payment(id:x['id'] as String,debtId:x['debtId'] as String,
      amountMinor:x['amountMinor'] as int,date:DateTime.parse(x['date'] as String),
      note:(x['note'] ?? '') as String);
    if (payment.id.isEmpty || payment.id.length>100 || payment.debtId.isEmpty ||
        payment.amountMinor<=0 || payment.amountMinor>10000000000000 || payment.note.length>400) {
      throw const FormatException('Invalid payment');
    }
    return payment;
  }
  Map<String,dynamic> toJson()=>{'id':id,'debtId':debtId,'amountMinor':amountMinor,
    'date':date.toIso8601String(),'note':note};
}

class DebtBook {
  const DebtBook({this.debts = const [], this.payments = const []});
  final List<Debt> debts;
  final List<Payment> payments;
  int paid(String id) => payments.where((p)=>p.debtId==id).fold(0,(sum,p)=>sum+p.amountMinor);
  int remaining(Debt debt) => debt.principalMinor - paid(debt.id);
  int total(String currency,{String kind='owe'}) => debts.where((d)=>d.currency==currency && d.kind==kind)
    .fold(0,(sum,d)=>sum+remaining(d));
  factory DebtBook.fromJson(Map<String,dynamic> json) {
    if(json['version'] != 1) throw const FormatException('Unsupported schema');
    final debts = (json['debts'] as List).map((x)=>Debt.fromJson(Map<String,dynamic>.from(x as Map))).toList();
    final payments = (json['payments'] as List).map((x)=>Payment.fromJson(Map<String,dynamic>.from(x as Map))).toList();
    if(debts.length>2000 || payments.length>20000 ||
      debts.map((d)=>d.id).toSet().length != debts.length ||
      payments.map((p)=>p.id).toSet().length != payments.length) throw const FormatException('Duplicate or excessive records');
    final book=DebtBook(debts:debts,payments:payments);
    for(final payment in payments){
      final match=debts.where((d)=>d.id==payment.debtId);
      if(match.isEmpty || payment.date.isBefore(match.first.created))throw const FormatException('Orphan payment');
    }
    for(final debt in debts){if(book.remaining(debt)<0)throw const FormatException('Overpaid debt');}
    return book;
  }
  Map<String,dynamic> toJson()=>{'version':1,'debts':debts.map((d)=>d.toJson()).toList(),
    'payments':payments.map((p)=>p.toJson()).toList()};
}

/// Purely illustrative fixed-rate amortization; excludes taxes, fees and daily accrual.
class Installment {
  const Installment(this.month, this.paymentMinor, this.interestMinor, this.balanceMinor);
  final int month,paymentMinor,interestMinor,balanceMinor;
}
List<Installment> estimateSchedule(int principalMinor, int aprBasisPoints, int months) {
  if(principalMinor<=0 || principalMinor>10000000000000 || aprBasisPoints<0 || aprBasisPoints>100000 || months<1 || months>600) {
    throw ArgumentError('Invalid installment inputs');
  }
  final rate=aprBasisPoints/120000;
  final monthly=rate==0 ? principalMinor/months : principalMinor*rate/(1-math.pow(1+rate,-months));
  var balance=principalMinor;
  final rows=<Installment>[];
  for(var m=1;m<=months;m++){
    final interest=(balance*rate).round();
    final payment=m==months ? balance+interest : math.min(balance+interest,monthly.round());
    balance=math.max(0,balance+interest-payment);
    rows.add(Installment(m,payment,interest,balance));
  }
  return rows;
}
