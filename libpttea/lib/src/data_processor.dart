/// libpttea.data_processor
///
/// This module processes the pages created by the PTT function into the desired data.

import 'dart:core';
import 'package:ansiparser/ansiparser.dart' as ansiparser;
import './pattern.dart' as pattern;
import './utils.dart' ;
import 'package:ansiparser/src/structures.dart';

List<String> getSystemInfo(List<String> systemInfoPage) {
  // Extracts system information from system_info page.
  return systemInfoPage.sublist(2, 9);
}

Map<String, String?> _processFavoriteLine(String line) {
  var item = <String, String?>{};

  const separator = "------------------------------------------";
  if (line.contains(separator)) {
    final match = RegExp(r"(?<index>\d+)").firstMatch(line);
    if (match != null) {
      item['index'] = match.namedGroup('index') ?? '';
      item['board'] = "------------";
    }
  } else {
    final match = pattern.regexFavoriteItem.firstMatch(line) ??
        pattern.regexFavoriteItemDescribe.firstMatch(line);
    if (match != null) {
      item.addAll(match.namedGroupToMap());
    }
  }
  return item;
}

List<Map<String, String?>> getFavoriteList(List<List<String>> favoritePages) {
  // Extract and merge the favorite list from favorite list pages.
  var favoriteList = <Map<String, String?>>[];

  for (var page in favoritePages) {
    final content = page.sublist(3, 23);
    for (var line in content) {
      final item = _processFavoriteLine(line);
      if (item.isNotEmpty) favoriteList.add(item);
    }
  }
  return favoriteList;
}

Map<String, String?>? processBoardLine(String line) {
  final match = pattern.regexPostItem.firstMatch(line);
  return match?.namedGroupToMap();
}

int getLatestPostIndex(List<String> boardPage) {
  // Extract the latest post index from the board page.
  final content = boardPage.sublist(3, 23);

  for (var line in content.reversed) {
    final item = processBoardLine(line);
    if (item == null) throw Exception("RuntimeError");

    final match = RegExp(r"\d+").firstMatch(item['index']!);
    if (match != null) {
      return int.parse(item['index']!);
    }
  }
  throw Exception("RuntimeError");
}

List<Map<String, String?>> getPostListByRange(List<List<String>> boardPages, int start, int stop) {
  // Extract the post list from the board pages by range.
  var postList = <Map<String, String?>>[];

  for (var page in boardPages) {
    final content = page.sublist(3, 23);

    for (var line in content.reversed) {
      final lineItems = processBoardLine(line);
      if (lineItems == null) throw Exception("RuntimeError");

      if (!RegExp(r"\d+").hasMatch(lineItems["index"]!)) continue;

      if (int.parse(lineItems["index"]!) < start) break;
      if (int.parse(lineItems["index"]!) <= stop) postList.add(lineItems);
    }
  }
  return postList;
}

(int, int) _getDisplaySpan(String statusBar) {
  // Return the index of the start and end of the display line by tuple.
  final match = pattern.regexPostStatusBar.firstMatch(statusBar);
  if (match != null) {
    final startIndex = int.parse(match.namedGroup("start")!);
    final endIndex = int.parse(match.namedGroup("end")!);
    return (startIndex, endIndex);
  } else {
    throw Exception("Failed to extract display span from status bar");
  }
}

int getDifferentIndex(List<String> page, List<String> lastPage) {
  // Get the index where the current page starts to differ compared to the last page.
  final (display_start, display_end) = _getDisplaySpan(page.last);
  final (display_start_previous, display_end_previous) = _getDisplaySpan(lastPage.last);

  int differentIndex;
  if (display_start == display_end_previous) {
    differentIndex = 1;
  } else if (display_start < display_end_previous) {
    differentIndex = display_end_previous - display_start + 1;
  } else {
    differentIndex = -1;
  }

  if (lastPage[lastPage.length - 2] == page[differentIndex]) {
    differentIndex += 1;
  }

  return differentIndex;
}

(List<String>, List<Map<String, String?>>) getPostPage(List<InterConverted> rawPostPage) {
  // Extract the post data from the raw post page, returning `Tuple(post_content_html, post_replies)`.
  var postReplies = <Map<String, String?>>[];
  List<String> postContentHtml = [];

  var foundReply = false;
  var postContentEndIndex = -1;

  var postPageContent = ansiparser.fromScreen(rawPostPage).toFormattedString();
  postPageContent = postPageContent.sublist(0,postPageContent.length-1);

  for (var index = 0; index < postPageContent.length; index++) {
    final line = postPageContent[index];
    final match = pattern.regexPostReply.firstMatch(line);
    if (match != null) {
      postReplies.add(match.namedGroupToMap());
      foundReply = true;
      continue;
    }

    if (!foundReply) {
      postContentEndIndex = index;
      continue;
    }

    if (foundReply) {
      postReplies.add({'type': 'author', 'reply': line});
      continue;
    }
  }

  if (postContentEndIndex != -1) {
    final rawPostContent = rawPostPage.sublist(0, postContentEndIndex + 1);
    postContentHtml = ansiparser.fromScreen(rawPostContent).toHtml();
  }

  return (postContentHtml, postReplies);
}
