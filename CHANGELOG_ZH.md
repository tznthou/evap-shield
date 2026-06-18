# 更新日誌

[English](CHANGELOG.md)

本檔記錄 evap-shield 所有值得注意的變更。

格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。本專案以日期分組，而非語意化版本——這是腳本工具集，不走 package registry 發布。

## [Unreleased]

### Changed

- README（中英）：補上 version-agnostic patcher 的說明——1-byte 結構式 patch（先前誤寫為 2-byte 字面）、45 個 patcher 測試，以及 2.1.181 的 Bun 1.4 註記。

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
