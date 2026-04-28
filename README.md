# Local AI Coding with Roo Code + Continue + Ollama

Run a fully local AI coding assistant on macOS using [Ollama](https://ollama.com), [Roo Code](https://marketplace.visualstudio.com/items?itemName=rooveterinaryinc.roo-cline), and [Continue](https://continue.dev) — no API keys, no cloud.

The key finding: most Ollama models fail silently in Roo Code because they output JSON text instead of native tool calls. This repo documents exactly which models work, why, and how to fix the ones that almost work.

---

## Quick Start

```sh
# 1. Install Ollama
brew install ollama && brew services start ollama

# 2. Pull models
ollama pull qwen3.5:9b
ollama pull starcoder2:3b        # tab autocomplete in Continue

# 3. Build the Roo-compatible alias (from this repo's root)
ollama create qwen35-roo:9b -f Modelfile.roo-qwen35-9b

# 4. Install VS Code extensions
code --install-extension rooveterinaryinc.roo-cline
code --install-extension continue.continue
```

Then set Roo Code to use `qwen35-roo:9b` via Ollama, and leave the `num_ctx` field **empty**.

Full instructions: [docs/setup.md](docs/setup.md)

---

## Model Compatibility

| Model | Roo Code | Continue chat | Continue autocomplete |
|---|---|---|---|
| `qwen35-roo:9b` | ✅ Recommended | ✅ Agent mode | — |
| `qwen35-roo:2b` | ✅ Low-RAM fallback | ✅ | — |
| `qwen2.5-coder:32b` | ❌ | ✅ Best quality | — |
| `qwen2.5-coder:7b` | ❌ | ✅ Fast | — |
| `starcoder2:3b` | ❌ | — | ✅ |

`qwen35-roo` models are custom aliases — not base models. They add `/no_think` and `num_ctx 32768` on top of `qwen3.5:9b`.

One-page summary: [TLDR.md](TLDR.md)

---

## What's in This Repo

### Setup Guides (`docs/`)

| File | What it covers |
|---|---|
| [docs/setup.md](docs/setup.md) | Full new-machine setup (Ollama + Roo Code + Continue) |
| [docs/roo-code.md](docs/roo-code.md) | Roo Code configuration and gotchas |
| [docs/continue.md](docs/continue.md) | Continue configuration, agent mode, and known issues |
| [docs/models.md](docs/models.md) | How Modelfiles work, `/no_think` explained |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Step-by-step diagnostic guide for `MODEL_NO_TOOLS_USED` |

### LLM Context Documents (`docs/agent-context/`)

Markdown files intended to be loaded as system context into an LLM assistant — they describe the working configuration and common failure modes so the assistant can help debug setup issues.

| File | Covers |
|---|---|
| [docs/agent-context/roo-code.md](docs/agent-context/roo-code.md) | Roo Code + Ollama setup knowledge |
| [docs/agent-context/continue.md](docs/agent-context/continue.md) | Continue + Ollama setup knowledge |

### Modelfiles

| File | Purpose |
|---|---|
| `Modelfile.roo-qwen35-9b` | Roo-optimised alias for `qwen3.5:9b` — recommended |
| `Modelfile.roo-qwen35-2b` | Roo-optimised alias for `qwen3.5:2b` — low-RAM fallback |

### Scripts (`scripts/`)

Test and benchmark local Ollama models for speed and native tool-call support.

```sh
# Run default model set
./scripts/test-ollama-models.sh

# Test a specific model with a task
TASK=csharp ./scripts/test-ollama-models.sh qwen35-roo:9b
TASK=bash   ./scripts/test-ollama-models.sh qwen35-roo:9b
TASK=elm    ./scripts/test-ollama-models.sh qwen35-roo:9b
```

See [scripts/BASHBOOK.Ollama-Model-Tests.md](scripts/BASHBOOK.Ollama-Model-Tests.md) for full usage.
