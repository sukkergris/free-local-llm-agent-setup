# How the Roo Models Were Created

The base `qwen3.5` models from Ollama work but are not tuned for Roo Code out of the box — they sometimes respond with plain text instead of calling a tool. The fix is to layer a system prompt and pinned parameters on top using an Ollama Modelfile, then register it as a named alias.

## The Modelfile

A Modelfile has two parts:

**`FROM`** — which base model to build on top of:
```
FROM qwen3.5:9b
```

**`PARAMETER`** — runtime settings baked into the alias:
```
PARAMETER num_ctx 32768    # context window — keep large for code tasks
PARAMETER temperature 0.7  # some creativity, not too random
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER presence_penalty 0
```

**`SYSTEM`** — a system prompt injected into every conversation:
```
SYSTEM """/no_think
You are running inside Roo Code as a coding agent.
When tools are provided, respond by calling the appropriate tool.
Do not answer with plain conversational text when a tool is available...
"""
```

The `/no_think` prefix is a Qwen3 special token that disables the model's thinking phase. Without it, the model outputs `<think>...</think>` reasoning tokens before responding, which causes it to fall back to XML-format tool calls instead of native function calling — breaking Roo Code.

The base model weights are **not modified**. `ollama create` layers metadata on top of the existing model — no fine-tuning involved.

## Creating the Aliases

Pull the base models first:

```sh
ollama pull qwen3.5:9b
ollama pull qwen3.5:2b
```

Then create the aliases from the Modelfiles in this repo:

```sh
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b
ollama create qwen35-roo:2b -f Modelfile.roo-qwen35-2b
```

Verify both exist:

```sh
ollama list
```

## The Two Roo Models

| Alias | Base | Use for |
|---|---|---|
| `qwen35-roo:9b` | `qwen3.5:9b` | Code tasks — recommended daily driver |
| `qwen35-roo:2b` | `qwen3.5:2b` | Quick/small tasks — low-RAM fallback |

## The Continue Models

These are used by the Continue extension for chat and autocomplete. They do **not** need a Modelfile — Continue talks to them directly via the Ollama provider. They don't work with Roo Code (output JSON text instead of native tool calls).

Pull them:

```sh
ollama pull qwen2.5-coder:32b
ollama pull qwen2.5-coder:7b
ollama pull qwen2.5:32b
ollama pull starcoder2:3b
```

| Model | Use for |
|---|---|
| `qwen2.5-coder:32b` | Continue chat — balanced quality |
| `qwen2.5-coder:7b` | Continue chat — fast |
| `qwen2.5:32b` | Continue chat — general purpose |
| `starcoder2:3b` | Continue tab autocomplete |

## Rebuilding After Changes

If you edit a Modelfile, re-run `ollama create` to apply the changes:

```sh
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b
```

The old alias is replaced in place. No need to `ollama rm` first.
