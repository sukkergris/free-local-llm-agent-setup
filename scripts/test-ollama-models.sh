#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_DIR="$SCRIPT_DIR/lib"
JSON_HELPER="$HELPER_DIR/test-ollama-json.py"

source "$HELPER_DIR/test-ollama-prompts.sh"

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
TASK="${TASK:-csharp}"
PROMPT="${PROMPT:-}"
NUM_PREDICT="${NUM_PREDICT:-256}"
NUM_CTX="${NUM_CTX:-}"
TEMPERATURE="${TEMPERATURE:-0.2}"
TOOL_TEST="${TOOL_TEST:-1}"
THINK="${THINK:-false}"
TOOL_THINK="${TOOL_THINK:-}"
RUN_DIR="${RUN_DIR:-output/model-tests/$(date +%Y%m%d-%H%M%S)}"

cd "$REPO_ROOT"

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

From scripts/test-ollama-models.bashbook, use:
  ./test-ollama-models.sh qwen35-roo:9b

Environment:
  OLLAMA_URL    Default: http://localhost:11434
  TASK          csharp, bash, elm, dockerfile, compose, short, custom
  PROMPT        Required when TASK=custom
  NUM_PREDICT   Default: 256
  NUM_CTX       Default: unset, so the model default is used
  TEMPERATURE   Default: 0.2
  TOOL_TEST     Default: 1
  THINK         Default: false, used for generation
  TOOL_THINK    Default: unset, used for tool-call test when set
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

build_generate_payload() {
  local model="$1"
  local prompt="$2"
  python3 "$JSON_HELPER" build-generate-payload "$model" "$prompt" "$NUM_PREDICT" "$TEMPERATURE" "$NUM_CTX" "$THINK"
}

build_tool_payload() {
  local model="$1"
  python3 "$JSON_HELPER" build-tool-payload "$model" "$TOOL_THINK"
}

extract_tool_result() {
  local file="$1"
  python3 "$JSON_HELPER" extract-tool-result "$file"
}

write_metrics() {
  local model="$1"
  local task="$2"
  local response_file="$3"
  local text_file="$4"
  local csv_file="$5"
  local tool_calls="$6"

  python3 "$JSON_HELPER" write-metrics "$model" "$task" "$response_file" "$text_file" "$csv_file" "$tool_calls"
}

need_cmd curl
need_cmd python3

mkdir -p "$RUN_DIR"
CSV_FILE="$RUN_DIR/results.csv"
PROMPT_TEXT="$(prompt_for_task "$TASK" "$PROMPT")"

printf 'model,task,prompt_tokens,output_tokens,total_seconds,eval_seconds,prompt_tokens_per_s,output_tokens_per_s,output_tokens_per_min,text_file,json_file,tool_calls,error\n' > "$CSV_FILE"

echo "Ollama URL: $OLLAMA_URL"
echo "Run dir:    $RUN_DIR"
echo "Task:       $TASK"
echo "Predict:    $NUM_PREDICT"
echo "Temp:       $TEMPERATURE"
echo "think:      $THINK"
if [[ -n "$TOOL_THINK" ]]; then
  echo "tool think: $TOOL_THINK"
else
  echo "tool think: model default"
fi
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
