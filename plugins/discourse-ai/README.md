# **Discourse AI** Plugin

**Plugin Summary**

For more information, please see: https://meta.discourse.org/t/discourse-ai/259214?u=falco

### Recovering invalid prompt turns

`Prompt` repairs role-order problems as messages are loaded or appended. The history builder discards stored system entries before trimming or formatting, including in single-message chat and topic transcripts. Only the prompt's leading system message supplies system instructions. A missing user turn gets a neutral history marker, and consecutive assistant replies keep their own attachments and provider signatures.

Tool results belong to outstanding calls in the same exchange. Parallel results may arrive in any order; a result from an earlier exchange cannot complete a new call with the same ID. Malformed historical exchanges are retained as labeled, non-executable evidence. A pending current call stays protected, even if that means the prompt cannot fit. Recovery does not retry the completion, run a tool, or create a missing result. Unknown roles and malformed content are still rejected.

Recovery warnings include the stage, message index, adjacent roles, and reason, not message bodies or tool payloads. Compression reads historical evidence without inserting separators. Replay preserves the current request by position; when no position was saved, the bot, compression, and resume code all skip recovery markers and internal budget hints.

### Admin Assistant tool loading

The Admin Assistant initially exposes website lookup, Meta search, local navigation,
Upcoming Changes, and `load_admin_tools`. Domain schemas are exposed only after the
model loads `settings`, `categories_tags`, `moderation`, or `appearance`; a request can
load several groups. Discovery returns the available tool names and their workflow
instructions. The next completion receives their schemas, without restarting the turn.
Loading tools does not execute an administrative action or bypass approval.

Loaded groups live on the conversation context. New contexts restore them from discovery
results and domain tool calls in retained history, including approval follow-ups. If
history trimming or compression removes that evidence, the model can load the group
again. Availability is rechecked against the current site, user, and plugin restrictions.
Ungrouped tools added by `admin_assistant_tools` remain immediately available for
backward compatibility; removing a tool through that modifier still excludes it from
loaded groups. Keep new built-in domain tools in `AdminAssistant::TOOL_GROUPS`.

### Workflow AI usage

The AI agent workflow action tags each LLM audit entry with its workflow ID, including
requests made by subagents and context compression. A workflow's stats panel displays the number of AI requests,
request, response, and cache tokens, and estimated USD cost for the last seven days. These
figures count requests rather than workflow executions; multiple items or tool calls can
produce multiple requests. Only retained audit logs are counted, so reducing audit-log
retention below seven days also shortens the available usage history. Older workflow runs
and other AI nodes without workflow attribution are not included. AI logs identify
existing workflows by name and link to their editor. The main AI usage report shows a
workflow breakdown below users only when attributed audit entries exist for a workflow
in the selected date, feature, and model filters. Unlike the overall report, this
breakdown cannot include audit entries after their retention window expires.

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
        --list-agents              List agent definitions under evals/agents
    -f, --feature KEY                Filter evals by feature (module_name:feature_name)
    -j, --judge NAME                 LLM config used as a judge (defaults to gpt-4o when available)
        --agent-keys KEYS          Comma-separated list of agent keys (or repeat the flag) to run sequentially
        --compare MODE               Run comparisons (MODE: agents or llms)
        --dataset PATH               Path to a CSV dataset file (requires --feature)
```

To run evals you will need to configure API keys in your environment:

OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
GEMINI_API_KEY=your_gemini_api_key

#### Custom agents for evals

Eval runs can swap the built-in agents with YAML definitions stored in
`plugins/discourse-ai/evals/agents`. Use `--list-agents` to discover available entries; the
special key `default` always refers to the built-in agent prompt. Pass `--agent-keys key1,key2`
(or repeat `--agent-keys key`) to apply them:

```
./run --eval simple_summarization --models gpt-4o-mini --agent-keys topic_summary_eval,another_prompt
```

Each agent file only needs a `system_prompt` (and optional description). When specified, that
prompt replaces the default system prompt of whichever agent the eval runner would normally use.
Pass multiple keys (including `default`) to rerun the same evals with different prompts without
restarting the CLI. Add new files under that directory to compare alternate prompts without touching
the database.

When running agent comparisons (`--compare agents`) the CLI automatically prepends the built-in
`default` agent so you can benchmark your YAML prompts against the stock behavior. Non-comparison
runs still execute only the agents you list.

#### Dataset-driven evals

Supply `--dataset path/to/file.csv` along with `--feature module:feature_name` to generate eval cases
from a CSV instead of YAML files. Each row must include `content` and `expected_output` columns; rows
are converted into individual eval ids (prefixed with the dataset filename) that reuse the selected
feature’s runner. Example:

```
./run --dataset evals/datasets/spam.csv --feature spam:inspect_posts --models gpt-4o-mini
```

#### Comparison matrix

Use the `--compare` flag to ask the CLI to judge multiple runs together:

- `--compare agents`: require a single `--models` value and at least one agent key (the
  built-in `default` agent is implicitly added). Each eval is executed for every agent; the
  judge LLM scores them side-by-side and announces the winner plus individual ratings.
- `--compare llms`: require at least two `--models` and exactly one agent (default unless you pass
  `--agent-keys custom_agent`). Every eval runs once and the judge compares the outputs from each
  LLM. Logs include the agent key (or `default`) so you can correlate recordings.

Both modes reuse the rubric declared under the eval’s `judge` block and stream the comparison summary
to STDOUT. The structured log files continue to be written for each underlying run so you can drill
into the raw outputs if the judge’s reasoning needs inspection.
