/// libpttea.api
/// ----------
///
/// This module implements the libpttea API.
library;

import 'dart:async';

import './ptt_functions.dart' as pttFunctions;
import './sessions.dart';

/// Log in to PTT.
///
/// 登入 PTT
Future<API> login(String account, String password,
    {bool delDuplicate = true,
    bool delErrorLog = true,
    int timeoutDelay = 0}) async {
  //
  final api = API();
  await api.login(account, password,
      delDuplicate: delDuplicate,
      delErrorLog: delErrorLog,
      timeoutDelay: timeoutDelay);

  return api;
}

class API {
  Session? session;

  /// Log in to PTT.
  ///
  /// 登入 PTT
  Future<void> login(String account, String password,
      {bool delDuplicate = true,
      bool delErrorLog = true,
      int timeoutDelay = 0}) async {
    //
    session = await pttFunctions.login(
        session, account, password, delDuplicate, delErrorLog, timeoutDelay);
  }

  /// Log out from PTT.
  ///
  /// 登出 PTT
  Future<void> logout({bool force = false}) async {
    //
    await pttFunctions.logout(session, force: force);
  }

  /// Get the PTT system info.
  ///
  /// 查看 PTT 系統資訊
  Future<List<String>> getSystemInfo() async {
    //
    return await pttFunctions.getSystemInfo(session);
  }

  /// Get the favorite list.
  ///
  /// 取得 "我的最愛" 清單
  Future<List<Map<String, String>>> getFavoriteList() async {
    //
    return await pttFunctions.getFavoriteList(session);
  }

  /// Get the latest post index.
  ///
  /// 取得最新的文章編號
  Future<int> getLatestPostIndex(String board) async {
    //
    return await pttFunctions.getLatestPostIndex(session, board);
  }

  /// Get the post list by range; the `start` < `stop` is required.
  ///
  /// 取得範圍內的文章列表
  Future<List<Map<String, String>>> getPostList(
      String board, int start, int stop) async {
    //
    return await pttFunctions.getPostListByRange(session, board, start, stop);
  }

  /// Get the post data.
  ///
  /// 取得文章資料
  Future<Stream<(List<String>, List<Map<String, String>>)>> getPost(
      String board, int index) async {
    //
    return pttFunctions.getPost(session, board, index);
  }
}
