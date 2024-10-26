library libpttea.ptt_functions;

import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:ansiparser/ansiparser.dart' as ansiparser;
import './data_processor.dart' as dataProcessor;
import './pattern.dart' as pattern;
import './ptt_action.dart' as pttAction;
import 'sessions.dart';
import 'websocket_client.dart';
import 'package:big5_utf8_converter/big5_utf8_converter.dart';
import 'package:ansiparser/src/structures.dart';


final logger = Logger('libpttea');

Future<Session> _login(Session? session, String account, String password) async {
  // Create connection
  session = Session();
  

  unawaited(session.websocketClient.connect());
  logger.info("Connect to the WebSocket server");

  // Wait for connected
  while (!session.websocketClient.connected) {
      await Future.delayed(Duration(seconds: 10));
    }
  logger.info("WebSocket is connected");

  // Start login
  logger.info("Start login");
  final big5decoder = Big5Decoder();

  // Wait for the login screen to load.
  logger.fine("Wait for the login screen to load.");
  while (true) {
    var rawMessage = await session.receiveRaw();
    var message = big5decoder.big5ToUtf8String(rawMessage);
    if (message.contains("請輸入代號，或以 guest 參觀，或以 new 註冊")) {
      break;
    }
  }

  // Send account
  logger.fine("send account, $account");
  session.send(account);

  // Verify account
  logger.fine("verify account");

  var rawMessage = await session.receiveRaw();
  var message = utf8.decode(rawMessage, allowMalformed: true);
  if (message != account) {
    throw Exception("The sent account could not be verified.");
  } else {
    session.send(pattern.NEW_LINE);
  }

  // Check password hint
  logger.fine("check password hint");

  var rawMessageHint = await session.receiveRaw();
  var messageHint = big5decoder.big5ToUtf8String(rawMessageHint);
  if (!messageHint.contains("請輸入您的密碼")) {
    throw Exception("Check password hint failed.");
  }

  // Send password
  logger.fine("send password");

  session.send(password);
  session.send(pattern.NEW_LINE);

  // Check if the login was successful.
  logger.fine("Check if the login was successful.");

  var rawMessageLogin = await session.receiveRaw();
  var messageLogin = utf8.decode(rawMessageLogin, allowMalformed: true);
  if (!messageLogin.contains("密碼正確")) {
    throw Exception("Account or password is incorrect.");
  }

  // Check if the login process is starting to load.
  logger.fine("Check if the login process is starting to load.");

  var rawMessageLoad = await session.receiveRaw();
  var messageLoad = utf8.decode(rawMessageLoad, allowMalformed: true);
  if (!messageLoad.contains("登入中，請稍候")) {
    throw Exception("Check if the login start loading failed.");
  }

  logger.info("Logged in");
  return session;
}

Future<void> _skipLoginInit(Session session, {bool delDuplicate = true, bool delErrorLog = true}) async {
  logger.info("Skip the login initialization step");

  // Skip - duplicate connections
  var messages = <String>[];

  var message = await session.receive();
  messages.add(message);

  const findDuplicate = "您想刪除其他重複登入的連線嗎";
  if (message.contains(findDuplicate)) {
    logger.fine("Skip - duplicate connections");

    // Send selection
    if (delDuplicate) {
      session.send("y");
      await session.untilString("y", drop: true);
    } else {
      session.send("n");
      await session.untilString("n", drop: true);
    }

    session.send(pattern.NEW_LINE);

    // Wait for duplicate connections to be deleted
    messages = await session.untilString("按任意鍵繼續", timeout: 15);
  } else if (!message.contains("按任意鍵繼續")) {
    messages.addAll(await session.untilString("按任意鍵繼續"));
  }

  // Skip - system is busy
  const findBusy = "請勿頻繁登入以免造成系統過度負荷";
  if (messages.any((m) => m.contains(findBusy))) {
    logger.fine("Skip - system is busy");
    session.send(pattern.NEW_LINE);

    messages = await session.untilString("按任意鍵繼續");
  }

  // Skip - last login ip
  const findLastIp = "歡迎您再度拜訪，上次您是從";
  if (messages.any((m) => m.contains(findLastIp))) {
    logger.fine("Skip - last login ip");
    session.send(pattern.NEW_LINE);
  } else {
    throw Exception("Last login IP check failed.");
  }

  // Skip - Last login attempt failed
  var messagesError = <String>[];

  var messageError = await session.receive();

  const findErrorLog = "您要刪除以上錯誤嘗試的記錄嗎";
  if (messageError.contains(findErrorLog)) {
    logger.fine("Skip - Last login attempt failed");

    // Send selection
    if (delErrorLog) {
      session.send("y");
      await session.untilString("y", drop: true);
    } else {
      session.send("n");
      await session.untilString("n", drop: true);
    }

    session.send(pattern.NEW_LINE);
  } else {
    messagesError.add(messageError);
  }

  // Wait for the home menu to load
  for (final msg in messagesError) {
    session.ansipScreen.put(msg);
  }

  while (true) {
    await session.receiveAndPut();

    if (session.router.inHome()) {
      // Init router
      session.router.initHome();
      break;
    }
  }
}

