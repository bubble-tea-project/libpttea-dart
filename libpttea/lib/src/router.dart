/// libpttea.router
///
/// This module provides a URL-based API for navigating between different PTT screens.

import 'dart:async';
import 'dart:core';
import './navigator.dart' as navigator;
import './pattern.dart' as pattern;
import './sessions.dart';

class Router {
  final Session _session;
  String _location = "";

  Router(this._session);

  List<String> _pathParts(String path) {
    // Split the path into individual parts.
    return path.replaceAll(RegExp(r'/$'), '').replaceAll(RegExp(r'^/'), '').split('/');
  }

  int _pathLevel(String path) {
    // Get the level of the path, starting from 0.
    return path.replaceAll(RegExp(r'/$'), '').split('/').length - 1;
  }

  String _pathCurrent(String path) {
    // Get the current location from the path.
    if (path == "/") return "/";
    final parts = _pathParts(path);
    return parts.last;
  }

  int _pathSameUntil(String current, String go) {
    // Get the level at which two paths are the same until they diverge.
    final currentParts = _pathParts(current);
    final goParts = _pathParts(go);

    final minLength = currentParts.length < goParts.length ? currentParts.length : goParts.length;
    for (var index = 0; index < minLength; index++) {
      if (currentParts[index] != goParts[index]) return index;
    }
    return minLength;
  }

  (List<String>, List<String>) _pathNeedMove(String current, String go) {
    // Calculate required steps to navigate from the current path to the target path.
    final currentLevel = _pathLevel(current);
    final currentParts = _pathParts(current);
    final goLevel = _pathLevel(go);
    final goParts = _pathParts(go);

    final sameUntil = _pathSameUntil(current, go);
    final needBack = currentParts.sublist(sameUntil, currentLevel);
    final needGo = goParts.sublist(sameUntil, goLevel);

    return (needBack, needGo);
  }

  Future<void> _back(List<String> needs) async {
    //shallow copy , but string is immutable
    var remain_needs = [...needs];

    for (final currentLocation in needs.reversed) {
      switch (currentLocation) {
        case "favorite":
          await navigator.Favorite(_session).back();
          break;
        case "utility":
          await navigator.Utility(_session).back();
          break;
        case "info":
          await navigator.UtilityInfo(_session).back();
          break;
        default:
          if (pattern.regexPathAtBoard.hasMatch(location())) {
            await navigator.Board(_session).back();
          } else if (pattern.regexPathAtPostIndex.hasMatch(location())) {
            await navigator.Post(_session).back();
          } else {
            throw UnimplementedError("Not supported yet, back from = $currentLocation.");
          }
      }
      remain_needs.removeLast();
      _location = "/" + remain_needs.join("/");
    }
  }

  Future<void> _go(List<String> needs) async {
    for (final nextLocation in needs) {
      switch (_pathCurrent(location())) {
        case "/":
          await navigator.Home(_session).go(nextLocation);
          break;
        case "favorite":
          await navigator.Favorite(_session).go(nextLocation);
          break;
        case "utility":
          await navigator.Utility(_session).go(nextLocation);
          break;
        default:
          if (pattern.regexPathAtBoard.hasMatch(location())) {
            await navigator.Board(_session).go(int.parse(nextLocation));
          } else {
            throw UnimplementedError("Not supported yet, from = ${location()}, go = $nextLocation.");
          }
      }

      if (location() == "/") {
        _location += nextLocation;
      } else {
        _location += "/$nextLocation";
      }
    }
  }

  bool inHome() {
    // Check if the current screen is the home menu.
    return navigator.inHome(_session);
  }

  void initHome() {
    // Initialize the path for the home menu.
    _location = "/";
  }

  String location() {
    // Get the current location path.
    if (_location.isEmpty) throw Exception("Home menu path is not initialized yet");
    return _location;
  }

  Future<void> go(String location) async {
    // Navigate to a URL location.
    if (this.location() == location) throw Exception("Already at the location");

    var (need_back, need_go) = _pathNeedMove(this.location(), location);
    await _back(need_back);
    await _go(need_go);
  }
}
