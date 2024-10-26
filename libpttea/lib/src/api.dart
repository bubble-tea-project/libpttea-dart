import 'dart:async';
import './ptt_functions.dart' as pttFunctions;
import 'sessions.dart';

/// This module implements the libpttea API.
class API {
  Session? session;

  Future<API> login(String account, String password, {bool delDuplicate = true, bool delErrorLog = true}) async {
    /// Log in to PTT.
    ///
    /// 登入 PTT
    session = await pttFunctions.login(session, account, password, delDuplicate, delErrorLog);
    return this;
  }

  Future<void> logout({bool force = false}) async {
    /// Log out from PTT.
    ///
    /// 登出 PTT
    await pttFunctions.logout(session, force: force);
  }

  Future<List<dynamic>> getSystemInfo() async {
    /// Get the PTT system info.
    ///
    /// 查看 PTT 系統資訊
    return await pttFunctions.getSystemInfo(session);
  }

  Future<List<dynamic>> getFavoriteList() async {
    /// Get the favorite list.
    ///
    /// 取得 "我的最愛" 清單
    return await pttFunctions.getFavoriteList(session);
  }

  Future<int> getLatestPostIndex(String board) async {
    /// Get the latest post index.
    ///
    /// 取得最新的文章編號
    return await pttFunctions.getLatestPostIndex(session, board);
  }

  Future<List<dynamic>> getPostList(String board, int start, int stop) async {
    /// Get the post list by range; the `start` < `stop` is required.
    ///
    /// 取得範圍內的文章列表
    return await pttFunctions.getPostListByRange(session, board, start, stop);
  }

  Future<Stream<(List<String>, List<Map<String, String?>>)>> getPost(String board, int index) async {
    /// Get the post, return an Asynchronous Generator that
    /// yields post data as a `tuple(content_html, post_replies)`.
    ///Stream<(List<String>, List<Map<String, String?>>)>
    /// 取得文章資料
    return pttFunctions.getPost(session, board, index);
  }
}

Future<API> login(String account, String password, {bool delDuplicate = true, bool delErrorLog = true}) async {
  /// Log in to PTT.
  ///
  /// 登入 PTT
  final api = API();
  return await api.login(account, password, delDuplicate: delDuplicate, delErrorLog: delErrorLog);
}