Future<Session> login(Session? session, String account, String password, bool delDuplicate, bool delErrorLog) async {
  logger.info("login");

  if (session != null) {
    throw Exception("Is already logged in.");
  }

  // Add ',' to get the UTF-8 response from the PTT WebSocket connection.
  session = await _login(session, "$account,", password);

  await _skipLoginInit(session, delDuplicate: delDuplicate, delErrorLog: delErrorLog);

  return session;
}

Future<List<String>> _getSystemInfoPage(Session session) async {
  // Get the PTT system info page
  if (session.router.location() != "/utility/info") {
    await session.router.go("/utility/info");
  }

  final systemInfoPage = session.ansipScreen.toFormattedString();
  logger.fine("Got system_info_page.");

  return systemInfoPage;
}

Future<List<String>> getSystemInfo(Session? session) async {
  logger.info("get_system_info");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  final systemInfoPage = await _getSystemInfoPage(session);

  final systemInfo = dataProcessor.getSystemInfo(systemInfoPage);

  return systemInfo;
}

Future<void> _logout(Session session) async {
  // Log out from PTT.
  if (session.router.location() != "/") {
    await session.router.go("/");
  }

  // Select logout index
  logger.fine("select logout index");
  session.send("g");
  session.send(pattern.RIGHT_ARROW);

  // Wait for logout confirmation prompt.
  logger.fine("Wait for logout confirmation prompt");
  await session.untilString("您確定要離開");

  // Send yes
  logger.fine("send yes");
  session.send("y");
  await session.untilString("y");
  session.send(pattern.NEW_LINE);

  // Check logout success
  logger.fine("check logout success");
  await session.untilString("期待您下一次的光臨");
}

Future<void> logout(Session? session, {bool force = false}) async {
  logger.info("logout");

  if (session == null) {
    throw Exception("Is already logged out");
  }

  try {
    await _logout(session);
    // print("");
  } catch (e) {
    logger.fine("logout timeout");
    
    if (!force) {
      throw Exception("logout failed");
    } else {
      logger.info("force logout");
    }
  }

  logger.info("Logged out");

  await session.websocketClient.close();
  session = null;
}

Future<List<List<String>>> _getFavoriteListPages(Session session) async {
  // Get the favorite list pages
  if (session.router.location() != "/favorite") {
    await session.router.go("/favorite");
  }

  // Pages
  final favoritePages = <List<String>>[];
  favoritePages.add(session.ansipScreen.toFormattedString()); // current page

  // Check if more than 1 page
  session.send(pattern.PAGE_DOWN); // to next page
  while (true) {
    // Wait page load
    final message = await session.receiveAndPut();

    if (message.contains("\x1b[4;1H")) {
      // More than 1 page
      session.ansipScreen.parse();

      final currentPage = session.ansipScreen.toFormattedString();
      favoritePages.add(currentPage);

      if (currentPage[currentPage.length-2] == "") {
        // Next page only has 1 item
        break;
      } else {
        session.send(pattern.PAGE_DOWN); // to next page
        continue;
      }
    }

    final match = RegExp(r"\d{1,2};1H>").firstMatch(message);
    if (match != null) {
      break;
    }
  }

  return favoritePages;
}

Future<List<Map<String, String?>>> getFavoriteList(Session? session) async {
  logger.info("get_favorite_list");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  final favoritePages = await _getFavoriteListPages(session);
  logger.info("Get favorite list pages successfully.");

  final favoriteList = dataProcessor.getFavoriteList(favoritePages);
  logger.fine("Get favorite list successfully.");

  return favoriteList;
}



Future<List<String>> _getBoardPage(Session session, String board) async {
  // Get the board pages
  if (session.router.location() != "/favorite/$board") {
    await session.router.go("/favorite/$board");
  }

  final boardPage = session.ansipScreen.toFormattedString();
  return boardPage;
}

