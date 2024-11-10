/// libpttea.ptt_functions
/// ----------
///
/// This module implements various PTT functions.
library;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:big5_utf8_converter/big5_utf8_converter.dart';
import 'package:ansiparser/ansiparser.dart' as ansiparser;
import 'package:ansiparser/src/structures.dart';

import './data_processor.dart' as data_processor;
import './pattern.dart' as pattern;
import './ptt_action.dart' as ptt_action;
import './sessions.dart';

final logger = Logger('libpttea');

/// Create connection and log in.
Future<void> _login(Session session, String account, String password) async {
  // Create connection
  logger.info("Connect to the WebSocket server");

  // Wait for connected
  await session.websocketClient.connect();
  logger.info("WebSocket is connected");

  // Start login
  // Use Big5 first and ignore errors (ignore Big5-UAO)
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
    session.send(pattern.newLine);
  }

  // Check password hint
  logger.fine("check password hint");

  rawMessage = await session.receiveRaw();
  message = big5decoder.big5ToUtf8String(rawMessage);
  if (!message.contains("請輸入您的密碼")) {
    throw Exception("Check password hint failed.");
  }

  // Send password
  logger.fine("send password");

  session.send(password);
  session.send(pattern.newLine);

  // Check if the login was successful.
  // If the login fails, will receive a mix of UTF-8 and Big5 UAO data.
  logger.fine("Check if the login was successful.");

  rawMessage = await session.receiveRaw();
  message = utf8.decode(rawMessage, allowMalformed: true);
  if (!message.contains("密碼正確")) {
    throw Exception("Account or password is incorrect.");
  }

  // Check if the login process is starting to load.
  logger.fine("Check if the login process is starting to load.");

  rawMessage = await session.receiveRaw();
  message = utf8.decode(rawMessage, allowMalformed: true);
  if (!message.contains("登入中，請稍候")) {
    throw Exception("Check if the login start loading failed.");
  }

  logger.info("Logged in");
  return;
}

/// Skip the login initialization step until the home menu is loaded.
Future<void> _skipLoginInit(Session session,
    {bool delDuplicate = true, bool delErrorLog = true}) async {
  logger.info("Skip the login initialization step");

  // Skip - duplicate connections
  // 注意: 您有其它連線已登入此帳號。您想刪除其他重複登入的連線嗎？[Y/n]
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

    session.send(pattern.newLine);

    // Wait for duplicate connections to be deleted
    messages = await session.untilString("按任意鍵繼續", timeout: 15);
  } else if (!message.contains("按任意鍵繼續")) {
    // no duplicate connections
    // and if not in first message
    messages.addAll(await session.untilString("按任意鍵繼續"));
  }

  // Skip - system is busy
  const findBusy = "請勿頻繁登入以免造成系統過度負荷";
  if (messages.any((m) => m.contains(findBusy))) {
    logger.fine("Skip - system is busy");
    session.send(pattern.newLine);

    // until last login ip
    messages = await session.untilString("按任意鍵繼續");
  }

  // Skip - last login ip
  const findLastIp = "歡迎您再度拜訪，上次您是從";
  if (messages.any((m) => m.contains(findLastIp))) {
    logger.fine("Skip - last login ip");
    session.send(pattern.newLine);
  } else {
    throw Exception("Last login IP check failed.");
  }

  // Skip - Last login attempt failed
  message = await session.receive();

  const findErrorLog = "您要刪除以上錯誤嘗試的記錄嗎";
  if (message.contains(findErrorLog)) {
    logger.fine("Skip - Last login attempt failed");

    // Send selection
    if (delErrorLog) {
      session.send("y");
      await session.untilString("y", drop: true);
    } else {
      session.send("n");
      await session.untilString("n", drop: true);
    }

    session.send(pattern.newLine);
  } else {
    // The message is part of the home menu.
    session.ansipScreen.put(message);
  }

  // Wait for the home menu to load
  while (true) {
    await session.receiveAndPut();

    if (session.router.inHome()) {
      // Init router
      session.router.initHome();
      break;
    }
  }
}

