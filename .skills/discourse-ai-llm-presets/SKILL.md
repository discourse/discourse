---
name: discourse-ai-llm-presets
description: Use when refreshing the default LLM presets shipped with Discourse AI — model versions, pricing, context windows, vision flags, and the matching `model_description` i18n keys.
---

# Updating Discourse AI Default LLM Presets

## Overview

Discourse AI ships a curated set of LLM model presets in `plugins/discourse-ai/lib/completions/llm_presets.rb` so admins can create new LLM configurations with one click. This skill keeps them current — refreshing model IDs, pricing, context windows, and vision flags as providers evolve.

## When to Use

- A user asks to "update", "refresh", or "bump" the default LLM model presets in Discourse AI.
- A new flagship model has been released by a major provider (e.g. new GPT, Claude, or Gemini version).
- Pricing on a provider has changed and the shipped presets are stale.

## Files Involved

| Path | What lives there |
| --- | --- |
| `plugins/discourse-ai/lib/completions/llm_presets.rb` | The four provider preset blocks: `anthropic_preset`, `google_preset`, `open_ai_preset`, `open_router_preset`. |
| `plugins/discourse-ai/config/locales/client.en.yml` | One-line `model_description` strings keyed by `<provider_id>-<model_name>` with `.`/`/`/`:` replaced by `-`. Every preset model needs a matching key. |

**Out of scope for this skill:**
- `plugins/discourse-ai/config/eval-llms.yml` — internal evaluation suite. May reference older models intentionally; do not auto-update.
- Other locale files (`client.de.yml`, `client.es.yml`, …) — translations are managed via Crowdin. Only update `client.en.yml`; stale keys in other locales clean up automatically.
- Existing `LlmModel` DB rows. Preset changes only affect *new* one-click creations; previously-configured models keep working under their original names.

## Data Sources

Two primary sources, cross-reference both:

1. **`https://www.llm-prices.com/current-v1.json`** — curated pricing for first-party APIs (Anthropic, OpenAI, Google, xAI, etc.). Has `input`, `output`, and `input_cached` per 1M tokens.
2. **`https://catwalk.charm.land/v2/providers`** — broader catalog with context windows, max output tokens, vision flags, cached pricing, and provider defaults (`default_large_model_id`, `default_small_model_id`). Use for context windows and vision support that `llm-prices` omits.

For the OpenRouter provider list specifically, also use:

3. **OpenRouter top-weekly** — fetch via the frontend API since the HTML page is JS-rendered:
   ```
   curl -s "https://openrouter.ai/api/frontend/models/find?order=top-weekly&limit=30"
   ```
   The user's reference URL is `https://openrouter.ai/models?fmt=cards&order=top-weekly&output_modalities=text` but `WebFetch` cannot read it — go straight to the API.

## Provider Preset Structure

Each preset block is a hash with `id`, `models` (array), `tokenizer`, `endpoint`, and `provider`. Each model entry uses the `model(...)` helper:

```ruby
model(
  name: "claude-sonnet-4-6",       # API model name — also the lookup key
  tokens: 1_000_000,                # context window in tokens
  display_name: "Claude Sonnet 4.6",
  max_output_tokens: 64_000,
  input_cost: 3.0,                  # USD per 1M input tokens
  cached_input_cost: 0.30,          # USD per 1M cached input tokens
  cache_write_cost: 3.75,           # Anthropic-specific
  output_cost: 15.0,
  vision_enabled: true,
  endpoint: "...",                  # only when the model needs a different endpoint than the provider default
)
```

Notes:
- `cache_write_cost` is currently only set on Anthropic models (Anthropic has a separate write price).
- `vision_enabled` defaults to `false` and is only added when `true`. Trust catwalk's `supports_attachments` flag — it has been wrong in the file before (e.g. `minimax-m2.7` and `glm-5.1` were marked vision-capable but are text-only).
- Google models override `endpoint` per model because the API path encodes the model name.
- The OpenAI provider-level `endpoint:` is `chat/completions` but every model overrides it with `/responses` — leave the provider-level value alone.

## Selection Rules

### Anthropic, Google, OpenAI

- Ship a small tiered set: flagship / standard / small. Anthropic ships 3 (Opus / Sonnet / Haiku); OpenAI follows the same 3-tier pattern (e.g. GPT-5.5 / GPT-5.4 / GPT-5.4-nano). Google ships 2 (Pro / Flash).
- Avoid mid-tier overlap (e.g. shipping both `gpt-5.4` and `gpt-5.4-mini` is redundant when `gpt-5.4-nano` already covers the cheap end).
- Prefer the catwalk `default_large_model_id` and `default_small_model_id` as a hint for what the provider currently considers canonical.

### OpenRouter

