# Fix Roo Code Tool-Calling Errors With Ollama

This tutorial recreates the fix for this Roo Code error:

```text
The model provided text/reasoning but did not call any of the required tools.
```

The short version: Roo Code requires the model to call a tool such as `attempt_completion` or `ask_followup_question`. Many models respond in plain text or JSON text instead, which makes Roo retry and get stuck. The fix is to use a model from the `qwen3.5` family and create a Roo-friendly Ollama alias with a pinned context window and a stricter system instruction.

## 1. Confirm Ollama Is Running

Run:

```sh
ollama list
```

You should see your installed models. In this setup, the important source model is:

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

SYSTEM """
You are running inside Roo Code as a coding agent.
When tools are provided, respond by calling the appropriate tool.
Do not answer with plain conversational text when a tool is available and the task can be completed or needs clarification.
For greetings or completed trivial requests, use attempt_completion or ask_followup_question as appropriate.
"""
```

## 3. Build The Ollama Alias

Run this from the same folder as the Modelfile:

```sh
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b
```

Then confirm it exists:

```sh
ollama list
# qwen35-roo:9b should appear
```

## 4. Verify The Alias Settings

Run:

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

Run this command:

```sh
curl -s http://localhost:11434/api/chat \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen35-roo:9b",
    "stream": false,
    "messages": [
      {
        "role": "user",
        "content": "hello"
      }
    ],
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
              "result": {
                "type": "string",
                "description": "Final response to the user"
              }
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
              "question": {
                "type": "string",
                "description": "Question to ask the user"
              }
            }
          }
        }
      }
    ]
  }'
```

A good response contains a real `tool_calls` field, similar to:

```json
"tool_calls": [
  {
    "function": {
      "name": "attempt_completion",
      "arguments": {
        "result": "Hello! How can I help you today?"
      }
    }
  }
]
```

If you only see normal chat text and no `tool_calls`, recreate the alias from step 3 and test again.

## 6. Configure Roo Code

In VS Code:

1. Open Roo Code.
2. Click the settings gear.
3. Set `API Provider` to `Ollama`.
4. Set `Base URL` to:

```text
http://localhost:11434
```

5. Set `Model ID` to:

```text
qwen35-roo:9b
```

6. Start a new Roo task and test with:

```text
hello
```

Roo should no longer loop on the "did not use a tool" diagnostic.

## 7. Optional: Stop Large Test Models

If you loaded a large model while testing, check what is still running:

```sh
ollama ps
```

Stop a loaded model if needed:

```sh
ollama stop qwen35-roo:9b
```

This only frees runtime memory. It does not delete the model.

## Notes

- `qwen35-roo:9b` is the recommended model — reliably emits native `tool_calls` (5/5 in testing) and produces good quality responses. Use `Modelfile.roo-qwen35-9b` to create it.
- `qwen35-roo:2b` is a low-RAM fallback — occasionally produces plain text instead of tool calls under load.
- `qwen2.5-coder:7b` and `qwen2.5-coder:32b` do **not** work with Roo Code — they output JSON-formatted text instead of native `tool_calls`, causing the `MODEL_NO_TOOLS_USED` error. They are fine for Continue (chat/autocomplete).
- `qwen2.5:32b` also supports native `tool_calls` if you need a large general-purpose model.
- The `num_ctx 32768` setting is important for coding-agent workflows.
- `qwen3.5` only comes in specific sizes on Ollama. As of testing: `0.8b`, `2b`, `4b`, `9b`, `27b`, `35b`. There is no `7b`.
