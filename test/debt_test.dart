import 'package:flutter_test/flutter_test.dart';
import 'package:borc_360/core/debt.dart';
void main(){
  test('locale amount parsing',(){expect(parseMoney('123.45'),12345);expect(parseMoney('١٢٣٫٤٥'),12345);expect(parseMoney('123,45'),12345);expect(parseMoney('1,234.50'),123450);expect(()=>parseMoney('-1'),throwsFormatException);});
  test('zero-interest schedule reconciles',(){final x=estimateSchedule(10000,0,3);expect(x.last.balanceMinor,0);expect(x.fold<int>(0,(n,e)=>n+e.paymentMinor),10000);});
  test('interest increases total repayment',(){final x=estimateSchedule(100000,1200,12);expect(x.last.balanceMinor,0);expect(x.fold<int>(0,(n,e)=>n+e.paymentMinor),greaterThan(100000));});
  test('reject invalid installment input',(){expect(()=>estimateSchedule(0,0,1),throwsArgumentError);expect(()=>estimateSchedule(100,0,0),throwsArgumentError);});
  test('ledger rejects orphan payment',(){expect(()=>DebtBook.fromJson({'version':1,'debts':[],'payments':[{'id':'p','debtId':'missing','amountMinor':10,'date':DateTime.now().toIso8601String()}]}),throwsFormatException);});
}
