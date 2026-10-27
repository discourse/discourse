# Sentiment and emotion classification backends

Sentiment and emotion can independently use a dedicated classification endpoint,
an LLM agent, or a decision model. Each capability has its own enable flag and
classification strategy setting.

The **Dedicated classification endpoint** backend uses the original classification
API configured through `ai_sentiment_model_configs`. Its stored strategy value
remains `classification_model`; the backend identifier and `classification_model`
metadata key also remain unchanged for compatibility. Existing endpoint
configurations, including untyped custom configurations, continue to work.

“Dedicated” distinguishes this API from the agent and decision-model backends; it
does not indicate deprecation or a configuration migration.
