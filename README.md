<h1 align="center">LibPttea-dart</h1>

<div align="center">

The [LibPttea](https://github.com/bubble-tea-project/libpttea) library implemented in Dart.


[![Pub Version](https://img.shields.io/pub/v/libpttea)](https://pub.dev/packages/libpttea)
[![GitHub License](https://img.shields.io/github/license/bubble-tea-project/libpttea-dart)](https://github.com/bubble-tea-project/libpttea-dart/blob/main/LICENSE)

</div>

## 📖 Description
LibPttea-dart 是 [LibPttea](https://github.com/bubble-tea-project/libpttea) 的 Dart 版本，目的在封裝各種 PTT 功能操作，旨在輔助開發 [PTTea](https://github.com/bubble-tea-project/PTTea) APP 專案的 PTT 功能函式庫。


## 📦 Installation
LibPttea is available on [Pub](https://pub.dev/packages/libpttea):
```bash
pub add libpttea
```


## 🎨 Usage
```dart
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

```


## 🔗 Links
- [LibPttea Python Version](https://github.com/bubble-tea-project/libpttea)
- [LibPttea Documentation (Python)](https://bubble-tea-project.github.io/libpttea/)


## 📜 License
[![GitHub License](https://img.shields.io/github/license/bubble-tea-project/libpttea-dart)](https://github.com/bubble-tea-project/libpttea-dart/blob/main/LICENSE)