# VH1 Streaming Parser Bug — 修復方案評估

> 最後更新：2026-06-16
> 狀態：觀望中，Opus 4.6[1m] 規避。目標回 4.8 時啟動修復。

## 根因摘要

Claude Code CLI 的 streaming `input_json_delta` 累積器有四層 partial-JSON parser pipeline：

```
ng$ = JSON.parse(kH1(vH1(bFH(VH1(buffer)))))
```

| 層 | 函式 | 功能 |
|---|---|---|
| 1 | VH1 | 逐字元 tokenizer |
| 2 | bFH | tail trimmer（砍不完整的尾端 token）|
| 3 | vH1 | bracket closer（補缺的 `}`/`]`）|
| 4 | kH1 | 重組回 JSON string |

**核心 bug（VH1 string handler）**：buffer 在 JSON string 值中間斷裂時（closing `"` 未到），VH1 設 `Y=true` 然後**整個 string token 被靜默丟棄**。

```js
// 2.1.178 binary 實際代碼（minified）
if(K==='"'){
  let $="",Y=!1;
  K=H[++_];
  while(K!=='"'){
    if(_===H.length){Y=!0;break}   // buffer 到底，string 沒關
    if(K==="\\"){if(_++,_===H.length){Y=!0;break}$+=K+H[_],K=H[++_]}
    else $+=K,K=H[++_]
  }
  if(K=H[++_],!Y)q.push({type:"string",value:$});  // Y=true → 丟掉
  continue
}
```

**Cascade**：string 丟 → orphaned key 被 bFH 砍 → 多次 drop → 整個 object 變 `{}` → `JSON.parse("{}")` 成功 → `callTool({arguments: {}})` → per-tool cache 鎖死 → session 內同 tool 永遠送 `{}`。

