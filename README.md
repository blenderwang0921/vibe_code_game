# 暮光林地｜小巫師的第一課

Godot 4 標準版、GDScript、Compatibility renderer 的單機 3D 小型 RPG。用幾何模型組成巫師、村莊、森林和苔背獸；不需素材包、.NET、Blender 或 export templates。預期第一次遊玩約 3–5 分鐘，完成委託後仍可繼續戰鬥。

## 開始遊戲

本機已下載 Godot **4.7.2 stable**，放在 `.tools/Godot.app`。在專案目錄執行：

```sh
./run.sh
```

也可以用 Godot 開啟 `project.godot`，按 **F5**。啟動編輯器：

```sh
./tools/godot.sh --editor
```

其他電腦複製專案時不需帶 `.tools` 和 `.godot`。macOS 或 Linux x86_64 可重新取得相同版本（需要 Python 3.10+、網路連線）：

```sh
python3 tools/install_godot.py
./run.sh
```

下載器會自動選擇 macOS universal 或 Linux x86_64（64 位元 x86，非 32 位元）官方標準版，顯示檔案大小、核對 SHA256、確認解壓容量並刪除下載暫存。macOS 安裝在 `.tools/Godot.app`，Linux 在 `.tools/godot`，啟動器會自動選用。其他平台請自行安裝 Godot 4 標準版；可用 `GODOT_BIN=/完整路徑/godot ./run.sh` 指定引擎。已驗證的版本是 4.7.2。

Linux 無桌面環境可執行 `./verify.sh` 做 headless 驗證；遊戲視窗與截圖仍需要圖形環境和 OpenGL 驅動。繁體中文需安裝 Noto Sans CJK TC 等字型。安裝器不會安裝系統套件，Linux 執行檔也仍需系統提供相容的函式庫。

## Blender（選用）

目前遊戲不需要 Blender；製作模型時可安裝固定版本 **Blender 4.5.3 LTS**：

```sh
python3 tools/install_blender.py
./tools/blender.sh --background --version
./tools/blender.sh --background --python-exit-code 1 --python tests/blender_smoke.py
# 之後執行自己的建模腳本：
# ./tools/blender.sh --background --python path/to/build_models.py
```

`blender_smoke.py` 會建立測試模型、匯出 GLB 並使用 Cycles CPU 渲染 256×256 PNG，成果在 `artifacts/blender-smoke/`。已在 macOS Apple Silicon 實測 Blender 4.5.3 安裝與此背景流程；Linux 尚待實機驗證。

在目前這台 Mac 的 Codex 沙箱內，Blender 曾於啟動時的 Metal 裝置偵測崩潰，並觸發 macOS「未依預期結束」提示；即使背景模式與 CPU 渲染也會經過此初始化。相同測試在允許沙箱外執行後成功。透過 Codex 執行時應使用核准的沙箱外執行模式；一般終端機可直接使用上述指令，不需要修改系統安全設定。

支援 macOS Apple Silicon／Intel 與 Linux x86_64。Linux 安全解壓建議使用 Python 3.12+（需有 `tarfile.data_filter`）；macOS 使用系統的 `hdiutil` 與 `ditto`。只下載目前平台的官方發行包，依官方 `.sha256` 清單驗證，暫存下載與解壓完成後會清除。安裝前要求約 **3.6 GiB 可用空間**，這是容量預算，模型、貼圖和渲染成果另計。

程式保存在 `.tools/blender/`，不需管理員權限，也不會進入 Git。可用 `BLENDER_BIN=/完整路徑/blender ./tools/blender.sh --background --version` 指定既有安裝；找不到專案內程式時也會搜尋 PATH。已存在的安裝會檢查能否執行並保留，不會自動升級或覆寫。Linux 若提示缺少共享函式庫，須先在主機或 Cloud 環境補齊依賴；此腳本不配置 GPU 或虛擬顯示器。

發布到 GitHub 時只需提交安裝腳本；`.tools/`、`.godot/`、`artifacts/` 已列入 `.gitignore`。新的開發環境需重新執行安裝步驟。

## 操作與流程

| 操作 | 效果 |
| --- | --- |
| 滑鼠右鍵點地面 | 移動；導航網格會繞過樹木與石頭。點障礙或地圖外不會改變目的地。 |
| Q | 朝滑鼠地面位置發射火球；第一個敵人或障礙會攔下火球。 |
| W | 游標處範圍傷害與 3 秒減速；射程 10 公尺。超出射程不消耗冷卻。 |
| E | 靠近村民接下委託或回報。 |
| 1 / 2，或點選按鈕 | 回報時選擇火球傷害 +60%，或冰霜半徑 +55%。 |
| Esc | 暫停／繼續與操作說明；也可暫時關閉獎勵選單。 |
| R | 死亡畫面重新開始整段體驗。 |

