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
        --list-models                List models
    -m, --model NAME                 Model to evaluate (will eval all models if not specified)
    -l, --list                       List evals
```

To run evals you will need to configure API keys in your environment:

OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
GEMINI_API_KEY=your_gemini_api_key
