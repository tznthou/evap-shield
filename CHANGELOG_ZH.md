# 更新日誌

[English](CHANGELOG.md)

本檔記錄 evap-shield 所有值得注意的變更。

格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。本專案以日期分組，而非語意化版本——這是腳本工具集，不走 package registry 發布。

## 2026-07-11

### Changed

- tested badge 更新到 **2.1.207**。Claude Code 從 2.1.206 → 2.1.207——連續第四天每日一更（2.1.204 裝於 2026-07-08、2.1.205 裝於 2026-07-09、2.1.206 裝於 2026-07-10、2.1.207 裝於 2026-07-11），且版號再度連續，兩點 diff 不需要跨過任何沒裝的版本；2.1.203 仍是唯一從未裝過的版本（`~/.local/share/claude/versions/` 現在有 205、206、207）。結構錨點掃原廠 binary 仍只找到 1 個 vulnerable site（bug 1／fix 0），字元級掃描迴圈簽名 `e[++t]` 仍出現 7 次。parser site 跟 2.1.206 逐字相同——±260 bytes window raw 就對上，連 normalize 都不必——仍是 `,!l)r.push({type:"string",value:a})`，flag（`l`）、接收端（`r`）、累加變數（`a`）都沒變——這下連續五版（2.1.202、2.1.204、2.1.205、2.1.206、2.1.207）都帶同一組區域名稱。build 溯源：原廠 binary 長了 842,112 bytes（240,395,024 → 241,237,136），parser site 漂移 +733,820 bytes（211,201,388 → 211,935,208）；Bun banner 仍是 `Bun v1.4.0`，沒有 runtime 升級。Anthropic 自己的 2.1.207 changelog（25 條）沒有一條碰 tool-call parsing、JSON tokenization 或 streaming parser——幾條*聽起來*沾邊的都落在別層：「streaming 超長清單時終端卡頓」是渲染層、「rules globs 的 malformed 括號 pattern 弄壞檔案讀取」是檔案路徑 glob 處理、「agent teams 因 malformed teammate mailbox 訊息 crash loop」是 agent-teams 信箱層、「auto-updater 不再覆寫 `~/.local/bin/claude` 的自訂 launcher script 或 symlink」是更新管線（這台機器的 launcher 是官方原裝 symlink，patch 的對象是 symlink 解析到的版本化 binary 本體，對本 repo 沒有影響）、「良性系統生成對話更新觸發的誤報 prompt-injection 警告」是警告分類器修復——與 bug cluster 的 model 側那一半*語意上*相鄰，但不是 parser。strings diff（新增 3,267／移除 2,721）在關鍵軸線上跟 2.1.206 一樣乾淨：新增集裡 charCode／codePoint／tokenizer 味的行**連續第二版是零條**，6 條泛用 `parse` 命中全落在別處（plugin shell-form 警告文案、script 輸出解析提示、proxy response 解析、ANSI 色碼 `parseFloat`、Storybook adapter 註釋、排程 interval 解析提示）。新增集跟官方 changelog 自己的主題對得上——agent 味字串（37）、plugin（24）、auto-mode（22，Bedrock／Vertex／Foundry 免 opt-in 那條）、teammate-mailbox（20）、worktree（14）、launcher／symlink（10）——沒有一條伸進 parser。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `1397a062c688…` → patched `da14ef36a630…`），並在磁碟（bug 0／fix 1）、有效 ad-hoc 簽章、本 session 的 mmap inode 三處驗證（`lsof` 查本 session 自己的 process，PID 4303，執行檔解析到 `~/.local/share/claude/versions/2.1.207`，inode 58669478，patch 於 2026-07-11T02:26:36Z 完成後 23 秒啟動——patched dogfooding）。一條磁碟層註腳：這次 re-sign 讓檔案縮了 1,403,616 bytes，又是大 CD 版面——2.1.207 原廠 CodeDirectory 帶 58,435+7 個 hash slot（1,870,277 bytes）外加 9,046 bytes Developer ID 憑證鏈，被 ad-hoc re-sign 換成 14,609+2 slot（467,648 bytes）的精簡版；2.1.202、206、207 都是重簽章原廠版面，2.1.204／205 的精簡原廠簽章現在看來才是特例。這是 2.1.181 以來官方第 **19** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196、197、198、199、200、201、202、204、205、206 後）仍未修 VH1。