Future<int> getLatestPostIndex(Session? session, String board) async {
  // Get the latest post index
  logger.info("get_latest_post_index");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  if (board.isEmpty) {
    throw Exception("board is empty");
  }

  final boardPage = await _getBoardPage(session, board);
  final latestPostIndex = dataProcessor.getLatestPostIndex(boardPage);

  return latestPostIndex;
}

Future<List<List<String>>> _getBoardPagesByRange(Session session, String board, int start, int stop) async {
  // Get the board pages by range
  int __getTopIndex(List<String> screen) {
    final topLine = screen[3];
    final topElement = dataProcessor.processBoardLine(topLine);
    if (topElement == null) {
      throw Exception("Top element could not be processed");
    }
    return int.parse(topElement['index']!);
  }

  if (session.router.location() != "/favorite/$board") {
    await session.router.go("/favorite/$board");
  }

  // Find index
  await pttAction.searchIndex(session, stop);

  // Pages
  List<List<String>> boardPages = [];

  // Add current
  final currentScreen = session.ansipScreen.toFormattedString();
  boardPages.add(currentScreen);

  // Check top index in screen
  int topIndex = __getTopIndex(currentScreen);

  // If pages not enough
  while (topIndex > start) {
    // Go to previous page
    session.send(pattern.PAGE_UP);

    // Wait for new page to load
    await session.untilRegexAndPut(RegExp(r".+\x1B\[4;1H$"));

    session.ansipScreen.parse();
    final currentScreen = session.ansipScreen.toFormattedString();
    boardPages.add(currentScreen);

    // Check top index in screen
    topIndex = __getTopIndex(currentScreen);
  }

  return boardPages;
}

Future<List<Map<String, String?>>> getPostListByRange(Session? session, String board, int start, int stop) async {
  // Get the post list by range; the `start` < `stop` is required.
  logger.info("get_post_list");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  if (start >= stop) {
    throw Exception("parameter error , `start` < `stop` is required");
  }

  final boardPages = await _getBoardPagesByRange(session, board, start, stop);
  final postList = dataProcessor.getPostListByRange(boardPages, start, stop);

  return postList;
}

Future<List<String>> _getPostPage(Session session, String oldPostStatusBar) async {
  // Get a post page
  while (true) {
    await session.receiveAndPut();
    session.ansipScreen.parse();
    final currentScreen = session.ansipScreen.toFormattedString();

    // Check status bar
    final postStatusBar = currentScreen.last;
    final match = pattern.regexPostStatusBar.firstMatch(currentScreen.last);
    if (match != null && postStatusBar != oldPostStatusBar) {
      oldPostStatusBar = postStatusBar;
      return currentScreen;
    }
  }
}

Stream<List<InterConverted>> _getFullPost(Session session, String board, int index) async* {
  // Get a complete post that consists of multiple pages
  int __extractProgress(String postStatusBar) {
    final match = pattern.regexPostStatusBar.firstMatch(postStatusBar);
    if (match != null) {
      return int.parse(match.namedGroup("progress")!);
    } else {
      throw Exception("Extract progress from the status bar error.");
    }
  }

  if (session.router.location() != "/favorite/$board/$index") {
    await session.router.go("/favorite/$board/$index");
  }

  // Yield the current page
  var currentScreen = session.ansipScreen.toFormattedString();
  yield session.ansipScreen.getParsedScreen();

  int progress = __extractProgress(currentScreen.last);

  // Until the post loading is complete
  while (progress < 100) {
    final oldPostStatusBar = currentScreen.last;
    session.send(pattern.PAGE_DOWN); // Next page

    // Yield the new page
    currentScreen = await _getPostPage(session, oldPostStatusBar);
    yield session.ansipScreen.getParsedScreen();

    progress = __extractProgress(currentScreen.last);
  }
}

Stream<(List<String>, List<Map<String, String?>>)> getPost(Session? session, String board, int index) async* {
  // Get the post
  logger.info("get_post");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  List<String> lastPage = [];
  int differentIndex = 0;
  
  await for (final rawPage in _getFullPost(session, board, index)) {
    final page = ansiparser.fromScreen(rawPage).toFormattedString();

    if (lastPage.isNotEmpty) {
      differentIndex = dataProcessor.getDifferentIndex(page, lastPage);
    }

    lastPage = page;

    var contentAndReplies = dataProcessor.getPostPage(rawPage.sublist(differentIndex));
    yield contentAndReplies;
  }
}