/// Log in to PTT.
Future<Session> login(Session? session, String account, String password,
    bool delDuplicate, bool delErrorLog, int timeoutDelay) async {
  logger.info("login");

  if (session != null) {
    throw Exception("Is already logged in.");
  } else {
    session = Session(timeoutDelay: timeoutDelay);
  }

  // Add ',' to get the UTF-8 response from the PTT WebSocket connection.
  await _login(session, "$account,", password);

  await _skipLoginInit(session,
      delDuplicate: delDuplicate, delErrorLog: delErrorLog);

  return session;
}

/// Get the PTT system info page
Future<List<String>> _getSystemInfoPage(Session session) async {
  if (session.router.location() != "/utility/info") {
    await session.router.go("/utility/info");
  }

  final systemInfoPage = session.ansipScreen.toFormattedString();
  logger.fine("Got system_info_page.");

  return systemInfoPage;
}

/// get the PTT system info
Future<List<String>> getSystemInfo(Session? session) async {
  logger.info("get_system_info");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  final systemInfoPage = await _getSystemInfoPage(session);

  final systemInfo = data_processor.getSystemInfo(systemInfoPage);

  return systemInfo;
}

/// Log out from PTT.
Future<void> _logout(Session session) async {
  //
  if (session.router.location() != "/") {
    await session.router.go("/");
  }

  // Select logout index
  logger.fine("select logout index");
  session.send("g");
  session.send(pattern.rightArrow);

  // Wait for logout confirmation prompt.
  logger.fine("Wait for logout confirmation prompt");
  await session.untilString("您確定要離開");

  // Send yes
  logger.fine("send yes");
  session.send("y");
  await session.untilString("y");
  session.send(pattern.newLine);

  // Check logout success
  logger.fine("check logout success");
  await session.untilString("期待您下一次的光臨");
}

/// Log out from PTT.
Future<void> logout(Session? session, {bool force = false}) async {
  logger.info("logout");

  if (session == null) {
    throw Exception("Is already logged out");
  }

  try {
    await _logout(session);
  } on TimeoutException {
    logger.fine("logout timeout");

    if (!force) {
      throw Exception("logout timeout");
    } else {
      logger.info("logout timeout , force logout");
    }
  } finally {
    logger.info("Logged out");
    await session.websocketClient.close();
  }

  session = null;
}

/// Get the favorite list pages
Future<List<List<String>>> _getFavoriteListPages(Session session) async {
  //
  if (session.router.location() != "/favorite") {
    await session.router.go("/favorite");
  }

  // Pages
  final favoritePages = <List<String>>[];
  favoritePages.add(session.ansipScreen.toFormattedString()); // current page

  // Check if more than 1 page
  session.send(pattern.pageDown); // to next page
  // Wait page load
  while (true) {
    final message = await session.receiveAndPut();

    if (RegExp(r".+\x1b\[4;1H$").hasMatch(message)) {
      // [4;1H at end
      // more than 1 page , now in next page
      session.ansipScreen.parse();

      final currentPage = session.ansipScreen.toFormattedString();
      favoritePages.add(currentPage);

      if (currentPage[currentPage.length - 2] == "") {
        // If the next page is last , it will contain empty lines.
        break;
      } else {
        session.send(pattern.pageDown); // to next page
        continue;
      }
    }

    // if page does not have an empty line.
    if (RegExp(r"\d{1,2};1H>").hasMatch(message)) {
      // Check if the "greater-than sign" has moved.
      // Same page, finished.
      break;
    }
  }

  // back to first page
  session.send(pattern.pageDown);

  return favoritePages;
}

/// get the favorite list
Future<List<Map<String, String>>> getFavoriteList(Session? session) async {
  logger.info("get_favorite_list");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  final favoritePages = await _getFavoriteListPages(session);

  final favoriteList = data_processor.getFavoriteList(favoritePages);

  return favoriteList;
}

/// get the latest board page
Future<List<String>> _getBoardPage(Session session, String board) async {
  //
  if (session.router.location() != "/favorite/$board") {
    await session.router.go("/favorite/$board");
  }

  final boardPage = session.ansipScreen.toFormattedString();

  return boardPage;
}

