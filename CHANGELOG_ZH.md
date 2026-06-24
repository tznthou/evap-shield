# 更新日誌

[English](CHANGELOG.md)

本檔記錄 evap-shield 所有值得注意的變更。

格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。本專案以日期分組，而非語意化版本——這是腳本工具集，不走 package registry 發布。

## 2026-06-24

### Changed

- tested badge 更新到 **2.1.187**。Claude Code 從 2.1.186 → 2.1.187（又是連續版號——繼 2.1.185→2.1.186 後第二次背靠背連號）。兩路 binary diff 確認官方仍未修 VH1：parser site 前後 ±260 bytes 的窗口與 2.1.186 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，變數名沒洗牌，連 normalize 都不必就一字不差——結構錨點掃整個 binary 也只有 1 個 vulnerable site（bug 1／fix 0）。但與 +858 KB 的 2.1.186 大 build 相反，2.1.187 反而*縮小*：原廠 size 從 216811232 → 215994048（**−817,184 bytes**），site 仍漂移 193217884 → 193618676（**+400,792**），證明是貨真價實的新 build 而非省去重編譯的複製。strings diff 顯示 2.1.187 是實質 build（非凍結冷飯），但新增 39／移除 26 條人類可讀訊息全落在別處：`/toggle-memory` 改名為 `/pause-memory`、Fable 5 計費文案常態化（拿掉「for a limited time」／「Included in your plan limits」）、sandbox／credential 保護欄位、GitHub Actions 設定、MCP idle timeout——無一碰 JSON parser。這是 2.1.181 以來官方第 **4** 個有效改版（繼 2.1.183、2.1.185、2.1.186 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `a59a16ba…` → patched `df0eb868…`），並在磁碟（bug 0／fix 1）、簽章、以及 running session mmap 的 patched binary 三處驗證。
- 發表前對外文件對齊。修掉兩份 README 裡 clone URL 的 `{owner}` placeholder（→ `tznthou`，原本會讓使用者複製即失敗）。更新 #62123 數據（54 → 57 留言；依 issue 留言者 association 重新查證，57 則全為非官方帳號，截至 2026-06-24 仍零官方回覆）。investigation §7 版本判決鏈補到 2.1.185–187，並納入外部 #70196 真實活例（takepan，2.1.186，後被官方標 `duplicate`／`area:model`）。FIX-PLAN.md 標為凍結於 2026-06-16 的決策史快照，當前論述導向 investigation。並修正兩份 README 的 check-update 測試數（18 → 21）。

## 2026-06-23

### Changed

- tested badge 更新到 **2.1.186**。Claude Code 從 2.1.185 → 2.1.186（這次連續版號，沒跳號，不像 2.1.182／2.1.184）。兩路 binary diff 確認官方仍未修 VH1：parser site 前後約 280 bytes 的窗口與 2.1.185 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，變數名沒洗牌——結構錨點掃整個 binary 也只有 1 個 vulnerable site。但不同於 2.1.183→2.1.185 那種 size 凍結的改版，2.1.186 是*實質*大 build：原廠 size 從 215952608 → 216811232（**+858,624 bytes**），site 大幅漂移 192250818 → 193217884（**+967,066**）。strings diff 顯示這次成長來自 sandbox／egress agent-proxy／managed-agents（subagent）／MCP resource tools／plugin governance——無一碰 JSON parser。這是 2.1.181 以來官方第 **3** 個有效改版（繼 2.1.183、2.1.185 後）仍未修 VH1，也是迄今最強的訊號：官方塞了約 858 KB 的實質新 code，卻依然沒碰 parser。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `463a79cc…` → patched `8b277719…`），並在磁碟（bug 0／fix 1）與啟動（2.1.186）驗證。

## 2026-06-22

### Changed

