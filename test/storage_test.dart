import 'package:flutter_test/flutter_test.dart';
import 'package:borc_360/core/debt.dart';
import 'package:borc_360/core/storage.dart';
void main(){
  late MemoryDebtStorage storage;late DebtController c;late Debt debt;
  setUp(()async{storage=MemoryDebtStorage();c=DebtController(storage);await c.load();debt=Debt(id:'d1',name:'Loan',principalMinor:10000,currency:'TRY',aprBasisPoints:0,created:DateTime(2026,1,1));});
  tearDown((){c.dispose();});
  test('add, repay, undo, delete',()async{await c.addDebt(debt);await c.pay('d1',3500);expect(c.book.remaining(debt),6500);final id=c.book.payments.single.id;await c.undoPayment(id);expect(c.book.remaining(debt),10000);await c.removeDebt('d1');expect(c.book.debts,isEmpty);});
  test('cannot overpay',()async{await c.addDebt(debt);await expectLater(c.pay('d1',10001),throwsArgumentError);expect(c.book.payments,isEmpty);});
  test('failed persistence is atomic',()async{storage.failWrite=true;await expectLater(c.addDebt(debt),throwsStateError);expect(c.book.debts,isEmpty);storage.failWrite=false;await c.addDebt(debt);expect(c.book.debts,singleton(isA<Debt>()));});
  test('export import roundtrip',()async{await c.addDebt(debt);await c.pay('d1',100);final exported=c.exportJson();final restored=DebtController(MemoryDebtStorage());await restored.load();await restored.importJson(exported);expect(restored.book.remaining(debt),9900);restored.dispose();});
  test('invalid import preserves previous state',()async{await c.addDebt(debt);await expectLater(c.importJson('{invalid'),throwsFormatException);expect(c.book.debts.length,1);});
  test('clear all',()async{await c.addDebt(debt);await c.clearAll();expect(c.book.debts,isEmpty);expect(c.book.payments,isEmpty);});
  test('unreadable encrypted data blocks writes',()async{storage.data='{';final second=DebtController(storage);await second.load();expect(second.error,isNotNull);await expectLater(second.addDebt(debt),throwsStateError);second.dispose();});
}
