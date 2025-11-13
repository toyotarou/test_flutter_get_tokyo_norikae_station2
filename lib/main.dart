import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/controllers_mixin.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => AppRootState();
}

class AppRootState extends State<AppRoot> {
  Key _appKey = UniqueKey();

  ///
  void restartApp() => setState(() => _appKey = UniqueKey());

  ///
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MyApp(key: _appKey, onRestart: restartApp),
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, required this.onRestart});

  // ignore: unreachable_from_main
  final VoidCallback onRestart;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with ControllersMixin<MyApp> {
  ///
  @override
  void initState() {
    super.initState();

    // ★ 重要ポイント：
    //   ProviderScope のビルドが完了した「次のフレーム」で API を叩くようにする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tokyoTrainStationNotifier.getAllTokyoTrainStation();
    });
  }

  ///
  @override
  Widget build(BuildContext context) {
    // ControllersMixin 経由で Riverpod の state を参照
    final lineModelList = tokyoTrainStationState.lineModelList;

    // データがまだ空の間はローディング表示にする
    Widget homeBody;
    if (lineModelList.isEmpty) {
      homeBody = const Center(child: CircularProgressIndicator());
    } else {
      // データが入ったら HomeScreen に List<LineModel> を渡す
      homeBody = HomeScreen(lineModelList: lineModelList);
    }

    return MaterialApp(
      // ignore: always_specify_types
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      supportedLocales: const <Locale>[Locale('en'), Locale('ja')],

      theme: ThemeData(
        scrollbarTheme: const ScrollbarThemeData().copyWith(
          thumbColor: MaterialStateProperty.all(Colors.greenAccent.withOpacity(0.4)),
        ),
        useMaterial3: false,
        colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark),
        highlightColor: Colors.grey,
      ),

      themeMode: ThemeMode.dark,
      title: 'LIFETIME LOG',
      debugShowCheckedModeBanner: false,
      home: GestureDetector(onTap: () => primaryFocus?.unfocus(), child: homeBody),
    );
  }
}