## 2026-07-10

### Changed

- tested badge 更新到 **2.1.206**。Claude Code 從 2.1.205 → 2.1.206——這是 2.1.205 更新隔天早上的另一次獨立更新（三版各有各的日期條目：2.1.204 裝於 2026-07-08、2.1.205 裝於 2026-07-09、2.1.206 裝於 2026-07-10——連續第三天每日一更），且版號再度連續，兩點 diff 不需要跨過任何沒裝的版本；2.1.203 仍是唯一從未裝過的版本（`~/.local/share/claude/versions/` 現在有 204、205、206）。結構錨點掃原廠 binary 仍只找到 1 個 vulnerable site（bug 1／fix 0），字元級掃描迴圈簽名 `e[++t]` 仍出現 7 次。parser site 跟 2.1.205 逐字相同——±260 bytes window raw 就對上，連 normalize 都不必——仍是 `,!l)r.push({type:"string",value:a})`，flag（`l`）、接收端（`r`）、累加變數（`a`）都沒變——這下連續四版（2.1.202、2.1.204、2.1.205、2.1.206）都帶同一組區域名稱。build 溯源：原廠 binary 長了 2,957,056 bytes（237,437,968 → 240,395,024），parser site 漂移 +1,153,245 bytes（210,048,143 → 211,201,388）；Bun banner 仍是 `Bun v1.4.0`，沒有 runtime 升級。Anthropic 自己的 2.1.206 changelog（27 條）沒有一條碰 tool-call parsing、JSON tokenization 或 streaming parser——整份都是 CLI/UX 與管線雜項（gateway `/login` 端點、`--mcp-config` 的 `request_timeout_ms` 修復、`/model` picker 列修復、agents view 修復、一個 Bedrock 啟動卡住），沒有比這些更接近 parser 的條目。strings diff（新增 4,548／移除 3,059）在關鍵軸線上是歷來最乾淨的一次：新增集裡 charCode／codePoint／tokenizer 味的行是**零條**（2.1.204 有 2 條、2.1.205 有約 125 條重建重切段命中），13 條泛用 `parse` 命中全落在別處（dataviz HTML 模板裡 chart runtime 的 `JSON.parse`、一條 backend wire-hint 註釋、一條 hosts 檔 regex 說明）。新增集是分散的功能面——CSS design tokens（70 條 `--cds-*`）、chart／dataviz 模板（47 條）、agent 味字串（47 條）、plugin／LSP 管線（約 24 條）、voice mode 文案（7 條）——沒有一條伸進 parser。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `3197aba4442d…` → patched `d60e80d290a4…`），並在磁碟（bug 0／fix 1）、有效 ad-hoc 簽章、本 session 的 mmap inode 三處驗證（`lsof` 查本 session 自己的 process，PID 47004，執行檔解析到 `~/.local/share/claude/versions/2.1.206`，inode 58468534，patch 於 2026-07-10T00:23:39Z 完成後三到四分鐘啟動——patched dogfooding）。一條磁碟層註腳：這次 re-sign 讓檔案縮了 1,398,720 bytes，回到 2.1.202 那次的量級而非 2.1.204/205 的 1,184——因為 2.1.206 原廠 CodeDirectory 回到大 slot 版面（58,231+7 個 hash slot、1,863,749 bytes，外加 9,046 bytes 憑證簽章），被 ad-hoc re-sign 換成 14,558+2 slot 的精簡版；這是 re-sign 的機械性後果，不是內容變更。這是 2.1.181 以來官方第 **18** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196、197、198、199、200、201、202、204、205 後）仍未修 VH1。

## 2026-07-09

### Changed

