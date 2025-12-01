---
title: Run Discourse AI evals
short_title: AI evals
id: ai-evals
---

# Overview

The Discourse AI plugin ships a Ruby CLI under `plugins/discourse-ai/evals` that exercises AI features against YAML definitions and records results. Use it to benchmark prompts, compare model outputs, and regression-test AI behaviors without touching the app database.

## Core concepts (what users need to know)

- **Eval case**: A YAML definition under `evals/cases/<group>/<id>.yml` that pairs inputs (`args`) with an expected outcome. Evals can check exact strings, regexes, or expected tool calls.
- **Feature**: The Discourse AI behavior under test, identified as `module:feature_name` (for example, `summarization:topic_summaries`). `--list-features` shows the valid keys.
- **Persona**: The system prompt wrapped around the LLM call. Runs default to the built-in prompt unless you pass `--persona-keys` to load alternate prompts from `evals/personas/*.yml`. Add multiple keys to compare prompts in one run.
- **Judge**: A rubric embedded in some evals that requires a second LLM to grade outputs. Think of it as an automated reviewer: it reads the model output and scores it against the criteria. If an eval defines `judge`, you must supply or accept the default judge model (`--judge`, default `gpt-4o`). Without a judge, outputs are matched directly against the expected value.
- **Comparison modes**: `--compare personas` (one model, many personas) or `--compare llms` (one persona, many models). The judge picks a winner and reports ratings; non-comparison runs just report pass/fail.
- **Datasets**: Instead of YAML cases, pass `--dataset path.csv --feature module:feature` to build cases from CSV rows (`content` and `expected_output` columns required).
- **Logs**: Every run writes plain text and structured traces to `plugins/discourse-ai/evals/log/` with timestamps and persona keys. Use them to inspect failures, skipped models, and judge decisions.

## Prerequisites

- Have a working Discourse development environment with the Discourse AI plugin present. The runner loads `config/environment` (defaulting to the repository root or `DISCOURSE_PATH` if set).
- LLMs are defined in `plugins/discourse-ai/config/eval-llms.yml`; copy it to `eval-llms.local.yml` to override entries locally. Each entry expects an `api_key_env` (or inline `api_key`), so export the matching environment variables before running, for example:
  - `OPENAI_API_KEY=...`
  - `ANTHROPIC_API_KEY=...`
  - `GEMINI_API_KEY=...`
- From the repository root, change into `plugins/discourse-ai/evals` and run `./run --help` to confirm the CLI is wired up. If `evals/cases` is missing it will be cloned automatically from `discourse/discourse-ai-evals`.

## Discover available inputs

- `./run --list` lists all eval ids from `evals/cases/*/*.yml`.
- `./run --list-features` prints feature keys grouped by module (format: `module:feature`).
- `./run --list-models` shows LLM configs that can be hydrated from `eval-llms.yml`/`.local.yml`.
- `./run --list-personas` lists persona keys defined under `evals/personas/*.yml` plus the built-in `default`.

## Run evals

- Run a single eval against specific models:

  ```sh
  OPENAI_API_KEY=... ./run --eval simple_summarization --models gpt-4o-mini
  ```

- Run every eval for a feature (or the whole suite) against multiple models:

  ```sh
  ./run --feature summarization:topic_summaries --models gpt-4o-mini,claude-3-5-sonnet-latest
  ```

  Omitting `--models` hydrates every configured LLM. Models that cannot hydrate (missing API keys, etc.) are skipped with a log message.

- Some evals define a `judge` block. When any selected eval requires judging, the runner defaults to `--judge gpt-4o` unless you pass `--judge name`. Invalid or missing judge configs cause the CLI to exit before running.

## Personas and comparison modes

- Supply custom prompts with `--persona-keys key1,key2`. Keys resolve to YAML files in `evals/personas`; each needs `key` (optional, defaults to the filename), `system_prompt`, and an optional `description`.
- Minimal persona example (`evals/personas/topic_summary_eval.yml`):

  ```yml
  key: topic_summary_eval
  description: Variant tuned for eval comparisons
  system_prompt: |
    Summarize the topic in 2–4 sentences. Keep the original language and avoid new facts.
  ```

- `--compare personas` runs one model against multiple personas. The built-in `default` persona is automatically prepended so you can compare YAML prompts against stock behavior, and at least two personas are required.
- `--compare llms` runs one persona (default unless overridden) across multiple models and asks the judge to score them side by side.
- Non-comparison runs accept a single persona; pass one `--persona-keys` value or rely on the default prompt.

## Dataset-driven runs

- Generate eval cases from a CSV instead of YAML by passing `--dataset path/to/file.csv --feature module:feature`. The CSV must include `content` and `expected_output` columns; each row becomes its own eval id (`dataset-<filename>-<row>`).
- Minimal CSV example:

  ```csv
  content,expected_output
  "This is spam!!! Buy now!",true
  "Genuine question about hosting",false
  ```

- Example:

  ```sh
  ./run --dataset evals/cases/spam/spam_eval_dataset.csv --feature spam:inspect_posts --models gpt-4o-mini
  ```

## Writing eval cases

- Store cases under `evals/cases/<group>/<name>.yml`. Each file must declare `id`, `name`, `description`, and `feature` (the `module:feature` key registered with the plugin).
- Provide inputs under `args`. Keys ending in `_path` (or `path`) are expanded relative to the YAML directory so you can reference fixture files. For multi-case files, `args` can contain arrays (for example, `cases:`) that runners iterate over.
- Expected results can be declared with one of:
  - `expected_output`: exact string match
  - `expected_output_regex`: treated as a multiline regular expression
  - `expected_tool_call`: expected tool invocation payload
- Set `vision: true` for evals that require a vision-capable model. Include a `judge` section (`pass_rating`, `criteria`, and optional `label`) to have outputs scored by a judge LLM.

## Results and logs

- CLI output shows pass/fail per model and prints expected vs actual details on failures. Comparison runs also stream the judge’s winner and ratings.
- Example pass/fail snippet:

  ```
  gpt-4o-mini: Passed 🟢
  claude-3-5-sonnet-latest: Failed 🔴
  ---- Expected ----
  true
  ---- Actual ----
  false
  ```

- Comparison winner snippet:

  ```
  Comparing personas for topic-summary
  Winner: topic_summary_eval
  Reason: Captured key details and stayed concise.
    - default: 7/10 — missed concrete use case
    - topic_summary_eval: 9/10 — mentioned service dogs and tone was neutral
  ```

- Each run writes plain logs and structured traces to `plugins/discourse-ai/evals/log/` (timestamped `.log` and `.json` files). The JSON files are formatted for [ui.perfetto.dev](https://ui.perfetto.dev) to inspect the structured steps.
- On completion the runner echoes the log paths; use them to audit skipped models, judge decisions, and raw outputs when iterating on prompts or features.

## Common features (what to try first)

- `summarization:topic_summaries`: Summarize a conversation.
- `spam:inspect_posts`: Spam/ham classification.
- `translation:topic_title_translator`: Translate topic titles while preserving tone/formatting.
- `ai_helper:rewrite`: Prompt the AI helper for rewrites.
- `tool_calls:tool_calls_with_no_tool` and `tool_calls:tool_call_chains`: Validate structured tool call behavior.
