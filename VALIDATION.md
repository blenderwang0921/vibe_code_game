# 驗證紀錄

2026-10-09，macOS 14.5 / arm64，Godot 4.7.2 stable 標準版，Compatibility renderer。

## 已完成

- 官方 macOS 下載包 170,622,178 bytes；SHA256 與 GitHub 官方 release metadata 一致：`c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e`。解壓後已刪除 ZIP。
- 專案匯入與 67 項邏輯／場景測試全部通過；最新結果在 `artifacts/tests.log`。驗證腳本會檢查錯誤和警告，並檢查所有測試腳本的語法。
- 已開啟真實 1280×720 視窗，檢視村莊、森林戰鬥、暫停、死亡、獎勵與強化後畫面。
- 輸入驅動試玩使用普通遊戲數值，以 E 接任務、右鍵移動、Q/W 戰鬥，完成 5 隻擊殺，回村按 E，按 2 選冰霜強化，再走回森林。沒有瞬移、直接扣敵人血量或略過冷卻。紀錄在 `artifacts/playthrough.json`，該次流程完成於 44.1 秒，包含 22 次火球與 5 次冰霜施放。
- 邏輯整合測試另覆蓋火球強化的實際傷害、冰霜強化後的擴大命中範圍、暫停、死亡重試及一次性獎勵。

測試找出並修正了導航資料尚未同步就查詢、導航表面與地面高度差、重新載入後存取舊 HUD，以及合成滑鼠事件與 OS 游標讀值不同步的問題。畫面檢查後修正了光照過曝、UI 血條高度、小徑面向與 3D 中文標籤的可讀性。

## 效能

引擎實際回報 **Apple M3**，不是計畫指定的 M2。

| 項目 | 結果 |
| --- | --- |
| 解析度／渲染 | 1280×720／gl_compatibility |
| 同場怪物 | 全程至少 10 隻 |
| 暖機／取樣 | 4 秒／30.005 秒 |
| 平均 FPS | 126.34 |
| 平均影格時間 | 7.91 ms |
| P95／P99 影格時間 | 10.21／11.46 ms |
| 陰影 | 開啟 |

測試包含移動、追擊、近戰和法術，使用真實經過時間，未使用固定 FPS 模擬。測試器提高生命值以防途中死亡；遊戲本體保持正常數值。原始數據為 `artifacts/benchmark.json`。目前結果有超過 60 FPS 的餘裕，因此沒有為達標而關閉陰影。

## 容量與待驗證項目

引擎本體約 337 MiB；加上專案、截圖及 Godot 快取，合計343.14 MiB，低於 1 GB。可用 `python3 tools/storage_report.py` 重新量測；本次完整明細在 `artifacts/storage.json`。

- **M2 的 60 FPS 目標尚未實測**；可在 M2 執行 `./benchmark.sh`，必要時用 `./benchmark.sh --low` 比較降低陰影與特效的結果。
- 已完成可見視窗的自動化操作與截圖檢視，但**真人戰鬥手感與初次遊玩 3–5 分鐘的時長仍未驗證**。自動控制器比初次玩家快，44.1 秒不代表真人遊玩時長。
- 目前沒有音效、存檔或獨立 App 打包。啟動方式與其他限制詳見 README。

## 畫面證據

- `artifacts/village.png`：村莊與任務 HUD。
- `artifacts/forest.png`：森林、火球與冰霜。
- `artifacts/playthrough-combat.png`：真實輸入事件下的戰鬥與擊殺進度。
- `artifacts/reward.png`：回報後的二選一獎勵。
- `artifacts/upgraded.png`：取得冰霜強化後回到森林。
- `artifacts/pause.png`、`artifacts/playthrough-death.png`：暫停與死亡畫面。

較早的村莊／森林截圖拍攝於小徑面向修正前；`playthrough-combat.png`、`reward.png`、`upgraded.png` 是修正後的畫面。所有 artifacts 為本機證據，已排除於版本控制。
