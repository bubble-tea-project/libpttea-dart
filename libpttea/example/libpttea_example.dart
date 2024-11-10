import 'package:libpttea/libpttea.dart' as libpttea;

const pttAccount = "PTT ID";
const pttPassword = "PTT 密碼";

Future<void> main() async {
  final libPttea =
      await libpttea.login(pttAccount, pttPassword, delDuplicate: true);

  final systemInfo = await libPttea.getSystemInfo();
  print(systemInfo);
  // [您現在位於 批踢踢實業坊 (140.112.172.11),
  // 系統負載: 輕輕鬆鬆,
  // 線上人數: 59384/175000,
  // ClientCode: 02000023,
  // 起始時間: 11/10/2024 05:17:51,
  // 編譯時間: Sun Jun  4 23:41:30 CST 2023,
  // 編譯版本: https://github.com/ptt/pttbbs.git 0447b25c 8595c8b4 M]

  await libPttea.logout();
}
