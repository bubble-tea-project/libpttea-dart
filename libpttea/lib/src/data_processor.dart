/// libpttea.data_processor
/// ----------
///
/// This module processes the pages created by the PTT function into the desired data.
library;

import 'package:ansiparser/ansiparser.dart' as ansiparser;
import 'package:ansiparser/src/structures.dart';

import './pattern.dart' as pattern;
import './utils.dart';

/// Extracts system information from system_info page.
List<String> getSystemInfo(List<String> systemInfoPage) {
  return systemInfoPage.sublist(2, 9);
}

Map<String, String> _processFavoriteLine(String line) {
  var favoriteItem = {
    'index': '',
    'board': '',
    'type': '',
    'describe': '',
    'popularity': '',
    'moderator': ''
  };

  // Check if the line is a separator line
  const separator = "------------------------------------------";
  if (line.contains(separator)) {
    final match = RegExp(r"(?<index>\d+)").firstMatch(line);
    if (match != null) {
      favoriteItem['index'] = match.namedGroup('index')!;
      favoriteItem['board'] = "------------";
    } else {
      throw Exception("Failed to process the favorite line");
    }
  } else {
    var match = pattern.regexFavoriteItem.firstMatch(line);

    // use regex that excludes popularity and moderator.
    match ??= pattern.regexFavoriteItemDescribe.firstMatch(line);

    if (match != null) {
      favoriteItem.addAll(match.groupMap(noMatch: ""));
    } else {
      throw Exception("Failed to process the favorite line");
    }
  }

  return favoriteItem;
}

/// Extract and merge the favorite list from favorite list pages.
List<Map<String, String>> getFavoriteList(List<List<String>> favoritePages) {
  var favoriteList = <Map<String, String>>[];

  for (final page in favoritePages) {
    final content = page.sublist(3, 23);

    for (final line in content) {
      // Skip empty lines
      if (line.isNotEmpty) {
        final favoriteItem = _processFavoriteLine(line);
        favoriteList.add(favoriteItem);
      }
    }
  }

  return favoriteList;
}

Map<String, String> processBoardLine(String line) {
  //
  final match = pattern.regexPostItem.firstMatch(line);
  if (match != null) {
    // extract all named groups
    return match.groupMap(noMatch: "");
  } else {
    throw Exception("Failed to process the board line");
  }
}

/// Extract the latest post index from the board page.
int getLatestPostIndex(List<String> boardPage) {
  final content = boardPage.sublist(3, 23);

  // Start from the latest (bottom)
  for (var line in content.reversed) {
    final item = processBoardLine(line);

    // Skip pinned posts and find the first index that is a digit
    final match = RegExp(r"\d+").firstMatch(item['index']!);
    if (match != null) {
      return int.parse(item['index']!);
    }
  }

  throw Exception("Failed to find the first index");
}

/// Extract the post list from the board pages by range.
List<Map<String, String>> getPostListByRange(
    List<List<String>> boardPages, int start, int stop) {
  var postList = <Map<String, String>>[];

  for (final page in boardPages) {
    final content = page.sublist(3, 23);

    for (var line in content.reversed) {
      final lineItems = processBoardLine(line);

      // skip pin post
      if (!RegExp(r"\d+").hasMatch(lineItems["index"]!)) {
        continue;
      }

      if (int.parse(lineItems["index"]!) < start) {
        break;
      }

      if (int.parse(lineItems["index"]!) <= stop) {
        postList.add(lineItems);
      }
    }
  }

  return postList;
}

/// Return the index of the start and end of the display line by tuple.
(int, int) _getDisplaySpan(String statusBar) {
  final match = pattern.regexPostStatusBar.firstMatch(statusBar);
  if (match != null) {
    final startIndex = int.parse(match.namedGroup("start")!);
    final endIndex = int.parse(match.namedGroup("end")!);

    return (startIndex, endIndex);
  } else {
    throw Exception("Failed to extract display span from status bar");
  }
}

/// Get the index where the current page starts to differ compared to the last page.
int getDifferentIndex(List<String> page, List<String> lastPage) {
  int differentIndex = -1;

  // status bar
  final (displayStart, displayEnd) = _getDisplaySpan(page.last);
  final (displayStartPrevious, displayEndPrevious) =
      _getDisplaySpan(lastPage.last);

  if (displayStart == displayEndPrevious) {
    // No overlap, starts from index 1
    differentIndex = 1;
  } else if (displayStart < displayEndPrevious) {
    // start_index = display_end_previous - display_start + 1
    differentIndex = displayEndPrevious - displayStart + 1;
  }

  // Caution!
  // Sometimes PTT will send an incorrect start line when the post is short; please refer to the documentation.
  final previousLine = lastPage[lastPage.length - 2];
  final line = page[differentIndex];
  if (previousLine == line) {
    // skip overlap
    differentIndex += 1;
  }

  return differentIndex;
}

/// Extract the post data from the raw post page, returning `Tuple(post_content_html, post_replies)`.
(List<String>, List<Map<String, String>>) getPostPage(
    List<InterConverted> rawPostPage) {
  // {'type': '噓', 'author': 'testest', 'reply': '笑死    ', 'ip': '000.000.00.00', 'datetime': '10/22 20:06'}
  var postReplies = <Map<String, String>>[];
  List<String> postContentHtml = [];

  var foundReply = false;
  var postContentEndIndex = -1;

  // Remove the status bar
  var postPageContent = ansiparser.fromScreen(rawPostPage).toFormattedString();
  postPageContent = postPageContent.sublist(0, postPageContent.length - 1);

  // Extract
  for (var index = 0; index < postPageContent.length; index++) {
    final line = postPageContent[index];

    // found reply
    final match = pattern.regexPostReply.firstMatch(line);
    if (match != null) {
      postReplies.add(match.groupMap());
      foundReply = true;
      continue;
    }

    // content only
    if (!foundReply) {
      postContentEndIndex = index;
      continue;
    }

    // content , but found replies on the same page.
    if (foundReply && line.isNotEmpty) {
      // If there are only a few replies, the page will include empty lines after the replies.

      // For the author's reply that edited the content.
      postReplies
          .add({'type': 'author', 'reply': line, 'ip': '', 'datetime': ''});
      continue;
    }
  }

  // Convert the post content to HTML
  if (postContentEndIndex != -1) {
    final rawPostContent = rawPostPage.sublist(0, postContentEndIndex + 1);
    postContentHtml = ansiparser.fromScreen(rawPostContent).toHtml();
  }

  return (postContentHtml, postReplies);
}
