#!/usr/bin/env python3
import csv
import json
import sys


def parse_bool(value: str) -> bool:
    return value.lower() in {"1", "true", "yes", "on"}


def build_generate_payload(args: list[str]) -> None:
    model, prompt, num_predict, temperature, num_ctx, think = args
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
        "think": parse_bool(think),
        "options": options,
    }))


def build_tool_payload(args: list[str]) -> None:
    model, think = args
    payload = {
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
    }
    if think:
        payload["think"] = parse_bool(think)
    print(json.dumps(payload))


def extract_tool_result(args: list[str]) -> None:
    (path,) = args
    try:
        data = json.load(open(path, encoding="utf-8"))
    except Exception as exc:
        print(f"error:{exc}")
        return

    if data.get("error"):
        print("error:" + str(data["error"])[:80])
        return

    calls = (data.get("message") or {}).get("tool_calls") or []
    if not calls:
        print("no")
        return

    name = (((calls[0] or {}).get("function") or {}).get("name") or "unknown")
    print("yes:" + name)


def write_metrics(args: list[str]) -> None:
    model, task, response_file, text_file, csv_file, tool_calls = args

    try:
        data = json.load(open(response_file, encoding="utf-8"))
    except Exception as exc:
        print(f"{model:<30} {task:<12} ERROR could not parse response: {exc}")
        return

    if data.get("error"):
        print(f"{model:<30} {task:<12} ERROR {str(data['error'])[:80]}")
        with open(csv_file, "a", newline="", encoding="utf-8") as f:
            csv.writer(f).writerow([
                model,
                task,
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                text_file,
                response_file,
                tool_calls,
                data["error"],
            ])
        return

    text = data.get("response") or ""
    with open(text_file, "w", encoding="utf-8") as f:
        f.write(text)
        if text and not text.endswith("\n"):
            f.write("\n")

    prompt_tokens = int(data.get("prompt_eval_count") or 0)
    output_tokens = int(data.get("eval_count") or 0)
    total_seconds = int(data.get("total_duration") or 0) / 1_000_000_000
    eval_seconds = int(data.get("eval_duration") or 0) / 1_000_000_000
    prompt_seconds = int(data.get("prompt_eval_duration") or 0) / 1_000_000_000

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


COMMANDS = {
    "build-generate-payload": (build_generate_payload, 6),
    "build-tool-payload": (build_tool_payload, 2),
    "extract-tool-result": (extract_tool_result, 1),
    "write-metrics": (write_metrics, 6),
}


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        valid = ", ".join(sorted(COMMANDS))
        print(f"Usage: {sys.argv[0]} <{valid}> ...", file=sys.stderr)
        return 2

    command = sys.argv[1]
    handler, arity = COMMANDS[command]
    args = sys.argv[2:]
    if len(args) != arity:
        print(f"{command} expects {arity} args, got {len(args)}", file=sys.stderr)
        return 2

    handler(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
