#!/usr/bin/env bash

prompt_for_task() {
  local task="$1"
  local custom_prompt="${2:-}"

  case "$task" in
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
      if [[ -z "$custom_prompt" ]]; then
        echo "TASK=custom requires PROMPT='...'" >&2
        return 1
      fi
      printf '%s\n' "$custom_prompt"
      ;;
    *)
      echo "Unknown TASK: $task" >&2
      echo "Valid tasks: csharp, bash, elm, dockerfile, compose, short, custom" >&2
      return 1
      ;;
  esac
}
