# evap-shield

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4.0+-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-2.1.x-7C3AED.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![Tested](https://img.shields.io/badge/tested-2.1.181-brightgreen.svg)](CHANGELOG_ZH.md)

[English](README.md)

Claude Code VH1 streaming parser bug 的防禦工具包。這個 bug 會讓 tool call 的參數靜默變成 `{}`。

---

## 使用前須知

evap-shield 有兩層獨立防禦，風險屬性不同。動手前請先讀這段，再決定要跑哪一層。

**Hook 是低風險的那層。** `install.sh` 安裝的是一個 PreToolUse hook，只*偵測*並阻擋送給 MCP tool 的 `{}` 呼叫。它完全不碰 Claude Code binary，要移除也只是刪掉一個檔案和一條 settings 設定。

**Binary patch 是根治層——但它是對簽章 binary 的非官方修改。** `patch-vh1.sh` 會改磁碟上的 Claude Code CLI binary，翻轉 parser 裡的一個 flag。macOS 上接著會對 binary 做 ad-hoc 重簽，用一個本地簽章取代原廠的 Developer ID 簽章——沒有 Anthropic 的金鑰可重簽，這是讓本地 patch 過的 Mach-O 能啟動的唯一辦法。它跑得起來，但已經不是 Anthropic 出廠的那個 binary 了。

**它的療效是單元驗證，不是端到端驗證。** 一個白盒單元測試把原始與 patch 後的 parser 並排跑過 760 個 streaming-truncation 案例，0 regression；其餘是結構推論。沒有端到端的確認，原因很具體：受影響 parser 的 primary 失效路徑從 server-side mock 結構性不可達——只有真實互動 TUI 的 abort-and-finalize handler 才會 commit 那個觸發它的 mid-stream buffer，所以這個修復沒辦法在受控的 harness 裡端到端跑出來。單元測試是目前能拿到的最強驗證，它的效力到哪裡、我們就誠實講到哪裡。

**使用條款請自己確認。** 修改廠商的簽章 binary *可能*牽涉 Anthropic 的使用條款（Terms of Service）。我們沒有研究過條文，不對任何一方下判斷——如果你在意這點，請自己讀過條款再決定要不要 patch。

**風險自負，且完全可回退。** 這是對你自己機器上的軟體做的防禦性研究，不是叫你隨便去改 binary。有 per-hash 備份、任何一步失敗就自動回退、以及一行指令還原（見 [還原 patch](#還原-patch)）——但 binary 在你的機器上，決定權也在你。

### 你該跑哪一層？

| 如果你… | 跑這個 | 你會得到 |
|---------|--------|----------|
| 想保守一點——不想動 binary，或在意使用條款 | **只裝 hook**：`bash install.sh` | 偵測加上阻擋 MCP `{}`，完全不動 Anthropic 出廠的東西 |
| 想從源頭修 parser，並接受改簽章 binary 的風險 | **再加 patch**：`bash patch-vh1.sh` | 透過上述非官方 binary 修改，讓每個 tool 的 `{}` 從源頭就不形成 |

這是個*風險*問題——你願意跑哪一層。它跟下面的 [回退判定標準](#回退判定標準) 是兩回事，那個是*症狀*問題——bug 活躍到什麼程度才值得 patch。

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
| **Patch**（`patch-vh1.sh`） | 把 VH1 tokenizer 裡被否定的 gate flag 翻成 `!0`（1 byte，長度相同）。比對採結構錨點——錨定 parser 的不變量，不綁 minified 變數名，所以跨版本的 bundler 洗牌都能存活（例如 2.1.181 的 Bun 1.4 改名）。截斷的 string 會被 push 而非丟棄，`{}` 從源頭就不會形成——每個 tool 都是。 | 否——每次更新後需重跑 |
| **Hook**（`evap-shield.sh`） | PreToolUse hook，阻擋送給 **MCP tool** 的 `{}` 呼叫——這是 Claude Code 內建 validation 唯一沒守到的洞（見 [設計抉擇](#設計抉擇)）。同時記錄 `{}` 事件，讓你知道 bug 有沒有在觸發。 | 是 |

Patch 是根治層——它讓 `{}` 根本不會形成。Hook 是 MCP tool 的免重啟安全網，也是你判斷 bug 是否還活著的觀測窗口。

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
| `bash test-evap-shield.sh` | 跑 hook 測試套件（25 tests） |
| `bash test-patch-vh1.sh` | 跑 patch failure-path 測試（45 tests） |
| `bash test-install.sh` | 跑 installer 合併安全測試（17 tests） |

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

## 還原 patch

Patch 完全可逆，而且還原機制的設計目標是：再壞也不會比「沒 patch」更糟。

```bash
bash patch-vh1.sh --restore
```

這會從 per-hash 備份還原原始 binary，並清除 patch 狀態。三層把關還原：

| 層 | 時機 | 做什麼 |
|----|------|--------|
| **自動還原** | patch 某步失敗（重簽、啟動檢查、驗證） | 還原原始 binary 並退出，絕不會留下半 patch 的 binary |
| **`--restore`** | patch 後任何時候 | 還原備份的原始版本，還原前先做 hash 比對 |
| **手動** | 連腳本都不想信 | 自己把 `~/.claude/state/patch-backups/` 裡的備份 `cp` 蓋回 binary |

還原為什麼是安全的：

- **原子替換。** 還原會先複製到暫存檔，再用 `rename()` 蓋過 binary，中斷的還原不會把 binary 截斷成半個。新 inode 也不會動到還在執行的 Claude Code。
- **先驗證。** 備份的 SHA-256 會在替換*之前*先跟記錄的原始 hash 比對——損壞的備份會被拒絕，而不是被裝上去。
- **下限是「跑得起來」。** 最壞情況是落在「沒 patch 但能跑」的 binary（bug 回來了，但 Claude Code 啟動得了）——絕不會是開不起來的那種。
- **不需要一個能跑的 Claude Code。** `--restore` 是 terminal 指令，所以就算哪天啟動失敗，你不靠一個正常的 Claude Code 也能救回來。

跟 patch 本身一樣，還原要等下次完全重啟才生效。

---

## 專案結構

```
evap-shield/
  evap-shield.sh        # PreToolUse hook——阻擋送給 MCP tool 的 {}
  install.sh            # 一鍵安裝
  patch-vh1.sh          # Binary patch 自動化（定位→備份→patch→驗證）
  test-evap-shield.sh   # Hook 測試套件（25 tests）
  test-patch-vh1.sh     # patch failure-path 測試（45 tests）
  test-install.sh       # installer 合併安全測試（17 tests）
  FIX-PLAN.md           # 完整技術分析與回退判定標準
  README.md             # English
  README_ZH.md          # 中文
  CHANGELOG.md          # 更新日誌（English）
  CHANGELOG_ZH.md       # 更新日誌（中文）
  docs/vh1-investigation.md  # 完整 VH1 bug 調查
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

**PreToolUse hook，守備範圍限於 MCP。** 我們評估過 MCP server middleware（schema 層拒絕 `{}`），最後選了 PreToolUse hook，因為它拿得到完整的 `tool_input` payload。它實際的守備範圍就是 MCP 這一塊：送給 built-in tool（Read、Edit、Bash）的 `{}` 會被 Claude Code 自己的 validation 擋下，那層跑在 PreToolUse hook *之前*，所以 hook 根本看不到。Hook 只會為 **MCP tool** 觸發——MCP 的 validation 跑在 hook *之後*。built-in tool 由 Claude Code 自己保護；hook 補的是 MCP 這個洞，並記錄 `{}` 事件讓你知道 bug 是否還活著。

**兩層防禦，不是一層。** Patch 從源頭修 parser——每個 tool 都涵蓋——但每次更新後會被覆蓋。Hook 撐得過更新、不必重啟，但只守 MCP 這個洞。所以 patch 是根治層，hook 是 patch 失效那段空窗（更新後、你重跑之前）的永久防線。各自單獨也能運作。

**Per-hash 備份，不是 per-version。** `--restore` 只能還原「被 patch 的那個 binary」。如果使用者在 patch 和 restore 之間跑了 `claude update`，備份來自不同版本。用 SHA-256 比對防止靜默還原錯版本——而且還原本身會先驗證備份的 hash 才信任它，再用 `rename()` 原子替換，被中斷的還原也絕不會留下截斷的 binary。

**Log 預設脫敏。** Hook 只記 tool name 和參數的 key 名稱——永遠不記參數值。檔案路徑、程式碼、使用者資料不會進 log。對開源工具來說，完整 input logging 是隱私風險。

---

## 技術限制

- **Hook 不保護 built-in tool。** 送給 Read、Edit、Bash 等的 `{}` 會被 Claude Code 自己的 validation 在 PreToolUse hook 執行*之前*擋下，hook 根本看不到。required-field map 列出 built-in 只是為了完整性，實際上 hook 只會為 **MCP tool**（`mcp__*`）觸發——MCP 的 validation 跑在 hook 之後。built-in 的 `{}` 由 Claude Code 自己處理，不是這個 hook。
- **Patch 的根治效果是單元驗證，不是端到端。** 760/0 個 streaming-boundary 單元案例證實截斷的 token 會被 push 而非丟棄；完整的端到端確認無法透過 server mock 觀測（受影響的 parser 路徑從外部結構性不可達）。這是單元證明加結構推論。
- Binary patch 錨定 parser 的結構不變量，不綁 minified 變數名，所以跨版本的 bundler/minifier 洗牌都能存活（已在 2.1.181 的 Bun 1.4 改名驗證）。如果 Anthropic 重構 parser 本身，patcher 會拒絕 patch 而非破壞它（安全失敗，不是靜默破壞）。
- Patch 不會在 `claude update` 後存活。每次更新後重跑 `patch-vh1.sh`。
- Hook 無法阻止 model 在 hook 觸發前的 retry loop。error message 寫成 terminal instruction 要求 model 停手，但這依賴 model 是否遵從。

---

## 授權

[MIT](LICENSE)

---

## 作者

**tznthou** — [tznthou@gmail.com](mailto:tznthou@gmail.com)
