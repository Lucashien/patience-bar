---
類型: 測試（emulator，node）
檔案: Tests/FirestoreRules/security.test.cjs
數量: 37
最後結果: 2026-11-01 全過（電腦上 emulator）
---
# Firestore 規則測試

測 `firestore.rules`。目前 `Tests/` 未納入版控（見 [[待辦]]）。`firebase.json` 在專案根目錄。

## 涵蓋範圍

| 群組 | 驗證什麼 | 對應功能 |
| --- | --- | --- |
| 建立配對 | 未登入不能建、不能預先加入別人 | [[配對與同步]] |
| 讀取與列出 | 非成員讀不到、不能 list couples | [[配對與同步]] |
| 加入 | 只能把自己加成第二人、第三人擋掉、不能改邀請碼 | [[配對與同步]] |
| 成員保護 | 不能換人／踢人／刪配對 | [[配對與同步]] |
| 使用者文件 | 只能寫自己的條與名字，不能改對方的 | [[耐心條]] |
| 事件 | 交易內更新自己的條並記事件 | [[耐心條]] |

## 缺口

- 沒有 `avatar` 欄位的案例（[[大頭貼]]）。
- 驗的是規則本身；規則**尚未發布**到 Console，雲端行為未驗證。

## 怎麼跑

在 `Tests/FirestoreRules/` 用 Firebase emulator（port 8187）執行 `security.test.cjs`。
