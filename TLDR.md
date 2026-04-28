# Roo Code + Ollama Tool Calling — TL;DR

## Problem

Roo Code shows `MODEL_NO_TOOLS_USED` in a loop. The model responds with plain text or JSON text instead of calling a tool.

## Why It Happens

Roo Code uses Ollama's native function calling API and reads `message.tool_calls` from the response. Models that output JSON-formatted text in `message.content` to simulate tool calls are **not compatible**.

## Which Models Work

| Model | Native `tool_calls` | Good for Roo |
|---|---|---|
| `qwen35-roo:9b` | ✅ 5/5 reliable | ✅ Recommended |
| `qwen35-roo:2b` | ✅ but inconsistent | ⚠️ Fallback (low RAM) |
| `qwen2.5:32b` | ✅ | ✅ If you need large/general |
| `qwen2.5-coder:7b` | ❌ outputs JSON text | ❌ |
| `qwen2.5-coder:32b` | ❌ outputs JSON text | ❌ |
| `deepseek-r1:8b` | ❌ empty response | ❌ |

## Fix

```sh
# 1. Pull the base model
ollama pull qwen3.5:9b

# 2. Create the Roo alias
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b

# 3. In VS Code → Roo Code settings:
#    API Provider: Ollama
#    Model ID:     qwen35-roo:9b
```

## Key Files

| File | Purpose |
|---|---|
| `Modelfile.roo-qwen35-9b` | Roo-optimised alias for qwen3.5:9b (recommended) |
| `Modelfile.roo-qwen35-2b` | Roo-optimised alias for qwen3.5:2b (low-RAM fallback) |
| `roo-ollama-tool-calling-tutorial.md` | Full step-by-step guide with diagnostics |