- tested badge 更新到 **2.1.205**。Claude Code 從 2.1.204 → 2.1.205——這是 2.1.204 更新一天後的另一次獨立更新（兩版各有各的日期條目：2.1.204 裝於 2026-07-08、2.1.205 裝於 2026-07-09），且這次版號連續，兩點 diff 不需要跨過任何沒裝的版本；2.1.203 仍是唯一從未裝過的版本（`~/.local/share/claude/versions/` 現在有 202、204、205）。結構錨點掃原廠 binary 仍只找到 1 個 vulnerable site（bug 1／fix 0），字元級掃描迴圈簽名 `e[++t]` 仍出現 7 次。parser site 跟 2.1.204 逐字相同——仍是 `,!l)r.push({type:"string",value:a})`，flag（`l`）、接收端（`r`）、累加變數（`a`）都沒變——這下連續三版（2.1.202、2.1.204、2.1.205）都帶同一組區域名稱，更加坐實 2.1.202 那次識別字重排是單一事件，不是新一輪改名節奏。build 溯源：原廠 binary 長回 476,064 bytes（236,961,904 → 237,437,968），parser site 漂移 +396,618 bytes（209,651,525 → 210,048,143）；Bun banner 仍是 `Bun v1.4.0`，沒有 runtime 升級。Anthropic 自己的 2.1.205 changelog（22 條）沒有一條碰 tool-call parsing、JSON tokenization 或 streaming parser：最接近的是一條 `--json-schema` 修復（structured-output 的 *schema 驗證*，不是字元級 JSON string tokenizer），以及「Auto-update binary downloads now stream to disk … cutting the updater's peak memory usage by roughly 400 MB」——那 400 MB 是 updater process 的 RAM，不是 binary 大小（binary 反而長了），跟 2.1.203 那次的磁碟瘦身也是兩回事。另外兩條 model-behavior guardrail（background task 通知現在會明講「no human input has occurred」以阻止 *捏造的 transcript 內批准*、以及一條擋竄改 transcript 檔的 auto-mode 規則）講的是這個 bug cluster 的 model-side confabulation 那一半，不是 VH1 所在的 client parser。strings diff（新增 4,966／移除 4,655）比 2.1.204 那次乾淨的兩條命中吵——新增集裡有約 125 條 charCode／codePoint／tokenizer 味的行——但逐條抽樣，全部落在被重建位移的既有字元處理常式（UTF-8 codec 迴圈、數字掃描器、第三方 `marked`／PowerShell／JSON-number tokenizer），沒有一條是 VH1 的 `push({type:"string",value:…})` site；命中數高只是因為 `strings` 在周圍 bytes 位移後把 minified library 程式碼重新切段，而判決本來就靠結構錨點對 parser-site window 的逐字讀取（跟 2.1.204 相同），從不靠 strings diff。新增集其餘是新功能面：`workflow`／`schedule`／`cron` 字串（約 283 條，對得上本 session 的 `Cron*`／`RemoteTrigger`／`Workflow` 工具）與 WebGL shader／blend 程式碼（約 129 條）。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `33e28624c5ae…` → patched `35a8d68cd2ca…`），並在磁碟（bug 0／fix 1）、有效 ad-hoc 簽章（`codesign --verify`：「valid on disk … satisfies its Designated Requirement」）、本 session 的 mmap inode 三處驗證（`lsof` 查本 session 自己的 process，PID 66238，執行檔解析到 `~/.local/share/claude/versions/2.1.205`，inode 58287616——patched dogfooding）。這是 2.1.181 以來官方第 **17** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196、197、198、199、200、201、202、204 後）仍未修 VH1。

## 2026-07-08

### Changed