- tested badge 更新到 **2.1.185**。Claude Code 從 2.1.183 → 2.1.185 後（2.1.184 跳號，如同先前的 2.1.182），兩路 binary diff 確認官方仍未修 VH1：parser site 與 2.1.183 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，變數名沒洗牌（沿用 Bun 1.4）——但在檔案裡漂移了 64 bytes（192250754 → 192250818），證明這是貨真價實的新 build（parser site 凍結不動，而非省去重編譯的複製）。原廠 size 不變（215952608），2.1.185 新增的字串全屬 sandbox／agent-proxy／cloud-sessions／oauth／MCP 治理，無一碰 JSON parser。這是 2.1.181 以來官方第 **2** 個有效改版（繼 2.1.183 後）仍未修 VH1。version-agnostic patcher 零腳本改動直接重套（`!l`→`!0`，1 byte；原廠 `a280c23b…` → patched `69862459…`），並在磁碟、記錄 state、以及 running session mmap 的 binary 三處重新驗證。

## 2026-06-20

### Changed

- `docs/vh1-investigation.md`：標注 MCP tool 的 hook 覆蓋依賴 validation *時序*、只在 2.1.179 驗過——不像 parser site 有 re-check 到 181/183；並補上這個 re-check 現已由 `SessionStart` hook 自動化（只 stat 的 fingerprint fast path 當閘門，變了才跑 anchored scan）。

## 2026-06-19

### Added

- **SessionStart 更新偵測 hook**（`check-update.sh`）：每次 session start 對 binary 做指紋比對（只 stat 的 fast path，沒變化時靜默），當 Claude Code 更新了——更新會覆蓋 binary patch——就回報 VH1 patch 是否需要重套（`vulnerable` → 重跑 patcher；`unknown` → 可能官方修了，請確認；`patched`／無變化 → 安靜）。只偵測與回報：絕不 patch、也不改任何檔案。獨立單檔、fail-open，附 `test-check-update.sh` 測試（21 tests）。

### Changed

- `install.sh` 現在會安裝兩個 hook（PreToolUse + SessionStart），用同樣冪等、非破壞的 settings 合併；installer 測試套件擴充到 26 tests。
- tested badge 更新到 **2.1.183**。Claude Code 從 2.1.181 → 2.1.183 後（2.1.182 跳號），三路 binary diff 確認官方 parser 在 identifier normalize 後與 2.1.181 逐字相同——這次 minifier 連變數名都沒洗牌（仍是 `l/n/a`）——VH1 官方仍未修。2.1.183 的 16 條 changelog 無一碰 tool-call 解析。version-agnostic patcher 零腳本改動直接重套（`!l`→`!0`，1 byte）。

## 2026-06-18

### Added

- VH1 bug 調查文（`docs/vh1-investigation.md`），含 2.1.181 re-check，確認此 bug 官方仍未修。

### Changed

- VH1 patcher 改為 **version-agnostic**：以錨定 parser 不變量的結構錨點，取代寫死的 minified 變數 pattern，因此能在跨版本的 bundler/minifier 洗牌後存活——已在 2.1.181 的 Bun 1.4 變數改名驗證。
- README（中英）：補上 version-agnostic patcher 的說明——1-byte 結構式 patch（先前誤寫為 2-byte 字面）、45 個 patcher 測試，以及 2.1.181 的 Bun 1.4 註記。

## 2026-06-17

### Added

- patcher failure-path 回歸測試套件（`test-patch-vh1.sh`）與 installer 合併安全測試套件（`test-install.sh`）。

### Changed

- 在文件中重新定調 hook 的守備範圍：patch 是根治層，hook 補的是 Claude Code 內建 validation 沒守到的 MCP tool 缺口。

### Fixed

- hook 改為能優雅處理 malformed 輸入與缺少 `jq` 的情況（fail-open），不再 crash。
- 還原改用 `rename()` 原子替換，並強化 patch-state 處理。

### Security

- 還原前先驗證備份的 SHA-256，才替換 binary。

## 2026-06-16

### Added

- 首次發布：PreToolUse hook（`evap-shield.sh`）與 binary patch（`patch-vh1.sh`），修補 Claude Code VH1 streaming parser bug，附一鍵安裝器（`install.sh`）。

### Fixed

- 防止 patch 時 macOS brick：patch 後的 Mach-O 會 ad-hoc 重簽，並在隔離的臨時 inode 上做啟動檢查，因此 patch 永不覆寫正在執行的 binary inode（否則 AMFI 會在重啟時 SIGKILL）。
