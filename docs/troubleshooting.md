# Fix Roo Code Tool-Calling Errors With Ollama

This tutorial recreates the fix for this Roo Code error:

```text
The model provided text/reasoning but did not call any of the required tools.
```

There are two root causes — both must be fixed:

1. **Thinking mode** — Qwen3.5 models output `<think>...</think>` tokens during streaming, causing them to fall back to XML-format tool calls that Roo Code can't parse. Fixed with `/no_think` in the system prompt.
2. **Context window too small** — Roo Code's `num_ctx` setting defaults to 4096 when populated, overriding the Modelfile. Roo's system prompt alone is ~4k tokens. Fixed by leaving the field empty.

## 1. Confirm Ollama Is Running

```sh
ollama list
```

You should see your installed models. The required source model is:

```text
qwen3.5:9b
```

If Ollama is not running, start it:

```sh
ollama serve
```

## 2. Create The Roo-Friendly Modelfile

Create a file named `Modelfile.roo-qwen35-9b` with this content:

```text
FROM qwen3.5:9b

PARAMETER num_ctx 32768
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER presence_penalty 0

SYSTEM """/no_think
You are running inside Roo Code as a coding agent.
When tools are provided, respond by calling the appropriate tool.
Do not answer with plain conversational text when a tool is available and the task can be completed or needs clarification.
For greetings or completed trivial requests, use attempt_completion or ask_followup_question as appropriate.
"""
```

The `/no_think` token at the start of the system prompt disables Qwen3.5's thinking phase, preventing it from falling back to XML tool calls during streaming.

## 3. Build The Ollama Alias

```sh
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b
```

Confirm it exists:

```sh
ollama list
# qwen35-roo:9b should appear
```

## 4. Verify The Alias Settings

```sh
ollama show qwen35-roo:9b
```

Check for:

```text
Capabilities
  tools

Parameters
  num_ctx       32768
  temperature   0.7
```

## 5. Test Native Tool Calling

```sh
curl -s http://localhost:11434/api/chat \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen35-roo:9b",
    "stream": false,
    "messages": [{"role": "user", "content": "hello"}],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "attempt_completion",
          "description": "Present the final result to the user when the task is complete",
          "parameters": {
            "type": "object",
            "required": ["result"],
            "properties": {
              "result": {"type": "string", "description": "Final response to the user"}
            }
          }
        }
      },
      {
        "type": "function",
        "function": {
          "name": "ask_followup_question",
          "description": "Ask the user a question when more information is needed",
          "parameters": {
            "type": "object",
            "required": ["question"],
            "properties": {
              "question": {"type": "string", "description": "Question to ask the user"}
            }
          }
        }
      }
    ]
  }'
```

A good response contains a `tool_calls` field:

```json
"tool_calls": [
  {
    "function": {
      "name": "attempt_completion",
      "arguments": {"result": "Hello! How can I help you today?"}
    }
  }
]
```

If you only see plain text and no `tool_calls`, recreate the alias from step 3 and test again.

## 6. Configure Roo Code

1. Open Roo Code in VS Code.
2. Click the settings gear.
3. Set **API Provider** → `Ollama`
4. Set **Base URL** → `http://localhost:11434`
5. Set **Model ID** → `qwen35-roo:9b`
6. Leave **Context Window Size (num_ctx)** → **empty**
7. Save.

> **Critical:** Do not enter a value in the `num_ctx` field. Roo Code defaults it to 4096 when populated, overriding the Modelfile's 32768. Roo's system prompt is ~4k tokens — a 4096 context leaves no room for the actual task and causes immediate failures.

Test with `hello` — Roo should respond without looping.

## 7. Optional: Stop Large Test Models

```sh
ollama ps          # see what's loaded in memory
ollama stop qwen35-roo:9b   # free RAM without deleting the model
```

## Notes

- `qwen35-roo:9b` is the recommended model — 5/5 reliable native `tool_calls`, good code quality.
- `qwen35-roo:2b` is the low-RAM fallback — same fixes applied, smaller and faster.
- `qwen2.5-coder:7b` and `qwen2.5-coder:32b` do **not** work with Roo Code. They output JSON-formatted text instead of native `tool_calls`. They are fine for Continue (chat/autocomplete).
- `qwen3.5` available sizes on Ollama: `0.8b`, `2b`, `4b`, `9b`, `27b`, `35b`. There is no `7b`.
- The `num_ctx` field in Roo Code settings must be left empty — the Modelfile handles it.