- tested badge 更新到 **2.1.204**。這台機器上 Claude Code 從 2.1.202 → 2.1.204——2.1.203 官方有出但這台機器從未裝過（`~/.local/share/claude/versions/` 只留著 201、202、204），所以這篇是直接跨版兩點 diff，不是逐版鏈接。結構錨點掃原廠 binary 仍只找到 1 個 vulnerable site（bug 1／fix 0），字元級掃描迴圈簽名 `e[++t]` 仍出現 7 次。parser site 跟 2.1.202 逐字相同——仍是 `,!l)r.push({type:"string",value:a})`，flag（`l`）、接收端（`r`）、累加變數（`a`）都沒變——代表 2.1.202 那次識別字重排（2.1.187 以來 raw 凍結首度被打破）是單一事件，不是新一輪改名節奏的開端。build 溯源：原廠 size 縮了 6.67 MB（243,631,376 → 236,961,904 bytes），parser site 漂移 −5,569,911 bytes（215,221,436 → 209,651,525）。這個縮減跟官方自己的說法對得上：2.1.203 的 changelog（37 條、大多是 background-agent／daemon／worktree／session 修復）裡有一條「Reduced binary size by ~7 MB and startup memory by ~7 MB by loading a large bundled dependency lazily instead of inlining it」——跟量到的 6.67 MB 對得夠近，不必另找解釋。2.1.203 跟 2.1.204(只有一條：headless session 裡 SessionStart hook streaming 的修復)的 changelog 都沒有一條碰 tool-call parsing 或 string tokenization。strings diff（新增 5,140、移除 3,094）裡新增字串只有兩條沾到 charCode／codePoint／tokenizer 味，都追到既有 library 程式碼隨重建搬位：一個是 markdown renderer 自己的 tokenizer（`this.tokenizer.code`，來自 `marked`），一個是 JS 語法 library 的 lexer 錯誤字串（`Unable to Tokenize because Errors detected in definition of Lexer`，來自 `chevrotain`）——都不是本 repo 要修的字元級 JSON string tokenizer。新增字串大宗落在新功能面：WebGL shader／blend 程式碼（約 35 條命中，一個 canvas 渲染功能）、`chevrotain` 這個 parser-generator library 本身（13 條）、以及 `workflow`／`schedule`／`routine` 風味的字串（合計 19 條），這些對得上本 session 自己剛拿到的 `Cron*`、`RemoteTrigger` 工具。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `1677b67595b6…` → patched `c5ca6692a3f5…`），並在磁碟（bug 0／fix 1）、有效 ad-hoc 簽章、本 session 的 mmap inode 三處驗證（`lsof` 查本 session 自己的 process，執行檔解析到 `~/.local/share/claude/versions/2.1.204`，inode 58124573，patch 完成後 22 秒才啟動——patched dogfooding）。這是 2.1.181 以來官方第 **16** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196、197、198、199、200、201、202 後）仍未修 VH1。

## 2026-07-07

### Changed

- tested badge 更新到 **2.1.202**。Claude Code 從 2.1.201 → 2.1.202（連續版號）。結構錨點掃原廠 binary 仍只找到 1 個 vulnerable site（bug 1／fix 0），字元級掃描迴圈簽名 `e[++t]` 仍出現 7 次——但這是 2.1.181 以來頭一次，site 周圍的窗口不是逐字相同：2.1.201 的 `,!l)n.push({type:"string",value:a})`(迴圈字元變數 `r`、數字測試變數 `s`)變成 2.1.202 的 `,!l)r.push({type:"string",value:a})`(迴圈字元變數 `n`、數字測試變數 `i`)——迴圈變數與接收端變數對調（`r`↔`n`），數字測試用的 helper 改名（`s`→`i`），flag（`l`）與累加變數（`a`）不變。兩版的 Bun runtime banner（`Bun v1.4.0`／`Bun/1.4.0`）相同，所以這比較像同一支模組區域性重編譯、把 minifier 的命名往後推了一格，不是像 2.1.181 那種 runtime／bundler 升級——結構錨點認的是 `type:"string"` 這個 AST tag、不是識別字命名，本來就是為了扛住這種情況設計的。build 溯源：原廠 size 長了 231,708,784 → 243,631,376 bytes（+11.4 MB，這份紀錄裡單一版號最大的一次跳動），parser site 漂移 207,862,449 → 215,221,436（+7,358,987 bytes）。strings diff（新增 5,819、移除 5,251，同樣是目前最大量）與官方 2.1.202 changelog 的敘述吻合：新增 `/config` 的「Dynamic workflow size」設定、`workflow.run_id`／`workflow.name` OpenTelemetry 屬性、`/workflows` 版面調整——新增字串裡的 `CORRECTNESS_ANGLES`、`finder_budget`、隨附的「Managed Agents」參考文件、一個 Storybook-source 轉換器都對得上。官方有一行「Fixed workflow scripts with unicode quote escapes in strings being corrupted before parsing」值得點名，以免被誤認跟 VH1 有關：那是驗證使用者自寫 workflow script 的 acorn 風格 JS 原始碼解析器（`ecmaVersion:"latest",sourceType:"module"`，兩版都在、只是位置挪動），跟本 repo 要修的字元級 JSON tokenizer 是不同層的不同 parser。strings diff 裡約 122 條 charCode／codePoint／tokenizer 風味的命中，追下去也是同一批既有 library 程式碼隨重建搬位造成的，不是新的 tokenizer 邏輯。這是 2.1.181 以來官方第 **15** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196、197、198、199、200、201 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套(`!l`→`!0`，1 byte；原廠 `7414f707861e…` → patched `a13d8253c64a…`)，並在磁碟（bug 0／fix 1）、有效 ad-hoc 簽章、本 session 的 mmap inode 三處驗證（patched dogfooding）。另記一筆磁碟層級的小發現：patched 檔案比原廠小 1,417,536 bytes——不是內容 patch 本身（同長度的 1-byte 翻轉）造成的，而是重簽章：Apple 的 Developer ID CodeDirectory（1,888,837 bytes、59,015+7 個 hash slot，外加 9,047 bytes 的憑證鏈簽章）被換成較小的 ad-hoc CodeDirectory（472,288 bytes、14,754+2 個 slot，沒有憑證 blob），差不多解釋了全部落差——這是 ad-hoc 重簽章已知的機械性後果，不是內容被動了手腳。

