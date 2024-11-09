/// libpttea.pattern
/// ----------
///
/// This module implements commonly used patterns for libpttea.
library;

/// Keyboard
// ---
const String newLine = '\r\n';

// ANSI escape codes for terminal input sequences
const String upArrow = '\x1b[A';
const String downArrow = '\x1b[B';
const String leftArrow = '\x1b[D';
const String rightArrow = '\x1b[C';

const String home = '\x1b[1~';
const String end = '\x1b[4~';
const String pageUp = '\x1b[5~';
const String pageDown = '\x1b[6~';

/// Regular expressions
// ---
final regexPathAtBoard = RegExp(r'^/favorite/\w+$');

final regexPathAtPostIndex = RegExp(r'^/favorite/\w+/\d+');

//
final regexIncompleteAnsiEscape = RegExp(r'.+\x1b(?:\[[^\x40-\x7E]*)?$');

//
final regexMenuStatusBar =
    RegExp(r'\[\d+\/\d+\s\S+\s\d+:\d+\].+人,.+\[呼叫器\](?:打開|拔掉|防水|好友)');

final regexBoardStatusBar = RegExp(r'文章選讀.+進板畫面');

final regexPostStatusBarSimple = RegExp(r'瀏覽.+目前顯示.+說明.+離開');

final regexPostStatusBar = RegExp(
    r'瀏覽.+\(\s{0,2}(?<progress>\d+)%\).+第\s(?<start>\d+)~(?<end>\d+)\s行.+離開');

// favorite_item normal
final regexFavoriteItem = RegExp(
    r'(?<index>\d+)\s+ˇ?(?<board>\S+)\s+(?<type>\S+)\s+◎(?<describe>.*\S+)\s{2,}(?<popularity>爆!|HOT|\d{1,2})?\s*(?<moderator>\w+.+)');

// favorite_item but no popularity and moderator
final regexFavoriteItemDescribe = RegExp(
    r'(?<index>\d+)\s+ˇ?(?<board>\S+)\s+(?<type>\S+)\s+◎(?<describe>.*\S+)');

// cursor has moved in favorite list
final regexFavoriteCursorMoved = RegExp(r'>\s+(?!1\s)\d+\s{3}');

// cursor not moved in favorite list
final regexFavoriteCursorNotMoved = RegExp(r'>\s{5}1\s{3}');

//
final regexPostItem = RegExp(
    r'(?<index>\d+|★)\s+(?<label>\D)?(?<count>爆|[\s\d]{2}|XX|X\d)?\s{0,1}(?<date>\d{1,2}/\d{1,2})\s(?<author>\S+)\s+(?<title>.+)');

final regexPostReply = RegExp(
    r'(?<type>[推→噓])\s(?<author>\w+):\s(?<reply>.+)\s(?<ip>(?:\d{1,3}\.?){4})?\s(?<datetime>\d{1,2}\/\d{1,2}\s\d{2}:\d{2})');

// The post has no content; it has already been deleted.
final regexPostNoContent = RegExp(r'此文章無內容.+按任意鍵繼續');
