# 更新日誌

[English](CHANGELOG.md)

本檔記錄 evap-shield 所有值得注意的變更。

格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。本專案以日期分組，而非語意化版本——這是腳本工具集，不走 package registry 發布。

## [Unreleased]

### Changed

- README（中英）：補上 version-agnostic patcher 的說明——1-byte 結構式 patch（先前誤寫為 2-byte 字面）、45 個 patcher 測試，以及 2.1.181 的 Bun 1.4 註記。

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