/// get the latest post index
Future<int> getLatestPostIndex(Session? session, String board) async {
  //
  logger.info("get_latest_post_index");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  if (board.isEmpty) {
    throw ArgumentError("board is empty");
  }

  final boardPage = await _getBoardPage(session, board);

  final latestPostIndex = data_processor.getLatestPostIndex(boardPage);

  return latestPostIndex;
}

/// Get the board pages by range
Future<List<List<String>>> _getBoardPagesByRange(
    Session session, String board, int start, int stop) async {
  //
  int _getTopIndex(List<String> screen) {
    //
    final topLine = screen[3];

    final topElement = data_processor.processBoardLine(topLine);

    return int.parse(topElement['index']!);
  }

  if (session.router.location() != "/favorite/$board") {
    await session.router.go("/favorite/$board");
  }

  // Find index
  await ptt_action.searchIndex(session, stop);

  // Pages
  List<List<String>> boardPages = [];

  // add current page
  final currentScreen = session.ansipScreen.toFormattedString();
  boardPages.add(currentScreen);

  // Check top index in screen
  int topIndex = _getTopIndex(currentScreen);

  // If pages not enough
  while (topIndex > start) {
    // Go to previous page
    session.send(pattern.pageUp);

    // Wait for new page to load
    // '[4;1H' at end
    await session.untilRegexAndPut(RegExp(r".+\x1B\[4;1H$"));

    session.ansipScreen.parse();
    final currentScreen = session.ansipScreen.toFormattedString();
    boardPages.add(currentScreen);

    // Check top index in screen
    topIndex = _getTopIndex(currentScreen);
  }

  return boardPages;
}

/// Get the post list by range; the `start` < `stop` is required.
Future<List<Map<String, String>>> getPostListByRange(
    Session? session, String board, int start, int stop) async {
  //
  logger.info("get_post_list");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  if (start >= stop) {
    throw ArgumentError("parameter error , `start` < `stop` is required");
  }

  final boardPages = await _getBoardPagesByRange(session, board, start, stop);

  final postList = data_processor.getPostListByRange(boardPages, start, stop);

  return postList;
}

/// Get a post page
Future<List<String>> _getPostPage(
    Session session, String oldPostStatusBar) async {
  // wait post page loaded
  while (true) {
    await session.receiveAndPut();
    session.ansipScreen.parse();
    final currentScreen = session.ansipScreen.toFormattedString();

    // Check status bar
    final postStatusBar = currentScreen.last;
    final match = pattern.regexPostStatusBar.firstMatch(currentScreen.last);
    // check status bar is complete and differs from the previous one
    if (match != null && postStatusBar != oldPostStatusBar) {
      oldPostStatusBar = postStatusBar;
      return currentScreen;
    }
  }
}

/// get a complete post that consists of multiple pages,
/// return an asynchronous generator that yields each raw page.
Stream<List<InterConverted>> _getFullPost(
    Session session, String board, int index) async* {
  //
  int _extractProgress(String postStatusBar) {
    //
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

  int progress = _extractProgress(currentScreen.last);

  // Until the post loading is complete
  while (progress < 100) {
    final oldPostStatusBar = currentScreen.last;
    session.send(pattern.pageDown); // Next page

    // Yield the new page
    currentScreen = await _getPostPage(session, oldPostStatusBar);
    yield session.ansipScreen.getParsedScreen();

    progress = _extractProgress(currentScreen.last);
  }
}

/// Get the post, return an Asynchronous Generator that yields post data.
Stream<(List<String>, List<Map<String, String>>)> getPost(
    Session? session, String board, int index) async* {
  //
  logger.info("get_post");

  if (session == null) {
    throw Exception("Not logged in yet.");
  }

  List<String> lastPage = [];
  int differentIndex = 0;

  await for (final rawPage in _getFullPost(session, board, index)) {
    final page = ansiparser.fromScreen(rawPage).toFormattedString();

    if (lastPage.isNotEmpty) {
      differentIndex = data_processor.getDifferentIndex(page, lastPage);
    }

    lastPage = page;

    var (contentsHtml, postReplies) =
        data_processor.getPostPage(rawPage.sublist(differentIndex));
    yield (contentsHtml, postReplies);
  }
}