**來源**：[#67765](https://github.com/anthropics/claude-code/issues/67765)（@in4mer 反編譯 2.1.173）
**主追蹤**：[#62123](https://github.com/anthropics/claude-code/issues/62123)（54+ comments, 0 staff）

---

## 修復方案

### A. Binary Patch — `!Y` → `!0`

**原理**：讓 VH1 永遠 push string token（含 partial），不再靜默丟棄。同 byte 長度替換。

**步驟**：
1. 定位 VH1 string handler：`strings -t d <binary> | grep 'Y=!0;break'`
2. 精確找到含 `if(K=H[++_],!Y)q.push` 的那一處（binary 有 3 處 `Y=!0;break`，需比對上下文確認是 VH1）
3. 將 `!Y` 替換為 `!0`（`59` → `30` in ASCII，或 minified 形式的等價替換）
4. 驗證 patch：用 regression fixture 跑截斷 JSON 測試

**Codex 評估**：locally sound。Partial string emit 後：
- bFH 仍可 trim trailing tokens
- vH1 仍可補 `}`/`]`
- kH1 會幫加 closing quote
- 結果是「截斷但有效的 string」取代「整個消失 → `{}`」

**風險**：
- 每次 `claude update` 需重做（版本鎖定）
- 3 處 `Y=!0;break` 要精確定位正確的那個
- 可能暴露 transient partial string 給假設「值完整」的下游邏輯
- 但 Codex 判斷：現行 `{}` cascade 的破壞性遠大於此風險

**自動化需求**：
- 寫 patch script，含 CLI version check + byte pattern verify + hash 驗證
- 寫 regression fixture：stream JSON 在每個 byte offset 截斷，assert 無 key/arg 消失

**2026-06-16 本地驗證結果**（`vh1-patch-test.mjs`，從 2.1.178 binary 抽出完整四層 pipeline）：

Phase 0 — 完整 JSON baseline：5/5 identical，patched 與 original 對完整輸入結果完全相同。

Phase 1 — 逐 byte 截斷（760 cut points）：

| 測試案例 | original `{}` | patched `{}` | 改善倍率 | patched 更差 |
|---|---|---|---|---|
| MCP tool args（232 pts）| 207 | 11 | 18.8× | **0** |
| CJK content（96 pts）| 73 | 11 | 6.6× | **0** |
| nested quotes（74 pts）| 57 | 11 | 5.2× | **0** |
| complete JSON（203 pts）| 21 | 8 | 2.6× | **0** |
| multi-key object（155 pts）| 11 | 5 | 2.2× | **0** |

**Regression = 0 / 760。Patched 從未比 original 更差。**

Phase 2 — 模擬 streaming delta：

| 案例 | chunk | original bad | patched bad |
|---|---|---|---|
| MCP tool args | 8B | 25/30（83%）| 1/30（3%）|
| MCP tool args | 16B | 12/15 | **0/15** |
| MCP tool args | 32B+ | 有 | **全 0** |
| CJK content | 8B | 9/13 | 1/13 |
| CJK content | 16B+ | 有 | **全 0** |

Phase 3 — Edge cases（patched 改善處，🔀 標記）：

```
cut at opening quote   → orig: {}  |  patched: {"content":""}
cut 1 char into value  → orig: {}  |  patched: {"content":"T"}
cut mid-value          → orig: {}  |  patched: {"content":"This is a lo"}
cut at escape sequence → orig: {}  |  patched: {"content":"line1\n"}
cut mid-escape         → orig: {}  |  patched: {"content":"line1"}
CJK mid-char           → orig: {}  |  patched: {"content":"中"}
```

結構性截斷（key 未完成、只有 `{`）兩者皆 `{}`，是正確行為。

**結論：Patch 邏輯安全。760 tests / 0 regression。下游 bFH→vH1→kH1 正確處理 partial string。**

patched 殘餘的 `{}` 來自兩類：(1) 截斷點在 key 內部（string 被 push 但 bFH 判定孤 value 移除）(2) 結構字元不足（只有 `{` 或 `{"a`）——皆為合理行為，非 patch 缺陷。

**優先級**：🟡 保留，C 不夠時再啟動。技術可行性已驗證。

---

### B. 提 PR — ❌ 死路

- repo 無 license、無 CONTRIBUTING.md
- 歷史 0 外部 PR 被 merge
- Issue 0 staff 回應已超過 3 週
- 結論：不可行

---

### C. MCP Server 端防禦

**原理**：在我們自己的 MCP server 加 argument validation，收到空/不合理 args 時回 hard error。斷的是 cascade 的第四環（per-tool cache）。

**實作清單**：

#### C1. Schema-aware rejection（核心）
```python
# FastMCP / Pydantic 範例
@server.tool()
async def append_entry(content: str, path: str):
    # Pydantic 自動驗證 required params
    # 收到 {} 時會 ValidationError → MCP error response
    ...
```
- 不是盲擋 `{}`，而是檢查 required params 是否存在
- 用 JSON Schema / Pydantic / Zod 嚴格驗證 argument types
- 回 hard validation error，**不要 soft fallback + default**

#### C2. Suspicious pattern detection
- 同 tool 之前收過完整 args，突然變 `{}` → 在 error message 中明確提示「疑似 streaming parser bug」
- 讓 model 知道這不是 user 錯誤，而是 client 端 bug

#### C3. Logging
- Log rejected args + tool name + timestamp
- 留證據供日後分析觸發頻率

#### C4. 危險操作額外守衛
- mutation/delete 類 tool 要求 explicit sentinel field（如 `confirm: true`）
- 避免 `{}` fallback 觸發破壞性操作

**範圍限制**：只保護我們自己的 MCP tools，built-in tools（Read/Edit/Bash 等）不受保護。

**優先級**：🟢 回 4.8 前先做

---

### D. 繼續 Opus 4.6[1m] — 現行方案

```bash
/model claude-opus-4-6[1m]
```

- 所有報告者共識 4.6 unaffected（#63583: Sonnet 4.6 = 0/2097，Opus 4.6 社群零報告）
- 1M context 無損
- 訂閱限額內含，不額外收費

**優先級**：🟢 現在

---

### E. Session Poison Detector Hook（Codex 建議，新增）

**原理**：不改 binary，用 Claude Code hook 偵測症狀。tool call 突然變 `{}` 時自動警告或 `/clear`。

**可能實作**：
- Hook 在 tool call 後檢查 MCP response 是否為 validation error pattern
- 連續 N 次同 tool 失敗 → 自動提示 user 做 `/clear`
- 比 binary patch 輕量，比 MCP 防禦更上游

**限制**：
- Hook 無法看到 tool call 的 arguments（只能看 tool name + result）
- 需要 MCP server 端配合（C 方案的 error message 做 marker）
- 對 built-in tools 無效

**優先級**：🟡 配合 C 一起做

---

### F. Wrapper CLI Shim（Codex 建議，存參考）

**原理**：在 Claude Code 外包一層 MCP traffic monitor，看到不可能的 arg shape 就 kill/restart。

**評估**：工程量大、維護成本高、需攔截 stdio/SSE。存為理論選項，不主動投入。

---

## 攔截點排序（Codex，最不脆弱→最脆弱）

| # | 位置 | 可行性 | 備註 |
|---|---|---|---|
| 1 | Patch bundled JS before execution | 低 | binary 內嵌 JS，無法獨立抽出 |
| 2 | Wrap parser function at module scope | 低 | minified，scope 不可達 |
| 3 | 攔截 JSON.parse 前的修復後 string | 低 | 同上 |
| 4 | Stream layer hold-back（未關閉 string 時暫不 parse）| 中 | 最乾淨的真修法，但需改更多代碼 |
| 5 | **Binary patch `!Y`→`!0`** | **中** | **我們的 A 方案** |
| 6 | Node monkey-patch / LD_PRELOAD | 低 | blast radius 太大，不建議 |

---

## 回退判定標準（2026-06-16 定義）

**測試條件**：切回 4.8，E+A 已部署，跑正常工作 session。觀察期：5 個完整工作 session 或 3 天，先到者為準。

| # | 指標 | 資料來源 | 回退觸發線 |
|---|---|---|---|
| 1 | E 攔截率 | evap-shield log | 攔截 > 0 且全攔住 = 繼續；hook 未觸發但 tool 異常 = 啟動 A |
| 2 | session 中毒 | 同 session 同 tool 連續 2+ 次被 E 攔截 | 1 次 = 啟動 A；2 次 = 回退 D |
| 3 | 不可恢復事件 | /clear 後仍異常，或 model retry loop 未被阻止 | 1 次 = 立即回退 D |

```
4.8 測試中
  ├─ 0 次 {} ──── 觀察期滿 → 留 4.8 ✅
  ├─ {} 出現，E 攔住 ── 繼續觀察
  ├─ E 攔不住或頻繁觸發 ── 啟動 A（binary patch）
  │   └─ patch 後仍漏 ── 回退 D
  ├─ session 中毒 ── 啟動 A
  │   └─ 第二次中毒 ── 回退 D
  └─ /clear 無法恢復 ── 立即回退 D
```

---

## 行動計畫（2026-06-16 更新）

**重新排序**：C（MCP 防禦）降為 optional guide，E+A 為通用主線。
原因：C 綁定在特定 MCP server（如 ccRecall），別人的環境沒有；E+A 是任何 Claude Code 用戶都能用的通用方案。

**關鍵發現**：PreToolUse hook 的 payload 包含 `tool_input`（完整 args），且 exit 2 可阻擋執行。FIX-PLAN 原本寫「hook 無法看到 tool call arguments」是錯的。這讓 E 從被動偵測器升級為主動攔截器，保護範圍涵蓋 built-in tools。

```
現在 ──────── D: Opus 4.6[1m] 觀望
                │
                ├── 持續追蹤 #62123 + #67765
                │
準備回 4.8 ──── E: evap-shield hook ✅ 完成
                │   PreToolUse 攔截器，20/20 測試通過
                │   攔 built-in + MCP tools 的 {} args
                │   連續 3+ 次升級 CRITICAL + terminal instruction
                │   一鍵安裝: bash install.sh
                │
                ├── A: binary patch script ✅ 完成
                │   自動定位 + patch + verify + backup/restore
                │   bash patch-vh1.sh [--dry-run | --restore]
                │
測試 4.8 ────── 裝 E → 切 4.8 → 觀察 5 session
                │   E 攔住 → 繼續
                │   E 擋不住 → 跑 A
                │
回退 ────────── D: Opus 4.6[1m]
                │
Anthropic 修了 → 驗證 → 移除 E+A → 留 4.8 ✅
```

### C: MCP 防禦（降為 optional guide）

C 對有自定義 MCP server 的人仍有價值，但非必要：
- ccRecall 已有 Zod schema validation，`{}` 本身會被 reject
- E 在上游攔截，C 是冗餘第二道防線
- 如果打包成 repo，可附 MCP middleware template 作為可選項

---

## 交付物（evap-shield/）

| 檔案 | 用途 |
|---|---|
| `evap-shield.sh` | PreToolUse hook 本體 |
| `install.sh` | 一鍵安裝到 ~/.claude/ |
| `test-evap-shield.sh` | 測試套件（20/20） |
| `patch-vh1.sh` | Binary patch 自動化（定位 + patch + verify + restore） |
| `FIX-PLAN.md` | 完整修復方案文件 |

---

## 相關資源

- Issue：[#67765](https://github.com/anthropics/claude-code/issues/67765)（根因 + 修法）、[#62123](https://github.com/anthropics/claude-code/issues/62123)（主追蹤）


