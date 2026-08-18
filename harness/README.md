# Reproduction harness

Zero-cost, offline reproduction of everything claimed in this repository's
[retraction](../README.md#retracted). A fake Anthropic API server constructs the exact
SSE stream you want, so failure modes that are intermittent in production become
deterministic — no API key, no cost, no waiting for the bug to show up.

This is the one part of the project that survived its own conclusions being wrong.
It is also what refuted them.

## Getting any Claude Code version

Official builds are downloadable by version, which makes red/green testing across the
fix window possible without relying on local backups:

```
https://downloads.claude.ai/claude-code-releases/{version}/darwin-arm64/claude
https://downloads.claude.ai/claude-code-releases/stable          # returns current stable version
```

## 1. `fake_api_truncation.py` — malformed / truncated tool input

Splits a tool call's JSON arguments into deltas and cuts the stream mid-value.

```bash
PROBE_MODE=truncate python3 fake_api_truncation.py 8790 /tmp/api.log 3
# modes: cut (connection drop) | hang (stall for client abort) | truncate (clean max_tokens cut)
# last arg = how many deltas to send before cutting

HOME=/tmp/sandbox CLAUDE_CONFIG_DIR=/tmp/sandbox/.claude \
ANTHROPIC_BASE_URL=http://127.0.0.1:8790 ANTHROPIC_API_KEY=fake \
  /path/to/claude -p "run something"
```

Result — the fix window, measured:

| version | tool input received by the model |
|---|---|
| 2.1.173 | `{}` — silent, no error |
| 2.1.181 | `{"__unparsedToolInput":{"raw":"...","len":60}}` — raw bytes preserved, retry triggered |
| 2.1.233 | same as 2.1.181 |

Official 2.1.233 and a 2.1.233 patched by `patch-vh1.sh` produce **byte-identical** output.

## 2. `fake_api_missing_block.py` — a `tool_use` block that goes missing

Five variants of "the model said it would use a tool and didn't."

```bash
./run.sh /path/to/claude silentdrop 8801 mytag
# modes: dropblock | halfblock | emptyblock | silentdrop | partialdrop
```

Results are identical on 2.1.173 and 2.1.233 — this path was never broken, never fixed:

| variant | stream | client response | detected |
|---|---|---|---|
| `dropblock` | `stop_reason=tool_use`, no block | `Your tool call was malformed and could not be parsed. Please retry.` | yes |
| `halfblock` | `content_block_start` then nothing | same | yes |
| `emptyblock` | complete block, `input={}` | `InputValidationError: The required parameter \`command\` is missing` | yes |
| `silentdrop` | prose announces a tool call, `stop_reason=end_turn`, no block | **nothing** — `num_turns=1`, `is_error=false`, no retry | **no** |
| `partialdrop` | announces three calls, emits one | **first one runs**, the others vanish silently | **no** |

The line is clean: protocol-inconsistent streams are caught and reported back to the
model; protocol-valid ones are structurally undetectable, because from the client's
side nothing is wrong.

## Two things that will waste your time

- **Session title generation eats the first request.** Claude Code fires an auxiliary
  request before the real turn. It carries no `tools`, so gate on `len(req['tools']) > 0`
  to find the actual conversation.
- **macOS has no `timeout`/`gtimeout`.** `run.sh` uses a background watchdog
  (`sleep N; kill -9`) instead.

## What this cannot show

The server is fake. Why a real model would emit `silentdrop` or `partialdrop` is not
observable here, and neither is how often any of this happens in practice. These
scripts establish what a client does with a given stream — nothing about incidence.