## 2026-07-04

### Changed

- tested badge 更新到 **2.1.201**，一次補上兩個改版——Claude Code 從 2.1.199 → 2.1.200（2.1.200 昨晚更新，已驗證但未單獨記錄）→ 2.1.201。兩個 transition 官方都沒修 VH1：parser site 前後 ±260 bytes 的窗口在 2.1.199、2.1.200、2.1.201 三版逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，連 normalize 都不必——這是連續第 9、第 10 個 raw 凍結的 build（延續 2.1.187 以來不間斷的 raw 凍結）。結構錨點掃各版原廠 binary 都只有 1 個 vulnerable site（bug 1／fix 0），字元級掃描迴圈簽名 `e[++t]` 在三版都恰好出現 7 次。build 溯源：2.1.199 → 2.1.200 縮了 446,752 bytes（232,155,536 → 231,708,784），site 漂移 799,552 bytes（207,062,833 → 207,862,385）；2.1.200 → 2.1.201 是罕見案例——兩個原廠 binary *完全*都是 231,708,784 bytes，但**並非**逐字相同（首個相異在 offset 2112，一個 Mach-O load-command 位址欄位），parser site 仍漂移了 64 bytes（207,862,385 → 207,862,449），證明是貨真價實的新 build、只是重打包後恰好同 size。2.1.200 → 2.1.201 的 strings diff 顯示新增 158 條、移除 160 條短字串，無一碰字元級 string tokenizer（沒有新增 `charCode`／`codePoint`／`tokenizer`）——新增字串以 gateway／session／feature-flag 層為大宗（`allowedHttpHookUrls`、`disableRemoteControl`、`disableClaudeAiConnectors`、`/workflows`、Sessions-API 標籤），無一觸及 parser。這是 2.1.181 以來官方第 **13、14** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196、197、198、199 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套到 2.1.201（`!l`→`!0`，1 byte；原廠 `a0852d76…` → patched `a9941c6f…`），並在磁碟（bug 0／fix 1）+ 有效 ad-hoc 簽章、running session mmap inode（PID 45409/50688 都持有 inode 57281235——patched dogfooding）驗證。

## 2026-07-03

### Changed

