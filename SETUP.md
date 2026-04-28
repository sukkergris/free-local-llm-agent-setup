# Roo Code + Ollama — New Machine Setup

## Prerequisites

- macOS (Apple Silicon or Intel)
- VS Code installed
- Homebrew installed

---

## 1. Install Ollama

```sh
brew install ollama
```

Start the service:

```sh
ollama serve
```

To have it start automatically on login:

```sh
brew services start ollama
```

---

## 2. Pull Models

### Required (Roo Code agent)

```sh
ollama pull qwen3.5:9b
```

### Optional (low-RAM fallback for Roo Code)

```sh
ollama pull qwen3.5:2b
```

### Optional (coding autocomplete in Continue)

```sh
ollama pull starcoder2:3b
```

### Optional (extra chat models for Continue)

```sh
ollama pull qwen2.5-coder:7b
ollama pull qwen2.5-coder:32b
ollama pull qwen2.5:32b
```

---

## 3. Create the Roo-Optimised Model Aliases

Clone or copy this repo, then run from its root:

```sh
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b
ollama create qwen35-roo:2b -f Modelfile.roo-qwen35-2b   # optional fallback
```

Verify:

```sh
ollama list
# qwen35-roo:9b should appear
```

---

## 4. Install VS Code Extensions

```sh
code --install-extension rooveterinaryinc.roo-cline
code --install-extension continue.continue
```

---

## 5. Configure Roo Code

1. Open VS Code and click the Roo Code icon in the sidebar.
2. Click the **settings gear**.
3. Set **API Provider** → `Ollama`
4. Set **Base URL** → `http://localhost:11434`
5. Set **Model ID** → `qwen35-roo:9b`
6. Leave **Context Window Size (num_ctx)** → **empty**
7. Save.

> **Critical:** Leave the `num_ctx` field empty. If populated, Roo Code overrides the Modelfile's `num_ctx 32768` with 4096 — barely enough for Roo's system prompt, causing immediate failures.

Test with a simple prompt like `hello` — Roo should respond without the `MODEL_NO_TOOLS_USED` error.

---

## 6. Configure Continue

Copy `~/.continue/config.yaml` from this repo, or see `SETUP.Continue.md` for the full config and setup steps.

Continue v1.x uses `config.yaml` — not `config.json`. If both exist, `config.yaml` takes precedence.

---

## Verify Everything Works

```sh
# Ollama is running
curl http://localhost:11434/api/tags

# Model alias exists and uses native tool calls
curl -s http://localhost:11434/api/chat \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen35-roo:9b",
    "stream": false,
    "messages": [{"role": "user", "content": "hello"}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "attempt_completion",
        "description": "Present the final result",
        "parameters": {
          "type": "object",
          "required": ["result"],
          "properties": {"result": {"type": "string"}}
        }
      }
    }]
  }' | python3 -c "import sys,json; m=json.load(sys.stdin)['message']; print('OK' if m.get('tool_calls') else 'FAIL — no tool_calls in response')"
```

Expected output: `OK`

---

## File Reference

| File | Purpose |
|---|---|
| `Modelfile.roo-qwen35-9b` | Roo alias for qwen3.5:9b — recommended daily driver |
| `Modelfile.roo-qwen35-2b` | Roo alias for qwen3.5:2b — low-RAM fallback |
| `SETUP.RooCode.md` | Roo Code-specific setup and gotchas |
| `SETUP.Continue.md` | Continue-specific setup, agent mode, and issues |
| `SETUP.Models.md` | How the Modelfiles work and all model explanations |
| `TLDR.md` | One-page summary of model compatibility findings |
| `roo-ollama-tool-calling-tutorial.md` | Full diagnostic guide |