- Pick the **top ~5–6 paid models by weekly usage** from the OpenRouter top-weekly list.
- **Skip `:free` variants** — they rotate out of OpenRouter within weeks and break presets.
- **Skip router/`~latest` aliases** (slug starts with `~`, e.g. `~anthropic/claude-sonnet-latest`) — those redirect and the underlying model can change.
- **Skip first-party Anthropic, Google, and OpenAI models** — they belong in their own provider blocks. The OpenRouter preset is for everything else (DeepSeek, Moonshot, MiniMax, Z.AI, xAI, Qwen, Arcee, etc.).
- Prefer models with vision and a sane cached-input price when ranking is close.

## i18n Keys

Every preset model needs a one-line description in `config/locales/client.en.yml` under `discourse_ai.llms.model_description`. The key format is:

```
<provider_id>-<model_name>
```

…with `.`, `/`, and `:` all replaced by `-` (handled in JS by `llm.id.replace(/[.:\/]/g, "-")` in `ai-llms-list-editor.gjs`).

Examples:
| Provider | Model `name` | i18n key |
| --- | --- | --- |
| `anthropic` | `claude-opus-4-7` | `anthropic-claude-opus-4-7` |
| `open_ai` | `gpt-5.4` | `open_ai-gpt-5-4` |
| `open_router` | `deepseek/deepseek-v4-flash` | `open_router-deepseek-deepseek-v4-flash` |
| `open_router` | `moonshotai/kimi-k2.6` | `open_router-moonshotai-kimi-k2-6` |

Whenever a model is added, renamed, or removed in `llm_presets.rb`, the matching key must be added/renamed/removed in `client.en.yml`. Missing keys silently fall through to an empty description (`I18n.lookup(..., { ignoreMissing: true })`).

## Steps

1. **Fetch source data** in parallel:
   ```bash
   curl -s https://www.llm-prices.com/current-v1.json -o /tmp/llm_prices.json
   curl -s https://catwalk.charm.land/v2/providers -o /tmp/catwalk.json
   curl -s "https://openrouter.ai/api/frontend/models/find?order=top-weekly&limit=30" -o /tmp/or_top.json
   ```

2. **Read the current presets file** at `plugins/discourse-ai/lib/completions/llm_presets.rb`.

3. **For each first-party provider block (Anthropic / Google / OpenAI)**: cross-reference each model's `tokens`, `max_output_tokens`, all `*_cost` fields, and `vision_enabled` against catwalk + llm-prices. Catwalk wins on context windows and vision flags; llm-prices wins on first-party API pricing.

4. **For the OpenRouter block**: parse `/tmp/or_top.json`, filter out `:free`, slugs starting with `~`, and first-party Anthropic/Google/OpenAI models. Take the top 5–6 remaining as the new list. Pricing comes from each entry's `endpoint.pricing` (multiply by 1_000_000 for per-1M tokens).

5. **Apply edits to `llm_presets.rb`** — prefer targeted `Edit` calls per model rather than rewriting whole blocks.

6. **Update `client.en.yml`** — add/rename/remove `model_description` keys to exactly match the new model set. Diff the model `name` list before/after to make sure no key is left orphaned.

7. **Validate**:
   ```bash
   bundle exec rubocop --force-exclusion plugins/discourse-ai/lib/completions/llm_presets.rb
   ruby -ryaml -e "YAML.load_file('plugins/discourse-ai/config/locales/client.en.yml'); puts 'YAML OK'"
   ```
   Also grep for orphaned references to any removed model names elsewhere in the plugin:
   ```bash
   grep -rn "<old-model-name>" plugins/discourse-ai --include="*.rb" --include="*.js" --include="*.gjs" --include="*.yml" \
     | grep -v lib/completions/llm_presets.rb
   ```

8. **Summarise the diff** to the user grouped by provider, calling out any pricing corrections (these are usually the most consequential — e.g. a model whose price had drifted vs. the provider's current price).

## Common Pitfalls

- **Forgetting the i18n keys.** Easy to miss because nothing breaks at runtime — the descriptions just go blank in the admin UI. Always update `client.en.yml` in the same commit.
- **Trusting OpenRouter pricing for first-party models.** OpenRouter aggregates many backends; for Anthropic / OpenAI / Google, prefer `llm-prices` or catwalk's first-party listing.
- **Inheriting wrong vision flags.** `vision_enabled` has been incorrect in the past — verify against catwalk every refresh.
- **Renaming a model without checking specs.** `spec/system/llms/ai_llm_spec.rb` and `lib/completions/endpoints/aws_bedrock.rb` reference Anthropic model names by string. Grep before renaming.
- **Picking unstable OpenRouter slugs.** `:free` and `~latest` alias slugs both churn faster than the release cycle of this file. Always skip them.
