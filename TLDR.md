# Roo Code + Ollama Tool Calling — TL;DR

## Problem

Roo Code shows `MODEL_NO_TOOLS_USED` in a loop. The model responds with plain text or JSON text instead of calling a tool.

## Why It Happens

Two causes, both must be fixed:

1. **Wrong model** — Roo Code uses Ollama's native function calling API and reads `message.tool_calls`. Models that output JSON-formatted text instead are not compatible.
2. **Thinking mode** — Qwen3.5 models have a built-in thinking phase. During streaming it bleeds into the message content and causes the model to fall back to XML-format tool calls, which Roo Code can't parse.
3. **Context window too small** — Roo Code's settings UI has a `num_ctx` field that defaults to 4096, overriding the Modelfile. Roo's system prompt alone is ~4k tokens, leaving no room for the task.

## Which Models Work

| Model | Native `tool_calls` | Good for Roo |
|---|---|---|
| `qwen35-roo:9b` | ✅ 5/5 reliable | ✅ Recommended |
| `qwen35-roo:2b` | ✅ reliable | ✅ Low-RAM fallback |
| `qwen2.5:32b` | ✅ | ✅ Large general-purpose option |
| `qwen2.5-coder:7b` | ❌ outputs JSON text | ❌ |
| `qwen2.5-coder:32b` | ❌ outputs JSON text | ❌ |
| `deepseek-r1:8b` | ❌ empty response | ❌ |

## Fix

```sh
# 1. Pull the base model
ollama pull qwen3.5:9b

# 2. Create the Roo alias (includes /no_think and num_ctx 32768)
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b

# 3. In VS Code → Roo Code settings:
#    API Provider:            Ollama
#    Model ID:                qwen35-roo:9b
#    Context Window (num_ctx): leave EMPTY — let the Modelfile control it
```

## Key Files

| File | Purpose |
|---|---|
| `Modelfile.roo-qwen35-9b` | Roo-optimised alias for qwen3.5:9b (recommended) |
| `Modelfile.roo-qwen35-2b` | Roo-optimised alias for qwen3.5:2b (low-RAM fallback) |
| `docs/troubleshooting.md` | Full step-by-step guide with diagnostics |
