# Roo Code Setup

Roo Code is an agentic coding assistant — it reads files, writes code, and runs commands. It requires a model that emits **native tool calls** via the Ollama API. Most models do not do this reliably.

## Model

| Model | Notes |
|---|---|
| `qwen35-roo:9b` | ✅ Recommended. Reliable native tool calls, good quality. |
| `qwen35-roo:2b` | ⚠️ Fallback for low-RAM machines. Occasionally inconsistent. |

`qwen2.5-coder:7b` and `qwen2.5-coder:32b` do **not** work — they output JSON text instead of native tool calls, causing Roo to loop with `MODEL_NO_TOOLS_USED`.

## Create the Model Alias

Run once on each new machine:

```sh
ollama pull qwen3.5:9b
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b
```

For the low-RAM fallback:

```sh
ollama pull qwen3.5:2b
ollama create qwen35-roo:2b -f Modelfile.roo-qwen35-2b
```

## Configure Roo Code in VS Code

1. Click the Roo Code icon in the sidebar
2. Open settings (gear icon)
3. Set **API Provider** → `Ollama`
4. Set **Base URL** → `http://localhost:11434`
5. Set **Model ID** → `qwen35-roo:9b`

## Verify

```sh
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
  }' | python3 -c "
import sys, json
m = json.load(sys.stdin)['message']
print('OK' if m.get('tool_calls') else 'FAIL — no tool_calls in response')
"
```

Expected output: `OK`

## Why Not the Coder Models?

`qwen2.5-coder:7b` and `qwen2.5-coder:32b` are better at writing code but output tool calls as JSON text in the message body. Roo Code reads `message.tool_calls` — not message content — so it never sees the tool being used and loops forever.

The `qwen3.5` family uses the native function calling mechanism Roo Code requires.

## See Also

- `Modelfile.roo-qwen35-9b` — the recommended alias definition
- `Modelfile.roo-qwen35-2b` — the fallback alias definition
- `SETUP.md` — full machine setup including Continue
- `TLDR.md` — one-page model compatibility summary
- `roo-ollama-tool-calling-tutorial.md` — full diagnostic guide