- 在 README 與調查文件記錄 model-side 邊界，並在 #62123 發表[第二條社群留言](https://github.com/anthropics/claude-code/issues/62123#issuecomment-4878159880)，貢獻兩週的取證資料：洩漏 `<invoke>` XML 前的 stray token pattern（`câ`／`call`／`court`／`count`——全部 c- 開頭、全在 opener 位置，橫跨 CLI／Desktop 與中日韓語境），以及同日取證坐實的 confabulation 形態——模型在單一 thinking block 內腦內執行工具，並發出假的「偵測到 prompt injection」／「環境損壞」警報，每一項聲稱都通不過 claim-vs-artifact 的 transcript 對照（對應 #64409 cluster）。技術限制新增一條把範圍寫死：model-side 形態在任何 client 修法的上游；repo 對它們能提供的是分診（辨認你中的是哪型指紋），不是防禦。
- tested badge 更新到 **2.1.199**。Claude Code 從 2.1.198 → 2.1.199（連續版號）。兩路 binary diff 確認官方仍未修 VH1：parser site 前後 ±260 bytes 的窗口與 2.1.198 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，連 normalize 都不必，這是連續第 8 個 raw 凍結的 build，延續 2.1.187 以來不間斷的 raw 凍結。結構錨點掃整個 binary 也只有 1 個 vulnerable site（bug 1／fix 0），字元級掃描迴圈簽名 `e[++t]` 在兩版都恰好出現 7 次，一次不差。原廠 binary 長了 2.83 MB（229,328,464 → 232,155,536），site 漂移 1,326,226 bytes（205,736,607 → 207,062,833），證明是貨真價實的新 build、parser 原地凍結。strings diff 顯示新增的 4,031 條（與移除的 2,708 條）短字串全落別處——約 1,400 條是 bundler 生成的 class constructor 守衛（`Cannot call a class constructor _XX without |new|`，編譯工具鏈層變動），其餘以 CSS design tokens（violet／magenta／neutral 色票、`--hl-*` highlight theme、Anthropic Sans/Mono）的 UI 模板層為大宗——tokenizer 新增字串為 0、parser 相關命中僅 1 條通用語意（`parseRepoSlug`），無一碰字元級 string tokenizer。這是 2.1.181 以來官方第 **12** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196、197、198 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `e3cb61ab…` → patched `c154554c…`），並在磁碟（bug 0／fix 1）、簽章、running session mmap inode（即本 session，啟動時間晚於 patch 完成 21 秒——patched dogfooding）三處驗證。

## 2026-07-02

### Fixed

- **Hook：counter file 存在、但當前 session+tool 沒有紀錄時，計數算術會爆掉。** `grep -c` 在無 match 時會印出 `0` *且* exit 1，舊寫法的 `|| echo 0` 因此疊上第二個零（`0\n0`），讓 block 訊息夾帶 shell `syntax error` 噪音，也讓「3 次升級 CRITICAL」的邏輯失效。2026-06-30 真實環境實測到（訊息顯示「Blocked calls in this session: 0\n0」）。現在計數只取 `grep` 的輸出、外加數字格式保底；並補上 regression 測試涵蓋「髒 counter file」情境——舊測試套件每次都從刪掉的 counter file 起跑，從未踩到這個分支。

### Changed

- **Hook：MCP `{}` 改依 per-session 歷史判定，不再無條件擋。** 舊的無差別規則在真實環境唯一一次觸發就是誤判：一次合法的零參數 MCP 呼叫（`tabs_context_mcp`，schema 全 optional）被擋下，模型還被告知參數「重試也會是空的」、該對一個健康的 session 執行 `/clear`。Hook 讀不到 MCP schema，光憑一個 `{}` 沒有訊號——但 VH1 中毒的特徵有：tool 在同一個 session 裡先送過真參數、然後塌縮成 `{}`。Hook 現在以 session 為單位記錄非空的 MCP 呼叫（`~/.claude/state/evap-shield-nonempty`），只擋帶著這個歷史的 tool 的 `{}`；首發 `{}` 放行並記錄為 `allowed`。Block 訊息改以歷史證據開頭、拿掉無條件的「已知 bug」斷言、加上「刻意空呼叫」的出口。Log 每行新增 `action` 欄位（`blocked`／`allowed`）。Hook 測試套件：25 → 30 tests（歷史閘門三態、跨 session 隔離、髒 counter、log action）。