1. 起點附近的護林人「榆木」會給你驅散 **5 隻苔背獸**的委託。接下後的擊殺才計算。
2. 沿小徑穿過淺綠色村莊結界，到森林用火球與冰霜戰鬥。施法不會取消移動。
3. 苔背獸腳下出現橙色圓環時，牠正準備攻擊。冰霜命中的敵人血條旁會有藍色標記。
4. 血量不足可以退回村莊，結界內不受傷並緩慢恢復生命。怪物會返回森林。
5. 完成後回村按 E，選擇一項永久生效於本次旅程的強化，再回森林試打。

初始森林有 10 隻怪物，死亡後 12 秒補充。獎勵只能領取一次。重新開始會清除任務、強化、冷卻和刷新佇列。

## 調整與結構

- `resources/balance.tres`：在 Godot Inspector 調整血量、傷害、冷卻、移速、射程、減速、怪物數量、刷新延遲和任務目標；預設值定義在 `scripts/balance.gd`。
- `scenes/`：世界、玩家、敵人、村民、火球、命中特效、HUD 的可重用文字場景。
- `scripts/world_builder.gd`：固定種子的幾何地圖、靜態碰撞、小徑和地標。
- `scripts/world.gd`：導航烘焙、滑鼠地面投影、施法、任務互動、刷新和固定角度跟隨鏡頭。
- `scripts/run_state.gd`、`health.gd`、`spell_book.gd`：可獨立驗證的任務、生命與冷卻規則。
- `tests/`：邏輯與整合測試、可見視窗截圖、壓力測試及輸入驅動的完整遊戲流程。
- `artifacts/`：本機驗證日誌、截圖與 JSON 報告；不納入版本控制。

幾何內容在執行時建立，世界啟動時從靜態碰撞烘焙導航網格。角色使用 `NavigationAgent3D` 尋路；碰撞層依序為地面、障礙、玩家、敵人。火球每個物理影格對整段位移查詢最近碰撞，避免高速穿透。

## 驗證

```sh
./verify.sh
python3 -m unittest discover -s tests -p 'test_installers.py'
./tools/godot.sh --script res://tests/visual_runner.gd
./tools/godot.sh --script res://tests/playthrough.gd
./benchmark.sh
./benchmark.sh --low
python3 tools/storage_report.py
```

`verify.sh` 會先匯入全部資源，執行 headless 測試，並把解析錯誤、執行錯誤或警告視為失敗。涵蓋冷卻、傷害、繞障礙、火球碰撞、冰霜範圍與減速、村莊邊界、任務計數、一次性獎勵、延遲刷新、暫停與死亡重試。使用固定模擬步進加快驗證，**這不是效能測試**。

`playthrough.gd` 則開啟真實視窗，以滑鼠和按鍵事件操作普通遊戲，使用原本的血量、傷害與冷卻；不瞬移角色、不直接扣敵人血量。這是自動化操作驗證，不能取代人對戰鬥手感的主觀試玩。

壓力測試會開啟 1280×720 的實際 Compatibility 視窗，暖機 4 秒，再用真實時間取樣 30 秒。10 隻怪物追擊、玩家移動並施法；只有測試用生命值提高，避免測試途中死亡或怪物數下降。結果在 `artifacts/benchmark.json`，降低特效時在 `benchmark-low.json`。

實測結果與限制見 [VALIDATION.md](VALIDATION.md)。

## 已知限制

- 這是一張小地圖的原型，無存檔、背包、裝備、完整技能樹、音樂與音效。離開或重試即重置。
- 尚未打包獨立 App；透過 Godot 執行。所有遊戲內容都可離線運作。
- 繁體中文使用系統字型，macOS 優先使用 PingFang TC；其他系統需有微軟正黑體或 Noto Sans CJK TC 等中文字型。
- 目前本機顯示卡被引擎識別為 **Apple M3**；沒有把此結果當作 M2 的效能保證。
- 建議 1280×720 或更大視窗。固定鏡頭不能旋轉；樹冠可能遮住部分角色，移動時可依地面位置和血條辨認。
- 自動化流程比初次遊玩快；3–5 分鐘是設計目標，尚未做真人遊玩時長與手感評估。

引擎來源為 [Godot 官方標準版 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)。所有遊戲幾何與 SVG 由本專案建立，未使用第三方遊戲素材。
