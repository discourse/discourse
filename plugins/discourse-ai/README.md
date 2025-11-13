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
        --persona-key KEY            Override runner personas using the YAML entry identified by KEY
```

To run evals you will need to configure API keys in your environment:

OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
GEMINI_API_KEY=your_gemini_api_key

#### Custom personas for evals

Eval runs can swap the built-in personas with YAML definitions stored in
`plugins/discourse-ai/evals/personas`. Use `--list-personas` to discover available entries and
`--persona-key <key>` to apply one:

```
./run --eval simple_summarization --models gpt-4o-mini --persona-key topic_summary_eval
```

Each persona file only needs a `system_prompt` (and optional description). When specified, that
prompt replaces the default system prompt of whichever persona the eval runner would normally use.
Add new files under that directory to compare alternate prompts without touching the database.
