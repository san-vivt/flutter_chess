import 'dart:math';

import 'package:chess_bot/chess_board/chess.dart';
import 'package:chess_bot/chess_board/flutter_chess_board.dart';
import 'package:chess_bot/chess_board/src/chess_sub.dart' as chess_sub;
import 'package:chess_bot/generated/i18n.dart';
import 'package:chess_bot/utils.dart';
import 'package:chess_bot/widgets/fancy_button.dart';
import 'package:chess_bot/widgets/modal_progress_hud.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lite_rolling_switch/lite_rolling_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chess_board/src/chess_board.dart';
import 'chess_controller.dart';

S strings;
ChessController _chessController;
SharedPreferences prefs;

void main() async {
  //run the app
  runApp(MyApp());
  //add all licenses
  addLicenses();
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    //set fullscreen
    SystemChrome.setEnabledSystemUIOverlays([]);
    //and portrait only
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

    //create the material app
    return MaterialApp(
      //manage resources first
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      //define title etc.
      title: app_name,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.indigo,

        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomepageState createState() => _MyHomepageState();
}

class _MyHomepageState extends State<MyHomePage> {
  Future<void> _loadEverythingUp() async {
    await _chessController.loadOldGame();
    //set the king in chess board
    _chessController.setKingInCheckSquare();
    //await prefs
    prefs = await SharedPreferences.getInstance();
    //load values from prefs
    //the chess controller has already been set here!
    _chessController.botColor =
        chess_sub.Color.fromInt(prefs.getInt('bot_color') ?? 1);
    _chessController.whiteSideTowardsUser =
        prefs.getBool('whiteSideTowardsUser') ?? true;
    _chessController.botBattle = prefs.getBool('botbattle') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    //set strings object
    strings ??= S.of(context);
    //init the context singleton object
    ContextSingleton(context);
    //build the chess controller,
    //if needed set context newly
    if (_chessController == null)
      _chessController = ChessController(context);
    else
      _chessController.context = context;
    //future builder: load old screen and show here on start the loading screen,
    //when the future is finished,
    //with setState show the real scaffold
    //return the view
    return (_chessController.game == null)
        ? FutureBuilder(
            future: _loadEverythingUp(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  var error = snapshot.error;
                  print('$error');
                  return Center(child: Text(strings.error));
                }

                return MyHomePageAfterLoading();
              } else {
                return Center(
                    child: ModalProgressHUD(
                  child: Container(),
                  inAsyncCall: true,
                ));
              }
            },
          )
        : MyHomePageAfterLoading();
  }
}

class MyHomePageAfterLoading extends StatefulWidget {
  MyHomePageAfterLoading({Key key}) : super(key: key);

  @override
  _MyHomePageAfterLoadingState createState() => _MyHomePageAfterLoadingState();
}

