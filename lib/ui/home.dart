import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/debt.dart';
import '../core/storage.dart';
import 'words.dart';

class DebtHome extends StatefulWidget {
  const DebtHome({super.key,required this.controller});
  final DebtController controller;
  @override State<DebtHome> createState()=>_DebtHomeState();
}
class _DebtHomeState extends State<DebtHome> {
  int tab=0;
  final plannerPrincipal=TextEditingController(), plannerRate=TextEditingController(text:'0'), plannerMonths=TextEditingController(text:'12');
  List<Installment>? plannerRows;
  final currency=const ['TRY','USD','EUR','GBP'];
  String money(int minor,String code)=>NumberFormat.currency(locale:Localizations.localeOf(context).toString(),name:code).format(minor/100);
  Future<void> action(Future<void> Function() work)async{
    try{await work();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(Words.of(context).get('done'))));}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(Words.of(context).get('error'))));}
  }
  @override void dispose(){plannerPrincipal.dispose();plannerRate.dispose();plannerMonths.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final w=Words.of(context),c=widget.controller;
    return AnimatedBuilder(animation:c,builder:(context,_)=>Scaffold(
      appBar:AppBar(title:Text(w.get('app'))),
      body:!c.loaded?const Center(child:CircularProgressIndicator()):c.error!=null?
        Center(child:Padding(padding:const EdgeInsets.all(20),child:Text(c.error!))):
        IndexedStack(index:tab,children:[_debts(w),_summary(w),_history(w),_planner(w),_settings(w)]),
      floatingActionButton:tab==0 && c.error==null?FloatingActionButton.extended(onPressed:()=>_newDebt(w),label:Text(w.get('new')),icon:const Icon(Icons.add)):null,
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:[
        NavigationDestination(icon:const Icon(Icons.account_balance_wallet_outlined),label:w.get('debts')),
        NavigationDestination(icon:const Icon(Icons.pie_chart_outline),label:w.get('summary')),
        NavigationDestination(icon:const Icon(Icons.history),label:w.get('history')),
        NavigationDestination(icon:const Icon(Icons.calculate_outlined),label:w.get('tools')),
        NavigationDestination(icon:const Icon(Icons.settings_outlined),label:w.get('settings'))])));
  }
  Widget _debts(Words w){
    final ds=widget.controller.book.debts;
    if(ds.isEmpty)return Center(child:Text(w.get('empty')));
    return ListView.builder(padding:const EdgeInsets.only(bottom:95),itemCount:ds.length,itemBuilder:(context,i){
      final d=ds[i],remaining=widget.controller.book.remaining(d);
      final overdue=d.due!=null && remaining>0 && d.due!.isBefore(DateTime.now());
      return Card(child:ListTile(title:Text(d.name),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${w.get('remaining')}: ${money(remaining,d.currency)}'),
        Text('${d.kind=='owe'?w.get('owe'):w.get('owed')} • ${remaining==0?w.get('paid'):overdue?w.get('overdue'):w.get('open')}'),
        LinearProgressIndicator(value:(widget.controller.book.paid(d.id)/d.principalMinor).clamp(0,1).toDouble()),
      ]),trailing:PopupMenuButton<String>(onSelected:(value){if(value=='pay')_pay(d,w);if(value=='delete')_delete(d,w);},itemBuilder:(context)=>[
        PopupMenuItem(value:'pay',enabled:remaining>0,child:Text(w.get('pay'))),PopupMenuItem(value:'delete',child:Text(w.get('delete')))]),onTap:()=>_details(d,w)));
    });
  }
  Widget _summary(Words w){
    final book=widget.controller.book;
    return ListView(padding:const EdgeInsets.all(16),children:[
      for(final kind in ['owe','owed'])...[
        Text(w.get(kind),style:Theme.of(context).textTheme.titleLarge),
        for(final code in currency) if(book.debts.any((d)=>d.currency==code && d.kind==kind))
          Card(child:ListTile(title:Text(code),trailing:Text(money(book.total(code,kind:kind),code)))),
      ],
      const SizedBox(height:16),Text('${w.get('open')}: ${book.debts.where((d)=>book.remaining(d)>0).length}'),
      Text('${w.get('paid')}: ${book.debts.where((d)=>book.remaining(d)==0).length}'),
      Text('${w.get('overdue')}: ${book.debts.where((d)=>d.due!=null && book.remaining(d)>0 && d.due!.isBefore(DateTime.now())).length}'),
    ]);
  }
  Widget _history(Words w){
    final book=widget.controller.book,entries=[...widget.controller.book.payments]..sort((a,b)=>b.date.compareTo(a.date));
    if(entries.isEmpty)return Center(child:Text(w.get('empty')));
    return ListView.builder(itemCount:entries.length,itemBuilder:(context,i){
      final p=entries[i],d=book.debts.firstWhere((d)=>d.id==p.debtId);
      return ListTile(title:Text('${d.name}: ${money(p.amountMinor,d.currency)}'),subtitle:Text(DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(p.date)),
        trailing:IconButton(tooltip:w.get('undo'),icon:const Icon(Icons.undo),onPressed:()=>action(()=>widget.controller.undoPayment(p.id))));
    });
  }
  Widget _planner(Words w){
    return ListView(padding:const EdgeInsets.all(16),children:[
        Text(w.get('disclaimer')),TextField(controller:plannerPrincipal,keyboardType:TextInputType.decimal,decoration:InputDecoration(labelText:w.get('amount'))),
        TextField(controller:plannerRate,keyboardType:TextInputType.decimal,decoration:InputDecoration(labelText:w.get('apr'))),
        TextField(controller:plannerMonths,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:w.get('months'))),
        FilledButton(onPressed:(){try{final p=parseMoney(plannerPrincipal.text);final annual=(double.parse(plannerRate.text.replaceAll(',','.'))*100).round();final n=int.parse(plannerMonths.text);setState(()=>plannerRows=estimateSchedule(p,annual,n));}catch(_){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(w.get('error'))));}},child:Text(w.get('estimate'))),
        if(plannerRows!=null)for(final row in plannerRows!)ListTile(title:Text('${w.get('months')} ${row.month}: ${money(row.paymentMinor,'TRY')}'),subtitle:Text('${w.get('remaining')}: ${money(row.balanceMinor,'TRY')}')),
      ]);
  }
  Widget _settings(Words w)=>ListView(padding:const EdgeInsets.all(16),children:[
    ListTile(title:Text(w.get('privacy')),leading:const Icon(Icons.lock_outline)),
    ListTile(title:Text(w.get('export')),leading:const Icon(Icons.ios_share),onTap:()=>Share.share(widget.controller.exportJson(),subject:'Debt 360 backup')),
    ListTile(title:Text(w.get('import')),leading:const Icon(Icons.download),onTap:()=>_import(w)),
    ListTile(title:Text(w.get('clear')),leading:const Icon(Icons.delete_forever),onTap:()async{
      final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(w.get('clear')),content:Text(w.get('clearConfirm')),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(w.get('cancel'))),
        TextButton(onPressed:()=>Navigator.pop(c,true),child:Text(w.get('confirm')))]));
      if(ok==true)await action(()=>widget.controller.clearAll());
    }),
  ]);
  Future<void> _newDebt(Words w)async{
    final name=TextEditingController(),amount=TextEditingController(),rate=TextEditingController(text:'0'),note=TextEditingController();
    var code='TRY',kind='owe';DateTime? due;
    final submitted=await showDialog<Debt>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:Text(w.get('new')),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,maxLength:90,decoration:InputDecoration(labelText:w.get('name'))),
        TextField(controller:amount,keyboardType:TextInputType.decimal,decoration:InputDecoration(labelText:w.get('amount'))),
        TextField(controller:plannerRate,keyboardType:TextInputType.decimal,decoration:InputDecoration(labelText:w.get('apr'))),
        TextField(controller:note,maxLength:400,decoration:InputDecoration(labelText:w.get('note'))),
        DropdownButton<String>(value:code,items:currency.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>update(()=>code=x!)),
        DropdownButton<String>(value:kind,items:['owe','owed'].map((x)=>DropdownMenuItem(value:x,child:Text(w.get(x)))).toList(),onChanged:(x)=>update(()=>kind=x!)),
        TextButton(onPressed:()async{final selected=await showDatePicker(context:ctx,firstDate:DateTime.now(),lastDate:DateTime(2100),initialDate:DateTime.now());if(selected!=null)update(()=>due=selected);},child:Text(due?.toIso8601String().substring(0,10)??w.get('due'))),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.get('cancel'))),
      FilledButton(onPressed:(){try{final d=Debt(id:newId(),name:validateName(name.text),principalMinor:parseMoney(amount.text),currency:code,
        aprBasisPoints:(double.parse(rate.text.replaceAll(',','.'))*100).round(),created:DateTime.now(),due:due,note:note.text,kind:kind);d.validate();Navigator.pop(ctx,d);}catch(_){ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(w.get('error'))));}},child:Text(w.get('save')))])));
    if(submitted!=null)await action(()=>widget.controller.addDebt(submitted));
  }
  Future<void> _pay(Debt debt,Words w)async{
    final amount=TextEditingController(),note=TextEditingController();
    final result=await showDialog<(int,String)>(context:context,builder:(ctx)=>AlertDialog(title:Text(w.get('pay')),
      content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:TextInputType.decimal,decoration:InputDecoration(labelText:w.get('amount'))),TextField(controller:note,maxLength:400,decoration:InputDecoration(labelText:w.get('note')))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.get('cancel'))),FilledButton(onPressed:(){try{Navigator.pop(ctx,(parseMoney(amount.text),note.text));}catch(_){ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(w.get('error'))));}},child:Text(w.get('save')))]));
    if(result!=null)await action(()=>widget.controller.pay(debt.id,result.$1,note:result.$2));
  }
  Future<void> _delete(Debt debt,Words w)async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(w.get('delete')),content:Text(debt.name),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(w.get('cancel'))),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(w.get('confirm')))]));
    if(ok==true)await action(()=>widget.controller.removeDebt(debt.id));
  }
  void _details(Debt debt,Words w){showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(debt.name,style:Theme.of(ctx).textTheme.titleLarge),Text('${w.get('total')}: ${money(debt.principalMinor,debt.currency)}'),Text('${w.get('remaining')}: ${money(widget.controller.book.remaining(debt),debt.currency)}'),Text('${w.get('apr')}: ${(debt.aprBasisPoints/100).toStringAsFixed(2)}'),if(debt.due!=null)Text('${w.get('due')}: ${DateFormat.yMMMd().format(debt.due!)}'),if(debt.note.isNotEmpty)Text(debt.note),const SizedBox(height:12)]))));}
  Future<void> _import(Words w)async{
    final controller=TextEditingController();
    final text=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text(w.get('import')),content:Column(mainAxisSize:MainAxisSize.min,children:[Text(w.get('importConfirm')),TextField(controller:controller,minLines:3,maxLines:8,decoration:InputDecoration(labelText:w.get('enterBackup')))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(w.get('cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:Text(w.get('confirm')))]));
    if(text!=null)await action(()=>widget.controller.importJson(text));
  }
}