- tested badge 更新到 **2.1.198**。Claude Code 從 2.1.197 → 2.1.198（連續版號）。兩路 binary diff 確認官方仍未修 VH1：parser site 前後 ±260 bytes 的窗口與 2.1.197 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，連 normalize 都不必，這是連續第 7 個 raw 凍結的 build（繼 187→191、191→193、193→195、195→196、196→197，再到 197→198），延續 2.1.187 以來不間斷的 raw 凍結。結構錨點掃整個 binary 也只有 1 個 vulnerable site（bug 1／fix 0），字元級掃描迴圈簽名 `e[++t]` 在兩版都恰好出現 7 次，一次不差。原廠 binary 長了 2.08 MB（227,251,472 → 229,328,464），site 漂移 3,048,115 bytes（202,688,492 → 205,736,607），證明是貨真價實的新 build、parser 原地凍結。strings diff 顯示新增的 15,452 條（與移除的 3,719 條）短字串主要對應這版兩項主打新功能——highlight.js 11 語法高亮升級（大量各語言關鍵字字典）與新增的 `/dataviz` skill（色票驗證器、圖表設計文案）——tokenizer 新增字串為 0、parser 相關命中 31 條全是通用語意（argparse、YAML、Storybook、proxy response），無一碰字元級 string tokenizer。這是 2.1.181 以來官方第 **11** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196、197 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `ab6f7ee1…` → patched `5b923d8e…`），並在磁碟（bug 0／fix 1）、簽章、running session mmap inode（即本 session，啟動時間晚於 patch 完成 19 秒——patched dogfooding）、啟動時序四處驗證。

## 2026-07-01

### Changed

- tested badge 更新到 **2.1.197**。Claude Code 從 2.1.196 → 2.1.197（連續版號）。兩路 binary diff 確認官方仍未修 VH1：parser site 前後 ±120 bytes 的窗口與 2.1.196 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，連 normalize 都不必，這是連續第 6 個 raw 凍結的 build（繼 187→191、191→193、193→195、195→196、再到 196→197），延續 2.1.187 以來不間斷的 raw 凍結。結構錨點掃整個 binary 也只有 1 個 vulnerable site（bug 1／fix 0）。原廠 binary 長了 1.4 MB（225,782,608 → 227,251,472），site 漂移 100,324 bytes（202,588,168 → 202,688,492），證明是貨真價實的新 build、parser 原地凍結。strings diff 顯示新增的 3,526 條（與移除的 3,368 條）短字串全落在別處——tool/agent/context/task/model/MCP/auth 跨子系統——tokenizer（+22）和 parser（+64）數量微乎其微，無一碰字元級 string tokenizer。這是 2.1.181 以來官方第 **10** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195、196 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `8cc0c4d1…` → patched `e94ede6d…`），並在磁碟（bug 0／fix 1）、簽章、running session mmap inode（即本 session——patched dogfooding）、啟動時序四處驗證。

## 2026-06-30

### Changed

- tested badge 更新到 **2.1.196**。Claude Code 從 2.1.195 → 2.1.196（連續版號）。兩路 binary diff 確認官方仍未修 VH1：parser site 前後 ±120 bytes 的窗口與 2.1.195 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，連 normalize 都不必，這是連續第 5 個 raw 凍結的 build（繼 187→191、191→193、193→195、再到 195→196），延續 2.1.187 以來不間斷的 raw 凍結。結構錨點掃整個 binary 也只有 1 個 vulnerable site（bug 1／fix 0）。原廠 binary 長了 1.1 MB（224,682,640 → 225,782,608），site 漂移 981,275 bytes（201,606,893 → 202,588,168），證明是貨真價實的新 build、parser 原地凍結。strings diff 顯示新增的 10,262 條（與移除的 7,616 條）短字串全落在別處——agent/plugin/MCP/skill/workflow/sandbox/OAuth/Bedrock 跨子系統——無一碰字元級 string tokenizer。這是 2.1.181 以來官方第 **9** 個有效改版（繼 2.1.183、185、186、187、190、191、193、195 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `6fc6e61a…` → patched `7fed84d2…`），並在磁碟（bug 0／fix 1）、簽章、running session mmap inode（即本 session——patched dogfooding）、啟動時序四處驗證。

## 2026-06-27

### Changed

