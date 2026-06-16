# evap-shield

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4.0+-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-2.1.x-7C3AED.svg)](https://docs.anthropic.com/en/docs/claude-code)

[English](README.md)

Claude Code VH1 streaming parser bug 的防禦工具包。這個 bug 會讓 tool call 的參數靜默變成 `{}`。

---

## 這是什麼 Bug？

Claude Code 的 streaming JSON parser 裡有一個 string tokenizer（minified 後叫 `VH1`），當 JSON string 值剛好被 streaming chunk 切斷時，parser 會靜默丟掉整個 token。接下來三層 parser 連鎖反應，最終 `JSON.parse("{}")` 成功——之後同一 session 裡同一個 tool 的每次呼叫都會送出空參數。

你的 AI 能想，但做不了事。而且它不知道為什麼。

追蹤於 [#62123](https://github.com/anthropics/claude-code/issues/62123)（54+ 留言，截至 2026-06-16 零官方回覆）及 [#67765](https://github.com/anthropics/claude-code/issues/67765)（根因分析）。

**受影響**：Opus 4.7、Opus 4.8、Sonnet 4.5。**不受影響**：Opus 4.6、Sonnet 4.6。

---

## 運作方式

兩層獨立防禦，各自可單獨運作：

| 層級 | 功能 | `claude update` 後存活？ |
|------|------|--------------------------|
| **Hook**（`evap-shield.sh`） | PreToolUse hook，檢查每個 tool call。缺少必要參數時阻擋執行，並告知 model 停止重試。 | 是 |
| **Patch**（`patch-vh1.sh`） | 把 VH1 tokenizer 裡的 `!Y` 換成 `!0`（2 bytes，長度相同）。截斷的 string 會被 push 而非丟棄。 | 否——每次更新後需重跑 |

Hook 是安全網。Patch 降低 hook 需要觸發的頻率。

---

## 功能

| 指令 | 說明 |
|------|------|
| `bash install.sh` | 一鍵安裝到 `~/.claude/` |
| `bash install.sh --dry-run` | 預覽變更，不實際修改 |
| `bash patch-vh1.sh` | 定位並修補 CLI binary 裡的 VH1 bug |
| `bash patch-vh1.sh --status` | 查看 binary 版本、patch 狀態、上次 patch 資訊 |
| `bash patch-vh1.sh --restore` | 從 per-hash 備份還原原始 binary |
| `bash patch-vh1.sh --dry-run` | 預覽 patch，不實際套用 |
| `bash test-evap-shield.sh` | 跑 21 個測試 |

---

## 快速開始

### 環境需求

- Bash 4.0+
- `jq`（hook 需要）
- Python 3（patcher 需要）
- macOS 上需要 `codesign`（用來重新簽署 patch 後的 Mach-O binary）

### 安裝 hook

```bash
git clone https://github.com/{owner}/evap-shield.git
cd evap-shield
bash install.sh
```

這會把 `evap-shield.sh` 複製到 `~/.claude/hooks/` 並註冊到 `settings.json`。安裝前會先建立帶時間戳的 settings 備份。

### 套用 binary patch（可選）

```bash
bash patch-vh1.sh
```

腳本會自動定位 Claude Code binary、確認 bug pattern 只出現一次、建立 per-hash 備份、patch、在 macOS 重新簽署 Mach-O binary，並用啟動檢查驗證結果。

> **提示：** 為求最乾淨的結果，patch 前可先完全關閉 Claude Code。即使 CC 開著也能安全執行——啟動檢查用的是獨立的臨時副本，不是正在執行的 binary，所以不會被記憶體裡的舊映像誤導。

Patch 要完全重啟後才生效，且每次 `claude update` 後都得重跑——見 [讓 patch 生效](#讓-patch-生效)。

---

## 讓 patch 生效

Patch 改的是磁碟上的 binary——但故事還沒完。以下說明它什麼時候才真的生效，以及什麼時候得重跑。

### Patch 後：必須重啟

正在執行的 Claude Code 早就把舊的、未 patch 的 binary 載進記憶體了，所以 **patch 不影響當前 session**。要讓它生效：

1. 完全結束 Claude Code——不是 `/clear` 或開新 session，是整個 process 關掉。
2. 如果你透過 wrapper 或常駐啟動器開 Claude Code（terminal multiplexer、背景 daemon、IDE 擴充套件的 host process），那個 process 可能持有自己的一份 binary 副本——連 wrapper 一起重啟。
3. 開一個全新 session，用 `bash patch-vh1.sh --status` 確認（應顯示 `Status: patched`）。

### `claude update` 後：必須重跑

`claude update` 會把全新版本裝進另一個目錄，並把 `claude` 指過去。你 patch 過的 binary 被留在原地——沒被動過，但也不再被使用——而新的那個又帶著 bug。

所以每次更新後：

```bash
bash patch-vh1.sh        # 重新偵測、備份、patch 新版本
# 然後依上述步驟重啟
```

`--status` 反映的是腳本解析到的磁碟 binary，不是當前 session 正在跑的那個。任何時候都能跑 `bash patch-vh1.sh --status` 查看它是 `patched` 還是 `vulnerable`。

---

## 專案結構

```
evap-shield/
  evap-shield.sh        # PreToolUse hook——阻擋 {} tool calls
  install.sh            # 一鍵安裝
  patch-vh1.sh          # Binary patch 自動化（定位→備份→patch→驗證）
  test-evap-shield.sh   # 測試套件（21 tests）
  FIX-PLAN.md           # 完整技術分析與回退判定標準
  README.md             # English
  README_ZH.md          # 中文
```

---

## 回退判定標準

從 Opus 4.6 回到受影響的版本（如 4.8）時：

| 訊號 | 動作 |
|------|------|
| 5 個 session 零 `{}` 事件 | 留在 4.8 |
| Hook 攔住 `{}`，全部擋下 | 繼續觀察 |
| 同一 session 內 hook 觸發 3+ 次 | 套用 binary patch |
| `/clear` 無法恢復 session | 退回 Opus 4.6 |

完整決策樹見 [FIX-PLAN.md](FIX-PLAN.md)。

---

## 為什麼做這個

2026 年 5 月 23 日，Claude Code 開始當機。不是 crash——是凍結。Model 想好了要做什麼，然後……什麼都沒發生。Tool call 蒸發了。盯著轉圈圈看了二十一分鐘，才意識到某個根本性的東西壞了。

三天的調查追到了一個 minified JavaScript tokenizer 裡的單一布林值：`Y=!0` 在 JSON string 被 streaming 切斷時設 flag，然後 `!Y` 靜默跳過 push 該 token。一個被丟掉的 string 連鎖反應成 `{}` 參數，接著被 per-tool cache 鎖死，整個 session 中毒。

Issue 有 54+ 留言，零官方回覆。唯一乾淨的出路是降回 Opus 4.6。

等不是辦法，所以我們造了 evap-shield。

## 設計抉擇

**Hook 優先於 MCP middleware。** 最初的計畫是在 MCP server 加 schema validation 擋 `{}`。但那只保護自定義 MCP tools——Read、Edit、Bash 這些內建工具完全不受保護。後來發現 PreToolUse hook 能拿到完整的 `tool_input` payload，而且 exit code 2 可以阻擋執行。一個 hook 就能涵蓋所有 tool。

**兩層防禦，不是一層。** Hook 擋住傷害但不修 parser。Patch 修了 parser 但更新後會被覆蓋。搭在一起，hook 是永久安全網，patch 降低噪音。各自單獨也能運作。

**Per-hash 備份，不是 per-version。** `--restore` 只能還原「被 patch 的那個 binary」。如果使用者在 patch 和 restore 之間跑了 `claude update`，備份來自不同版本。用 SHA-256 比對防止靜默還原錯版本。

**Log 預設脫敏。** Hook 只記 tool name 和參數的 key 名稱——永遠不記參數值。檔案路徑、程式碼、使用者資料不會進 log。對開源工具來說，完整 input logging 是隱私風險。

---

## 技術限制

- Hook 只檢查有硬編碼 required-field map 的 tools（Read、Edit、Write、Bash、NotebookEdit、`mcp__*`）。不在清單裡的新 built-in tool 會通過。
- Binary patch 鎖定特定 byte pattern。如果 Anthropic 重構 parser，patcher 會拒絕 patch（安全失敗，不是靜默破壞）。
- Patch 不會在 `claude update` 後存活。每次更新後重跑 `patch-vh1.sh`。
- Hook 無法阻止 model 在 hook 觸發前的 retry loop。error message 寫成 terminal instruction 要求 model 停手，但這依賴 model 是否遵從。

---

## 授權

[MIT](LICENSE)

---

## 作者

**tznthou** — [tznthou@gmail.com](mailto:tznthou@gmail.com)
