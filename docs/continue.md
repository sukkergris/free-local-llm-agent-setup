# Continue Setup

Continue is a VS Code extension that provides chat, tab autocomplete, and agent mode (file read/write). It runs entirely locally using Ollama.

---

## TL;DR — For Impatient Users

```sh
# 1. Pull models
ollama pull qwen3.5:9b
ollama pull qwen2.5-coder:7b
ollama pull starcoder2:3b

# 2. Build the agent alias (run from the repo root)
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b

# 3. Install the extension
code --install-extension continue.continue

# 4. Drop the config in place
cp config.json ~/.continue/config.json
```

**Critical:** Make sure `~/.continue/config.yaml` does NOT exist — if it does, delete it. It breaks Continue silently.

Open VS Code, open the Continue panel, select **Qwen 3.5 9B (Agent)** from the model picker. Type a message — it should respond. Agent mode (file read/write) works with that model.

**If something breaks:** read the Issues section at the bottom of this file.

---

## Models

| Model | Role | RAM |
|---|---|---|
| `qwen35-roo:9b` | Agent + chat | ~6 GB |
| `qwen2.5-coder:7b` | Chat — fast | ~5 GB |
| `qwen2.5-coder:32b` | Chat — balanced, best quality | ~20 GB |
| `starcoder2:3b` | Tab autocomplete | ~2 GB |

```sh
ollama pull qwen3.5:9b          # agent model base
ollama pull qwen2.5-coder:7b
ollama pull qwen2.5-coder:32b   # optional, needs 20 GB RAM
ollama pull starcoder2:3b
```

---

## Config File

The active config is `~/.continue/config.json`. The file hot-reloads on save — no VS Code restart needed.

> **Note:** Continue v1.x introduced `config.yaml` but in practice `config.json` is what the extension reads. If you create `config.yaml` and models don't appear, edit `config.json` instead.

### Full config (`~/.continue/config.json`)

```json
{
  "models": [
    {
      "title": "Qwen 3.5 9B (Agent)",
      "model": "qwen35-roo:9b",
      "provider": "ollama",
      "contextLength": 32768,
      "requestOptions": {
        "num_ctx": 32768,
        "num_predict": 2048,
        "temperature": 0.7
      }
    },
    {
      "title": "Qwen 2.5 Coder 7B (Fast)",
      "model": "qwen2.5-coder:7b",
      "provider": "ollama",
      "contextLength": 32768,
      "requestOptions": {
        "num_ctx": 32768,
        "num_predict": 2048,
        "temperature": 0.1
      }
    },
    {
      "title": "Qwen 2.5 Coder 32B (Balanced)",
      "model": "qwen2.5-coder:32b",
      "provider": "ollama",
      "contextLength": 12288,
      "requestOptions": {
        "num_ctx": 12288,
        "num_predict": 2048,
        "temperature": 0.1
      }
    }
  ],
  "tabAutocompleteModel": {
    "title": "Starcoder 3b",
    "provider": "ollama",
    "model": "starcoder2:3b"
  },
  "embeddingsProvider": {
    "provider": "transformers.js"
  }
}
```

---

## Agent Mode

Agent mode lets Continue read and write files, create new files, and run terminal commands directly from chat.

### Enable it

Add `capabilities: [tool_use]` to a model entry. The `qwen35-roo:9b` alias is the recommended agent model — it uses Qwen3.5 with `/no_think` and a system prompt tuned for tool use. Without that alias, agent mode is unreliable.

### How to use it

Select **Qwen 3.5 9B (Agent)** in the model picker, then ask it to do something to a file:

```
Read src/main.ts and add error handling to the fetchUser function
```

Continue will call `read_file`, show you the tool call, and apply the edit.

### Built-in tools

`read_file` · `write_file` · `create_new_file` · `run_terminal_command` · `ls`

---

## Tab Autocomplete

`starcoder2:3b` handles inline suggestions. No extra config needed — it's wired up via `tabAutocompleteModel` in `config.json`.

If suggestions aren't appearing: check that the model is pulled (`ollama list`) and that Continue is enabled in the VS Code status bar.

---

## Issues We Ran Into

### 1. `config.yaml` breaks Continue entirely — delete it if it exists

**Symptom:** Continue shows a blank setup screen ("Setup Chat model", "Setup Autocomplete model") with no models at all, even though `config.json` is valid.

**Cause:** If `~/.continue/config.yaml` exists, the new Continue version chokes on it silently — even if the YAML is valid — and shows the empty setup UI instead of reading `config.json`.

**Fix:**

```sh
rm ~/.continue/config.yaml
# or rename it to keep a backup:
mv ~/.continue/config.yaml ~/.continue/config.yaml.bak
```

Then reload VS Code (`Cmd+Shift+P` → **Developer: Reload Window**). Models come back immediately.

Always use `config.json` only. Do not create `config.yaml`.

### 2. `contextLength` must match `num_ctx`

`contextLength` in the config tells Continue when to start trimming conversation history. Ollama's actual context window is set by `num_ctx` in the Modelfile. If `contextLength` is larger than `num_ctx`, Continue won't trim in time — Ollama silently cuts off tokens mid-context and responses start losing history without any error.

The 32B models are capped at `12288` despite being capable of more, to keep RAM usage manageable. The `contextLength` in the config must match that value.

Wrong:
```yaml
defaultCompletionOptions:
  contextLength: 128000   # too big — Ollama is only using 12288
```

Right:
```yaml
defaultCompletionOptions:
  contextLength: 12288
```

### 3. Agent mode doesn't work with `qwen2.5-coder` models

Continue manages tool use through its own layer, so `qwen2.5-coder` models work fine for chat and autocomplete. But for multi-step agent tasks (file edits, chained tool calls), they fall through. Use `qwen35-roo:9b` for agent mode.

The `qwen35-roo` alias is the same model used by Roo Code — built from `qwen3.5:9b` with `/no_think` in the system prompt and `num_ctx 32768`. See `SETUP.Models.md` for how it's built.

### 4. `create_new_file` custom command looks broken but isn't

In `config.json`, custom commands can use an `arguments` field instead of a `prompt` field to call built-in Continue agent actions. This is valid syntax — Continue renders it as a tool call block with an Apply button. It is not a broken command.

---

## See Also

- `../Modelfile.roo-qwen35-9b` — the agent alias definition
- `models.md` — how Modelfiles work, `/no_think` explanation
- `roo-code.md` — Roo Code setup (shares the same model alias)
- `agent-context/continue.md` — full agent context document for LLM assistants
- `../TLDR.md` — one-page model compatibility summary
