# **Discourse AI** Plugin

**Plugin Summary**

For more information, please see: https://meta.discourse.org/t/discourse-ai/259214?u=falco

### Evals

The directory `evals` contains AI evals for the Discourse AI plugin.
You may create a local config by copying `config/eval-llms.yml` to `config/eval-llms.local.yml` and modifying the values.

To run them use:

cd evals
./run --help

```
Usage: evals/run [options]
    -e, --eval NAME                  Name of the evaluation to run
    -m, --models NAME                Models to evaluate (comma separated, defaults to all)
    -l, --list                       List eval ids
        --list-models                List configured LLMs
        --list-features              List feature keys available to evals
        --list-personas              List persona definitions under evals/personas
    -f, --feature KEY                Filter evals by feature (module_name:feature_name)
    -j, --judge NAME                 LLM config used as a judge (defaults to gpt-4o when available)
        --persona-keys KEYS          Comma-separated list of persona keys (or repeat the flag) to run sequentially
        --compare MODE               Run comparisons (MODE: personas or llms)
```

To run evals you will need to configure API keys in your environment:

OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
GEMINI_API_KEY=your_gemini_api_key

#### Custom personas for evals

Eval runs can swap the built-in personas with YAML definitions stored in
`plugins/discourse-ai/evals/personas`. Use `--list-personas` to discover available entries; the
special key `default` always refers to the built-in persona prompt. Pass `--persona-keys key1,key2`
(or repeat `--persona-keys key`) to apply them:

```
./run --eval simple_summarization --models gpt-4o-mini --persona-keys topic_summary_eval,another_prompt
```

Each persona file only needs a `system_prompt` (and optional description). When specified, that
prompt replaces the default system prompt of whichever persona the eval runner would normally use.
Pass multiple keys (including `default`) to rerun the same evals with different prompts without
restarting the CLI. Add new files under that directory to compare alternate prompts without touching
the database.

When running persona comparisons (`--compare personas`) the CLI automatically prepends the built-in
`default` persona so you can benchmark your YAML prompts against the stock behavior. Non-comparison
runs still execute only the personas you list.

#### Comparison matrix

Use the `--compare` flag to ask the CLI to judge multiple runs together:

- `--compare personas`: require a single `--models` value and at least one persona key (the
  built-in `default` persona is implicitly added). Each eval is executed for every persona; the
  judge LLM scores them side-by-side and announces the winner plus individual ratings.
- `--compare llms`: require at least two `--models` and exactly one persona (default unless you pass
  `--persona-keys custom_persona`). Every eval runs once and the judge compares the outputs from each
  LLM. Logs include the persona key (or `default`) so you can correlate recordings.

Both modes reuse the rubric declared under the eval’s `judge` block and stream the comparison summary
to STDOUT. The structured log files continue to be written for each underlying run so you can drill
into the raw outputs if the judge’s reasoning needs inspection.
