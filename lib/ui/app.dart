import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'shell.dart';
import 'theme.dart';

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgendaIA',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AppShell(),
    );
  }
}
