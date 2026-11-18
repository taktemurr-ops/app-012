import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borc_360/core/storage.dart';
import 'package:borc_360/main.dart';
import 'package:borc_360/ui/words.dart';
void main(){
  test('all locales contain keys',(){expect(Words.complete(),isTrue);});
  testWidgets('app shows empty debt list', (tester)async{
    final controller=DebtController(MemoryDebtStorage());
    await tester.pumpWidget(DebtApp(controller:controller));await tester.pumpAndSettle();
    expect(find.byType(NavigationBar),findsOneWidget);
    expect(find.byType(FloatingActionButton),findsOneWidget);
    controller.dispose();
  });
}
