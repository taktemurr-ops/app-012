import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/storage.dart';
import 'ui/home.dart';
import 'ui/words.dart';
void main(){WidgetsFlutterBinding.ensureInitialized();runApp(DebtApp(controller:DebtController(const EncryptedDebtStorage())));}
class DebtApp extends StatefulWidget {
  const DebtApp({super.key,required this.controller});
  final DebtController controller;
  @override State<DebtApp> createState()=>_DebtAppState();
}
class _DebtAppState extends State<DebtApp> {
  @override void initState(){super.initState();widget.controller.load();}
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'Debt 360',debugShowCheckedModeBanner:false,
    theme:ThemeData(colorSchemeSeed:Colors.teal,useMaterial3:true),
    supportedLocales:Words.supported,
    localizationsDelegates:const [GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
    localeResolutionCallback:(locale,supported){for(final x in supported){if(x.languageCode==locale?.languageCode)return x;}return const Locale('en');},
    home:DebtHome(controller:widget.controller));
}
