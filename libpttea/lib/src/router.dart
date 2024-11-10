/// libpttea.router
/// ----------
///
/// This module provides a URL-based API for navigating between different PTT screens.
library;

import 'dart:async';
import 'dart:math';

import './navigator.dart' as navigator;
import './pattern.dart' as pattern;
import './sessions.dart';

class Router {
  final Session _session;
  String _location = "";

  Router(this._session);

  /// Split the path into individual parts.
  List<String> _pathParts(String path) {
    return path
        .replaceAll(RegExp(r'/$'), '')
        .replaceAll(RegExp(r'^/'), '')
        .split('/');
  }

  /// Get the level of the path, starting from 0.
  int _pathLevel(String path) {
    // Remove trailing slashes
    path = path.replaceAll(RegExp(r'/$'), '');

    // count '/'
    return "/".allMatches(path).length;
  }

  /// Get the current location from the path.
  String _pathCurrent(String path) {
    if (path == "/") return "/";

    final parts = _pathParts(path);

    return parts.last;
  }

  /// Get the level at which two paths are the same until they diverge.
  int _pathSameUntil(String current, String go) {
    final currentParts = _pathParts(current);
    final goParts = _pathParts(go);

    // Find the shorter
    final minLength = min(currentParts.length, goParts.length);

    for (var index = 0; index < minLength; index++) {
      if (currentParts[index] != goParts[index]) return index;
    }

    // If one path is a subset of the other
    return minLength;
  }

  /// Calculate required steps to navigate from the current path to the target path.
  (List<String>, List<String>) _pathNeedMove(String current, String go) {
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
    // shallow copy , but string is immutable
    var remainNeeds = [...needs];

    for (final currentLocation in needs.reversed) {
      //
      switch (currentLocation) {
        case "favorite":
          await navigator.Favorite(_session).back();

        case "utility":
          await navigator.Utility(_session).back();

        case "info":
          await navigator.UtilityInfo(_session).back();

        default:
          // when at Board
          if (pattern.regexPathAtBoard.hasMatch(location())) {
            await navigator.Board(_session).back();
          }
          // when at Post index
          else if (pattern.regexPathAtPostIndex.hasMatch(location())) {
            await navigator.Post(_session).back();
          } else {
            throw UnimplementedError(
                "Not supported yet, back from = $currentLocation.");
          }
      }
      remainNeeds.removeLast();
      _location = "/${remainNeeds.join("/")}";
    }
  }

  Future<void> _go(List<String> needs) async {
    for (final nextLocation in needs) {
      //
      switch (_pathCurrent(location())) {
        case "/":
          await navigator.Home(_session).go(nextLocation);

        case "favorite":
          await navigator.Favorite(_session).go(nextLocation);

        case "utility":
          await navigator.Utility(_session).go(nextLocation);

        default:
          // when at Board
          if (pattern.regexPathAtBoard.hasMatch(location())) {
            await navigator.Board(_session).go(int.parse(nextLocation));
          } else {
            throw UnimplementedError(
                "Not supported yet, from = ${location()}, go = $nextLocation.");
          }
      }

      if (location() == "/") {
        _location += nextLocation;
      } else {
        _location += "/$nextLocation";
      }
    }
  }

  /// Check if the current screen is the home menu.
  bool inHome() {
    return navigator.inHome(_session);
  }

  /// Initialize the path for the home menu.
  void initHome() {
    _location = "/";
  }

  /// Get the current location path.
  String location() {
    if (_location.isEmpty) {
      throw Exception("Home menu path is not initialized yet");
    } else {
      return _location;
    }
  }

  /// Navigate to a URL location.
  Future<void> go(String location) async {
    if (this.location() == location) {
      throw Exception("Already at the location");
    }

    var (needBack, needGo) = _pathNeedMove(this.location(), location);

    await _back(needBack);
    await _go(needGo);
  }
}
