#!/usr/bin/env bash
set -euo pipefail

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
TASK="${TASK:-csharp}"
PROMPT="${PROMPT:-}"
NUM_PREDICT="${NUM_PREDICT:-256}"
NUM_CTX="${NUM_CTX:-}"
TEMPERATURE="${TEMPERATURE:-0.2}"
TOOL_TEST="${TOOL_TEST:-1}"
RUN_DIR="${RUN_DIR:-output/model-tests/$(date +%Y%m%d-%H%M%S)}"

if [[ "$#" -gt 0 ]]; then
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
Usage:
  ./scripts/test-ollama-models.sh [model ...]

Examples:
  ./scripts/test-ollama-models.sh
  ./scripts/test-ollama-models.sh qwen35-roo:9b
  TASK=elm ./scripts/test-ollama-models.sh qwen35-roo:9b qwen35-roo:2b
  TASK=custom PROMPT="Write a Dockerfile for a .NET API." ./scripts/test-ollama-models.sh qwen35-roo:9b

Environment:
  OLLAMA_URL    Default: http://localhost:11434
  TASK          csharp, bash, elm, dockerfile, compose, short, custom
  PROMPT        Required when TASK=custom
  NUM_PREDICT   Default: 256
  NUM_CTX       Default: unset, so the model default is used
  TEMPERATURE   Default: 0.2
  TOOL_TEST     Default: 1
  RUN_DIR       Default: output/model-tests/<timestamp>
EOF
    exit 0
  fi
  MODELS=("$@")
else
  MODELS=("qwen35-roo:9b" "qwen35-roo:2b" "qwen2.5-coder:7b")
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

safe_name() {
  printf '%s' "$1" | tr '/:' '__' | tr -c 'A-Za-z0-9_.-' '_'
}

prompt_for_task() {
  case "$TASK" in
    csharp)
      cat <<'EOF'
Write a compact C# 12 example with:
- a User record
- an EmailAddress value object
- validation that returns clear error messages
- two xUnit tests
Return code only.
EOF
      ;;
    bash)
      cat <<'EOF'
Write a production-friendly Bash script that:
- uses set -euo pipefail
- parses --source and --target flags
- validates required arguments
- logs actions with timestamps
- supports --dry-run
Return code only.
EOF
      ;;
    elm)
      cat <<'EOF'
Write Elm code that defines:
- a User alias
- a JSON decoder for User
- a Msg type
- an update function for loading success and failure
Return code only.
EOF
      ;;
    dockerfile)
      cat <<'EOF'
Write a multi-stage Dockerfile for a .NET 8 web API.
It should restore, build, publish, run as a non-root user, expose port 8080, and include a healthcheck.
Return code only.
EOF
      ;;
    compose)
      cat <<'EOF'
Write a docker-compose.yml for:
- a .NET 8 web API
- Postgres
- a named database volume
- healthchecks
- environment variables
- service dependency conditions
Return YAML only.
EOF
      ;;
    short)
      cat <<'EOF'
Write one concise C# method that checks whether a string looks like an email address. Return code only.
EOF
      ;;
    custom)
      if [[ -z "$PROMPT" ]]; then
        echo "TASK=custom requires PROMPT='...'" >&2
        exit 1
      fi
      printf '%s\n' "$PROMPT"
      ;;
    *)
      echo "Unknown TASK: $TASK" >&2
      echo "Valid tasks: csharp, bash, elm, dockerfile, compose, short, custom" >&2
      exit 1
      ;;
  esac
}

build_generate_payload() {
  local model="$1"
  local prompt="$2"
  python3 - "$model" "$prompt" "$NUM_PREDICT" "$TEMPERATURE" "$NUM_CTX" <<'PY'
import json
import sys

model, prompt, num_predict, temperature, num_ctx = sys.argv[1:6]
options = {
    "num_predict": int(num_predict),
    "temperature": float(temperature),
}
if num_ctx:
    options["num_ctx"] = int(num_ctx)

print(json.dumps({
    "model": model,
    "prompt": prompt,
    "stream": False,
    "options": options,
}))
PY
}

build_tool_payload() {
  local model="$1"
  python3 - "$model" <<'PY'
import json
import sys

model = sys.argv[1]
print(json.dumps({
    "model": model,
    "stream": False,
    "messages": [{"role": "user", "content": "hello"}],
    "tools": [{
        "type": "function",
        "function": {
            "name": "attempt_completion",
            "description": "Present the final result",
            "parameters": {
                "type": "object",
                "required": ["result"],
                "properties": {"result": {"type": "string"}},
            },
        },
    }],
}))
PY
}

extract_tool_result() {
  local file="$1"
  python3 - "$file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception as exc:
    print(f"error:{exc}")
    raise SystemExit(0)

if data.get("error"):
    print("error:" + str(data["error"])[:80])
    raise SystemExit(0)

calls = (data.get("message") or {}).get("tool_calls") or []
if not calls:
    print("no")
    raise SystemExit(0)

name = (((calls[0] or {}).get("function") or {}).get("name") or "unknown")
print("yes:" + name)
PY
}

