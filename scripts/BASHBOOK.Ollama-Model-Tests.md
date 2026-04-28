# Bashbook: Ollama Model Tests

This bashbook gives you repeatable commands for testing the local Ollama models you use with Roo Code and Continue.

It covers three things:

- Speed: output tokens per second and per minute
- Quality: save each model response to a file so you can compare answers
- Tool calling: check whether a model returns native `message.tool_calls`

## Quick Start

Open the BashBook notebook in VS Code and run the cells:

```text
test-ollama-models.bashbook
```

The `.bashbook` file is a VS Code notebook file, not a shell script. If you want to run tests from a terminal, use the script directly.

Run the default model set from a terminal:

```sh
./scripts/test-ollama-models.sh
```

Run one model:

```sh
./scripts/test-ollama-models.sh qwen35-roo:9b
```

Compare several models:

```sh
./scripts/test-ollama-models.sh qwen35-roo:9b qwen35-roo:2b qwen2.5-coder:7b qwen2.5-coder:32b
```

Results are written under:

```text
output/model-tests/
```

Each run creates:

- `results.csv` with speed and tool-call metrics
- one `.txt` response file per model
- one `.json` raw Ollama response per model
- one `.tool.json` raw tool-call test response per model, unless disabled

## Test Different Workloads

Use `TASK` to pick a coding workload:

```sh
TASK=csharp ./scripts/test-ollama-models.sh qwen35-roo:9b
TASK=bash ./scripts/test-ollama-models.sh qwen35-roo:9b
TASK=elm ./scripts/test-ollama-models.sh qwen35-roo:9b
TASK=dockerfile ./scripts/test-ollama-models.sh qwen35-roo:9b
TASK=compose ./scripts/test-ollama-models.sh qwen35-roo:9b
```

Use `TASK=short` for a tiny sanity check:

```sh
TASK=short NUM_PREDICT=64 ./scripts/test-ollama-models.sh qwen35-roo:2b
```

Use a fully custom prompt:

```sh
TASK=custom PROMPT="Write an Elm decoder for a user profile JSON object." ./scripts/test-ollama-models.sh qwen35-roo:9b
```

## Tune Runtime Options

Limit output length:

```sh
NUM_PREDICT=128 ./scripts/test-ollama-models.sh qwen35-roo:9b
```

Set temperature:

```sh
TEMPERATURE=0.2 ./scripts/test-ollama-models.sh qwen35-roo:9b
```

Override context size for this request:

```sh
NUM_CTX=8192 ./scripts/test-ollama-models.sh qwen35-roo:9b
```

Leave `NUM_CTX` unset when you want Ollama to use the model alias defaults from the Modelfile. For `qwen35-roo:9b`, that means `num_ctx 32768`.

Disable the native tool-call test:

```sh
TOOL_TEST=0 ./scripts/test-ollama-models.sh qwen2.5-coder:7b
```

## Read The Numbers

The script prints a compact table:

```text
model                         task          out_tok      tok/s    tok/min tool_calls
qwen35-roo:9b                 csharp            256      38.20       2292 yes:attempt_completion
```

Important fields:

- `out_tok`: generated output tokens
- `tok/s`: generated output tokens per second
- `tok/min`: generated output tokens per minute
- `tool_calls`: whether `/api/chat` returned native `message.tool_calls`

For Roo Code, `tool_calls` should be `yes:...`.

For Continue chat/autocomplete, native tool calls matter less, because Continue can manage some tool use itself. For Roo Code, native tool calls are critical.

## Manual One-Off Speed Test

You can also use Ollama directly:

```sh
ollama run --verbose qwen35-roo:9b "Write a compact Dockerfile for a C# app."
```

Look for:

```text
eval rate: 42.00 tokens/s
```

Then:

```text
tokens/min = eval rate * 60
```

## Manual Native Tool-Call Test

This checks whether the model returns native `message.tool_calls` through Ollama's chat API:

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
  }' | python3 -c '
import sys, json
m = json.load(sys.stdin).get("message", {})
calls = m.get("tool_calls") or []
print("OK" if calls else "FAIL")
print(calls)
'
```

## Useful Model Sets

Roo Code candidates:

```sh
./scripts/test-ollama-models.sh qwen35-roo:9b qwen35-roo:2b qwen2.5:32b
```

Continue chat candidates:

```sh
./scripts/test-ollama-models.sh qwen35-roo:9b qwen2.5-coder:7b qwen2.5-coder:32b qwen2.5:32b
```

Autocomplete sanity check:

```sh
TASK=short NUM_PREDICT=64 TOOL_TEST=0 ./scripts/test-ollama-models.sh starcoder2:3b
```

## Before Testing

Check what is installed:

```sh
ollama list
```

Check what is currently loaded in memory:

```sh
ollama ps
```

Free a loaded model without deleting it:

```sh
ollama stop qwen35-roo:9b
```