- tested badge 更新到 **2.1.195**。Claude Code 從 2.1.193 → 2.1.195（2.1.194 跳號）。兩路 binary diff 確認官方仍未修 VH1：parser site 前後 ±120 bytes 的窗口與 2.1.193 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，連 normalize 都不必，這是連續第 3 個 raw 凍結的 build（繼 187→191、191→193 後），延續 2.1.187 以來不間斷的 raw 凍結——連前段的 escape 掃描迴圈（`if(r==="\\"){…l=!0;break}a+=r+e[t]`）都原封未動。結構錨點掃整個 binary 也只有 1 個 vulnerable site（bug 1／fix 0）。原廠 binary 長了 2.43 MB（222,248,240 → 224,682,640），site 漂移 3,313,810 bytes（198,293,083 → 201,606,893），證明是貨真價實的新 build、parser 原地凍結。strings diff 顯示新增的 4,746 條（與移除的 2,534 條）短字串全落在別處——LLM gateway/proxy 轉發層（re-emit Anthropic-shaped `text/event-stream`、Bedrock 的 AWS binary event-stream、strip 掉 client 的 `Authorization`）、JWE/JWK/OAuth 憑證層、agent/workflow 子系統、voice streaming、sandbox、Storybook adapter——無一碰字元級 string tokenizer。這是 2.1.181 以來官方第 **8** 個有效改版（繼 2.1.183、185、186、187、190、191、193 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `8b45adad…` → patched `84c24c42…`），並在磁碟（bug 0／fix 1）、簽章、running session mmap inode（即本 session——patched dogfooding）、啟動時序四處驗證。

## 2026-06-26

### Changed

- tested badge 更新到 **2.1.193**，從 2.1.187 一次補齊——下方 2.1.191 的 re-check（2026-06-25）已記入 investigation 判決鏈，但當時公開 badge 未同步 bump，故本條同時涵蓋 2.1.191 與 2.1.193。Claude Code 從 2.1.191 → 2.1.193（2.1.192 跳號）。兩路 binary diff 確認官方仍未修 VH1：parser site 前後 ±120 bytes 的窗口與 2.1.191 逐字相同——仍是 `,!l)n.push({type:"string",value:a})`，連 normalize 都不必，延續 2.1.187 以來的 raw 凍結——結構錨點掃整個 binary 也只有 1 個 vulnerable site（bug 1／fix 0）。原廠 binary 再長 2.39 MB（219,856,224 → 222,248,240），site 漂移 989,822 bytes（197,303,261 → 198,293,083），證明是貨真價實的新 build。strings diff 顯示 3,701 條新增短字串全落在別處——Bun runtime stream builtin（`@putByIdDirectPrivate(readableStreamController…)`、HTTP「Parse Error」路徑）、workflow-VM sandbox（`attacker-reachable` clone walker）、feedback 回報 UI template——無一碰字元級 string tokenizer。這是 2.1.181 以來官方第 **7** 個有效改版（繼 2.1.183、185、186、187、190、191 後）仍未修 VH1。version-agnostic patcher 零腳本改動重套（`!l`→`!0`，1 byte；原廠 `f7513a30…` → patched `cadbe992…`），並在磁碟（bug 0／fix 1）、簽章、running session mmap inode（即本 session——patched dogfooding）、啟動時序四處驗證。

## 2026-06-25

### Changed

- re-check 2.1.190 與 2.1.191。2.1.187 之後，Claude Code 釋出 2.1.190（2026-06-24；188／189 跳號）與 2.1.191。兩者都是貨真價實的新 build（原廠 size 215,994,048 → 217,273,568 → 219,856,224；parser site 在 191 漂移到 197,303,261），且都把 site 凍結在 `,!l)n.push({type:"string",value:a})`，與 2.1.187 raw 逐字相同。strings diff 將成長歸因於 Bun runtime 升級（HTTP agent/proxy/tunnel、async_hooks）與 workflow/agent 子系統；2.1.191 的十八條 changelog（/rewind、background agents、sandbox、MCP retry、CPU −37%）無一碰 tool-call parser。2.1.190 是約 8 小時的短暫空窗——在 191 取代它之前從未 patch——191 則重新 patch 並以 byte／inode／啟動時序驗證。這是 2.1.181 以來官方第 **5**、**6** 個有效改版仍未修 VH1。（這兩版的公開 badge bump 併入 2026-06-26 條目。）

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