class _MyHomePageAfterLoadingState extends State<MyHomePageAfterLoading>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _chessController.saveOldGame();
        break;
      default:
        break;
    }
  }

  void update() {
    setState(() {});
  }

  Future<bool> _onWillPop() async {
    _chessController.saveOldGame();
    return true;
  }

  void _onAbout() async {
    //show the about dialog
    showAboutDialog(
      context: context,
      applicationVersion: version,
      applicationIcon: Image.asset(
        'res/drawable/ic_launcher.png',
        width: 50,
        height: 50,
      ),
      applicationLegalese: await rootBundle.loadString('res/licenses/this'),
      children: [
        FancyButton(
          onPressed: () => launch(strings.privacy_url),
          text: strings.privacy_title,
        )
      ],
    );
  }

  void _onWarning() {
    showTextDialog("Warning!", null,
        forceCancelText: 'no',
        onDoneText: 'yes',
        icon: Icons.warning,
        onDone: (value) {},
        children: [Image.asset('res/drawable/moo.png')]);
  }

  @override
  Widget build(BuildContext context) {
    //get the available height for the chess board
    double availableHeight = MediaQuery.of(context).size.height - 200;
    //set the update method
    _chessController.update = update;
    //the default scaffold
    return WillPopScope(
      onWillPop: _onWillPop,
      child: ModalProgressHUD(
        inAsyncCall: ChessController.loadingBotMoves,
        progressIndicator: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            Text(
              strings.moves_done(_chessController.progress),
              style: Theme.of(context).textTheme.bodyText1,
            ),
          ],
        ),
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.brown[50],
            body: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FlatButton(
                                shape: roundButtonShape,
                                onPressed: () {
                                  //inverse the bot color and save it
                                  _chessController.botColor =
                                      chess_sub.Color.flip(
                                          _chessController.botColor);
                                  //save value int to prefs
                                  prefs.setInt('bot_color',
                                      _chessController.botColor.value);
                                  //set state, update the views
                                  setState(() {});
                                  //make move if needed
                                  _chessController.makeBotMoveIfRequired();
                                },
                                child: Text((_chessController.botColor ==
                                        chess_sub.Color.WHITE)
                                    ? strings.white
                                    : strings.black)),
                            LiteRollingSwitch(
                              value: (prefs.getBool("bot") ?? false),
                              onChanged: (pos) {
                                prefs.setBool("bot", pos);
                                //make move if needed
                                _chessController?.makeBotMoveIfRequired();
                              },
                              iconOn: Icons.done,
                              iconOff: Icons.close,
                              textOff: strings.bot_off,
                              textOn: strings.bot_on,
                              colorOff: Colors.red[800],
                              colorOn: Colors.green[800],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                            strings.turn_of_x(
                                (_chessController?.game?.game?.turn ==
                                        chess_sub.Color.BLACK)
                                    ? strings.black
                                    : strings.white),
                            style: Theme.of(context)
                                .textTheme
                                .subtitle1
                                .copyWith(
                                  inherit: true,
                                  color: (_chessController?.game?.in_check() ??
                                          false)
                                      ? ((_chessController.game.inCheckmate(
                                              _chessController.game
                                                  .moveCountIsZero()))
                                          ? Colors.purple
                                          : Colors.red)
                                      : Colors.black,
                                )),
                      ),
                      Center(
                        // Center is a layout widget. It takes a single child and positions it
                        // in the middle of the parent.
                        child: SafeArea(
                          child: ChessBoard(
                            boardType: boardTypeFromString(
                                prefs.getString('board_style') ?? 'd'),
                            size: min(MediaQuery.of(context).size.width,
                                availableHeight),
                            onCheckMate: _chessController.onCheckMate,
                            onDraw: _chessController.onDraw,
                            onMove: _chessController.onMove,
                            onCheck: _chessController.onCheck,
                            chessBoardController: _chessController.controller,
                            chess: _chessController.game,
                            whiteSideTowardsUser:
                                _chessController.whiteSideTowardsUser,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FancyButton(
                            onPressed: _chessController.undo,
                            animation: FancyButtonAnimation.pulse,
                            icon: Icons.undo,
                          ),
                          SizedBox(
                            width: 8.0,
                          ),
                          FancyButton(
                            onPressed: _chessController.resetBoard,
                            icon: Icons.autorenew,
                          ),
                          SizedBox(
                            width: 8.0,
                          ),
                          FancyButton(
                            onPressed: _chessController.switchColors,
                            icon: Icons.switch_left,
                          ),
                          SizedBox(
                            width: 8.0,
                          ),
                          FancyButton(
                            onPressed: _chessController.onSetDepth,
                            icon: Icons.upload_rounded,
                            animation: FancyButtonAnimation.pulse,
                          ),
                          SizedBox(
                            width: 8.0,
                          ),
                          FancyButton(
                            onPressed: _chessController.changeBoardStyle,
                            icon: Icons.style,
                            animation: FancyButtonAnimation.pulse,
                          ),
                          SizedBox(
                            width: 8.0,
                          ),
                          FancyButton(
                            onPressed: _chessController.onFen,
                            text: 'fen',
                          ),
                          SizedBox(
                            width: 8.0,
                          ),
                          Container(
                            width: 150,
                            child: CheckboxListTile(
                              title: Text(strings.bot_vs_bot),
                              value: _chessController.botBattle,
                              onChanged: (value) {
                                prefs.setBool('botbattle', value);
                                _chessController.botBattle = value;
                                setState(() {});
                                //check if has to make bot move
                                if (!_chessController.makeBotMoveIfRequired()) {
                                  //since move has not been made, inverse the bot color and retry
                                  _chessController.botColor = Chess.swap_color(
                                      _chessController.botColor);
                                  _chessController.makeBotMoveIfRequired();
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: 8.0,
                          ),
                          FancyButton(
                            onPressed: () => (random.nextInt(80100) == 420)
                                ? _onWarning()
                                : _onAbout(),
                            icon: Icons.info,
                            animation: FancyButtonAnimation.pulse,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}