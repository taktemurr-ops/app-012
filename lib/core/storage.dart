import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'debt.dart';

abstract class DebtStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}
class EncryptedDebtStorage implements DebtStorage {
  const EncryptedDebtStorage();
  static const _key='borc360-data-v1';
  static const _storage=FlutterSecureStorage(aOptions:AndroidOptions(encryptedSharedPreferences:true));
  @override Future<String?> read()=>_storage.read(key:_key);
  @override Future<void> write(String value)=>_storage.write(key:_key,value:value);
  @override Future<void> delete()=>_storage.delete(key:_key);
}
class MemoryDebtStorage implements DebtStorage {
  String? data;
  bool failWrite=false,failRead=false;
  @override Future<String?> read() async {if(failRead)throw StateError('Read failed');return data;}
  @override Future<void> write(String value) async {if(failWrite)throw StateError('Write failed');data=value;}
  @override Future<void> delete() async {if(failWrite)throw StateError('Delete failed');data=null;}
}
class DebtController extends ChangeNotifier {
  DebtController(this.storage);
  final DebtStorage storage;
  DebtBook _book=const DebtBook();
  DebtBook get book=>_book;
  bool loaded=false;
  String? error;
  Future<void> _queue=Future<void>.value();
  Future<void> load() async {
    if(loaded)return;
    try {
      final raw=await storage.read();
      if(raw!=null){
        if(raw.length>2000000)throw const FormatException('Too large');
        _book=DebtBook.fromJson(Map<String,dynamic>.from(jsonDecode(raw) as Map));
      }
    }catch(_){error='Unable to read encrypted data';}
    loaded=true;notifyListeners();
  }
  Future<void> _commit(DebtBook Function(DebtBook) change) {
    final task=_queue.then((_)async {
      if(!loaded || error!=null)throw StateError('Data unavailable');
      final candidate=change(_book);
      final raw=jsonEncode(candidate.toJson());
      if(raw.length>1500000)throw StateError('Storage limit');
      final normalized=DebtBook.fromJson(Map<String,dynamic>.from(jsonDecode(raw) as Map));
      await storage.write(raw);
      _book=normalized;
      notifyListeners();
    });
    _queue=task.catchError((Object _){});
    return task;
  }
  Future<void> addDebt(Debt debt)=>_commit((x) {
    debt.validate();
    if(x.debts.any((d)=>d.id==debt.id))throw ArgumentError('Duplicate debt');
    return DebtBook(debts:[...x.debts,debt],payments:x.payments);
  });
  Future<void> pay(String debtId,int amount,{String note=''})=>_commit((x){
    final matches=x.debts.where((d)=>d.id==debtId);
    if(matches.isEmpty)throw ArgumentError('Debt not found');
    if(amount<=0 || amount>x.remaining(matches.first))throw ArgumentError('Invalid repayment');
    if(note.length>400)throw ArgumentError('Note too long');
    final payment=Payment(id:newId(),debtId:debtId,amountMinor:amount,date:DateTime.now(),note:note);
    return DebtBook(debts:x.debts,payments:[...x.payments,payment]);
  });
  Future<void> removeDebt(String id)=>_commit((x)=>DebtBook(
    debts:x.debts.where((d)=>d.id!=id).toList(),
    payments:x.payments.where((p)=>p.debtId!=id).toList()));
  Future<void> undoPayment(String id)=>_commit((x){
    if(!x.payments.any((p)=>p.id==id))throw ArgumentError('Payment not found');
    return DebtBook(debts:x.debts,payments:x.payments.where((p)=>p.id!=id).toList());
  });
  Future<void> importJson(String raw)=>_commit((_) {
    if(raw.length>1500000)throw const FormatException('Backup too large');
    return DebtBook.fromJson(Map<String,dynamic>.from(jsonDecode(raw) as Map));
  });
  String exportJson()=>const JsonEncoder.withIndent('  ').convert(_book.toJson());
  Future<void> clearAll()=>_commit((_)=>const DebtBook());
}
