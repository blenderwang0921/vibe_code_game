# 主角造型提案 / Wizard rig v1

已選定 **B「森芽旅人」** 作為遊戲主角，透過 `scenes/wizard_visual.tscn` 接入 `scenes/player.tscn`。A、C 保留為替代造型與裝備設計參考。球形頭部沒有五官、身體藏在長袍下、雙手是獨立浮空球。

主角保留模型 rest pose，尚未新增動畫，也不套用舊程序角色的腳步、搖擺或施法傾斜。移動／瞄準朝向與受傷閃光仍由既有 gameplay 流程控制；其他角色維持既有表現。`ActorVisual.model_scene` 是模型入口，裝備與骨架仍在 GLB 中獨立保留。

| 版本 | 造型方向 | 魔杖重點 | 完整角色三角面數 |
| --- | --- | --- | ---: |
| `a_astral` 星環學者 | 靛藍、黃銅、折彎尖帽 | 開口雙星環與懸浮晶核 | 1,708 |
| `b_grove` 森芽旅人 | 青綠、暖木色、寬袍擺與軟帽 | 金色嵌線木枝包覆種子晶核 | 1,416 |
| `c_lantern` 暮光司燈者 | 象牙白、深紫、挺直高帽 | 幾何燈籠框、長晶核與小墜飾 | 1,304 |

長袍與帽子以大色塊、窄邊及簡單輪廓建立等級感。魔杖使用較高的幾何預算，透過頂部輪廓、金屬框架和晶核形狀建立收藏差異。材質沒有外部貼圖依賴；晶核只有輕微 emission，不依賴 bloom 或粒子才能辨識。

## 來源與輸出

- 可重建來源：`tools/build_character_concepts.py`。使用 Blender Python API，沒有外部套件或 addon。
- 可編輯來源：`artifacts/characters/{a_astral,b_grove,c_lantern}.blend`。
- 全身比較：`artifacts/characters/comparison.png`；另有每套 1000×1100 的獨立肖像。
- 各版本目錄包含 `character.glb` 完整角色，以及 `body.glb`、`robe.glb`、`hat.glb`、`wand.glb` 模組。
- `.blend`、渲染及報告依 repository 規則保留在 ignored `artifacts/`；GLB 與生成程式可版本控制。`artifacts/.gdignore` 避免 Godot 匯入來源與證據。

重新生成會覆蓋上述輸出；若在 Blender 手動修改，先另存自己的工作副本。所有匯出均為原點、單位縮放、無展示用旋轉；並排展示用場景另存 `comparison.blend`。

```sh
./tools/blender.sh --background --python-exit-code 1 --python tools/build_character_concepts.py
./verify.sh
./tools/godot.sh --audio-driver Dummy --script res://tests/character_preview.gd
```

macOS 的 Blender 指令依根目錄 AGENTS.md 使用核准的沙箱外模式。實際驗證環境：Blender 4.5.3 LTS、Godot 4.7.2 Compatibility、Apple M3。

## 骨架契約

三套共用 `wizard_rig_v1` 的 18 根骨骼名稱、父子關係及 rest transforms。每個角色有六個網格：`Body_Head`、`Body_Hand_L`、`Body_Hand_R`、`Equip_Robe`、`Equip_Hat`、`Equip_Wand`。

```text
root
└─ pelvis
   ├─ spine
   │  └─ chest
   │     ├─ head
   │     │  └─ socket_hat
   │     ├─ hand.L
   │     └─ hand.R
   │        └─ socket_wand
   │           └─ fx_tip
   └─ hem.00 … hem.07
```

- `root`：整體移動／漂浮；原點在角色地面投影。
- `pelvis`、`spine`、`chest`：袍身彎曲與身體姿態。
- `head`：頭部與帽子一起轉動；`socket_hat` 保留帽子獨立動作。
- `hand.L`、`hand.R`：直接控制浮空手。`hand.R` 是持杖手；沒有不需要的手臂網格、手指或腿部骨骼。
- `socket_wand`：持杖手的子骨骼，可單獨調整握持角度。帽與杖網格都以 100% 權重綁定對應 socket 骨骼。
- `fx_tip`：目前共用的晶核效果錨點；將來魔杖高度改動時應以裝備資料提供效果位置偏移，不更改共用 rest pose。
- `hem.00` 至 `hem.07`：八方向袍擺骨骼。衣服上部依高度混合 pelvis / spine / chest；下擺依高度和方位角混合 pelvis 與相鄰 hem。每頂點最多三個 influence，權重總和為 1。

骨架是可變形的基礎骨架；未添加動畫 clip、IK、布料模擬或 animator control rig。後續動作應在這份契約上建立，並依實際動作調整局部權重。不要把所有 Godot bone pose rotation 直接覆蓋成 identity；姿勢測試以匯入時的初始旋轉乘上增量旋轉，保留袍擺骨骼軸向。

## 座標與裝備替換

Blender 使用公尺、Z 向上、角色朝 -Y；高度約 2.5–2.7 m（含帽）。glTF 轉換後朝 Godot +Z；本遊戲 actor 朝 -Z，因此在角色的 visual 容器加 Y 軸 180° 旋轉，勿改 gameplay 根節點。帽子與持杖 socket、兩手位置在三套中一致。

每個模組 GLB 都攜帶相同骨架契約，以便獨立檢查。正式組裝時只保留 **一個** Skeleton3D，把裝備 MeshInstance3D 綁到角色骨架；不要為每件裝備各播放一套骨架。glTF joint 順序不屬於契約，需以骨骼名稱重新對應 Skin binds。`tests/character_preview.gd` 的 `attach_equipment()` 示範並實際測試此作法。

各版本材質使用 `版本/cloth`、`light`、`dark`、`trim`、`gem`、`skin`、`wand_shaft` 語意命名。未來等級變色應修改材質／裝備資料；讓帽子與長袍保持樸素，把稀有裝備幾何變化集中在魔杖。

## 驗證與目前界線

生成器檢查每套六網格／18 骨骼、非零面積面、全部頂點權重正規化，並實際評估持杖手的骨架變形。結果在 `artifacts/characters/validation.json`。

Godot 真實視窗檢查三套匯入、所有網格的 skeleton 連結、B 袍＋C 帽＋A 杖跨版本混搭、頭／手／袍擺的測試姿勢，以及三套正常遊戲鏡頭和實景近照。測試姿勢不寫入動畫或來源資產。日誌是 `artifacts/characters/godot-preview.log`；圖片為 `godot_*.png`、`gameplay_*.png`、`game_closeup_*.png`。

正常遊戲鏡頭 size=26 下角色佔畫面較小：能讀出帽型、主色與魔杖大輪廓，細小墜飾、嵌線仍需裝備預覽近鏡欣賞。B 已接入正式主角；尚未加入正式換裝 UI、物品稀有度規則、施法動畫或專屬特效。