write_metrics() {
  local model="$1"
  local task="$2"
  local response_file="$3"
  local text_file="$4"
  local csv_file="$5"
  local tool_calls="$6"

  python3 - "$model" "$task" "$response_file" "$text_file" "$csv_file" "$tool_calls" <<'PY'
import csv
import json
import sys

model, task, response_file, text_file, csv_file, tool_calls = sys.argv[1:7]

try:
    data = json.load(open(response_file, encoding="utf-8"))
except Exception as exc:
    print(f"{model:<30} {task:<12} ERROR could not parse response: {exc}")
    raise SystemExit(0)

if data.get("error"):
    print(f"{model:<30} {task:<12} ERROR {str(data['error'])[:80]}")
    with open(csv_file, "a", newline="", encoding="utf-8") as f:
        csv.writer(f).writerow([model, task, "", "", "", "", "", "", "", text_file, response_file, tool_calls, data["error"]])
    raise SystemExit(0)

text = data.get("response") or ""
with open(text_file, "w", encoding="utf-8") as f:
    f.write(text)
    if text and not text.endswith("\n"):
        f.write("\n")

prompt_tokens = int(data.get("prompt_eval_count") or 0)
output_tokens = int(data.get("eval_count") or 0)
total_seconds = (int(data.get("total_duration") or 0) / 1_000_000_000)
eval_seconds = (int(data.get("eval_duration") or 0) / 1_000_000_000)
prompt_seconds = (int(data.get("prompt_eval_duration") or 0) / 1_000_000_000)

output_tps = output_tokens / eval_seconds if eval_seconds else 0
output_tpm = output_tps * 60
prompt_tps = prompt_tokens / prompt_seconds if prompt_seconds else 0

with open(csv_file, "a", newline="", encoding="utf-8") as f:
    csv.writer(f).writerow([
        model,
        task,
        prompt_tokens,
        output_tokens,
        f"{total_seconds:.3f}",
        f"{eval_seconds:.3f}",
        f"{prompt_tps:.2f}",
        f"{output_tps:.2f}",
        f"{output_tpm:.0f}",
        text_file,
        response_file,
        tool_calls,
        "",
    ])

print(f"{model:<30} {task:<12} {output_tokens:>8} {output_tps:>10.2f} {output_tpm:>10.0f} {tool_calls}")
PY
}

need_cmd curl
need_cmd python3

mkdir -p "$RUN_DIR"
CSV_FILE="$RUN_DIR/results.csv"
PROMPT_TEXT="$(prompt_for_task)"

printf 'model,task,prompt_tokens,output_tokens,total_seconds,eval_seconds,prompt_tokens_per_s,output_tokens_per_s,output_tokens_per_min,text_file,json_file,tool_calls,error\n' > "$CSV_FILE"

echo "Ollama URL: $OLLAMA_URL"
echo "Run dir:    $RUN_DIR"
echo "Task:       $TASK"
echo "Predict:    $NUM_PREDICT"
echo "Temp:       $TEMPERATURE"
if [[ -n "$NUM_CTX" ]]; then
  echo "num_ctx:    $NUM_CTX"
else
  echo "num_ctx:    model default"
fi
echo
printf "%-30s %-12s %8s %10s %10s %s\n" "model" "task" "out_tok" "tok/s" "tok/min" "tool_calls"
printf "%-30s %-12s %8s %10s %10s %s\n" "-----" "----" "-------" "-----" "-------" "----------"

for model in "${MODELS[@]}"; do
  safe_model="$(safe_name "$model")"
  response_file="$RUN_DIR/${safe_model}-${TASK}.json"
  text_file="$RUN_DIR/${safe_model}-${TASK}.txt"
  tool_file="$RUN_DIR/${safe_model}-${TASK}.tool.json"
  tool_calls="skipped"

  if [[ "$TOOL_TEST" == "1" ]]; then
    tool_payload="$(build_tool_payload "$model")"
    if curl -sS "$OLLAMA_URL/api/chat" -H 'Content-Type: application/json' -d "$tool_payload" > "$tool_file"; then
      tool_calls="$(extract_tool_result "$tool_file")"
    else
      tool_calls="error:tool-test-request"
    fi
  fi

  generate_payload="$(build_generate_payload "$model" "$PROMPT_TEXT")"
  if curl -sS "$OLLAMA_URL/api/generate" -H 'Content-Type: application/json' -d "$generate_payload" > "$response_file"; then
    write_metrics "$model" "$TASK" "$response_file" "$text_file" "$CSV_FILE" "$tool_calls"
  else
    echo "$model $TASK ERROR generate request failed" >&2
  fi
done

echo
echo "CSV: $CSV_FILE"
echo "Responses: $RUN_DIR"
