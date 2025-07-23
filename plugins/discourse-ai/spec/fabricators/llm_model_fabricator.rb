# frozen_string_literal: true

Fabricator(:llm_model) do
  display_name "A good model"
  name "gpt-4-turbo"
  provider "open_ai"
  tokenizer "DiscourseAi::Tokenizer::OpenAiTokenizer"
  api_key "123"
  url "https://api.openai.com/v1/chat/completions"
  max_prompt_tokens 131_072
  input_cost 10
  cached_input_cost 2.5
  output_cost 40
end

Fabricator(:anthropic_model, from: :llm_model) do
  display_name "Claude 3 Opus"
  name "claude-3-opus"
  max_prompt_tokens 200_000
  url "https://api.anthropic.com/v1/messages"
  tokenizer "DiscourseAi::Tokenizer::AnthropicTokenizer"
  provider "anthropic"
end

Fabricator(:hf_model, from: :llm_model) do
  display_name "Llama 3.1"
  name "meta-llama/Meta-Llama-3.1-70B-Instruct"
  max_prompt_tokens 64_000
  tokenizer "DiscourseAi::Tokenizer::Llama3Tokenizer"
  url "https://test.dev/v1/chat/completions"
  provider "hugging_face"
end

Fabricator(:open_router_model, from: :llm_model) do
  display_name "OpenRouter"
  name "openrouter-1.0"
  provider "open_router"
  tokenizer "DiscourseAi::Tokenizer::OpenAiTokenizer"
  max_prompt_tokens 64_000
  url "https://openrouter.ai/api/v1/chat/completions"
end

Fabricator(:vllm_model, from: :llm_model) do
  display_name "Llama 3.1 vLLM"
  name "meta-llama/Meta-Llama-3.1-70B-Instruct"
  max_prompt_tokens 64_000
  tokenizer "DiscourseAi::Tokenizer::Llama3Tokenizer"
  url "https://test.dev/v1/chat/completions"
  provider "vllm"
end

Fabricator(:fake_model, from: :llm_model) do
  display_name "Fake model"
  name "fake"
  provider "fake"
  tokenizer "DiscourseAi::Tokenizer::OpenAiTokenizer"
  max_prompt_tokens 32_000
  api_key "fake"
  url "https://fake.test/"
end

Fabricator(:gemini_model, from: :llm_model) do
  display_name "Gemini"
  name "gemini-1.5-pro"
  provider "google"
  tokenizer "DiscourseAi::Tokenizer::OpenAiTokenizer"
  max_prompt_tokens 800_000
  url "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest"
end

Fabricator(:bedrock_model, from: :anthropic_model) do
  url ""
  provider "aws_bedrock"
  api_key "asd-asd-asd"
  name "claude-3-sonnet"
  provider_params { { region: "us-east-1", access_key_id: "123456" } }
end

Fabricator(:nova_model, from: :llm_model) do
  display_name "Amazon Nova pro"
  name "amazon.nova-pro-v1:0"
  provider "aws_bedrock"
  tokenizer "DiscourseAi::Tokenizer::OpenAiTokenizer"
  max_prompt_tokens 300_000
  api_key "fake"
  url ""
  provider_params { { region: "us-east-1", access_key_id: "123456" } }
end

Fabricator(:cohere_model, from: :llm_model) do
  display_name "Cohere Command R+"
  name "command-r-plus"
  provider "cohere"
  api_key "ABC"
  url "https://api.cohere.ai/v1/chat"
end

Fabricator(:samba_nova_model, from: :llm_model) do
  display_name "Samba Nova"
  name "samba-nova"
  provider "samba_nova"
  api_key "ABC"
  url "https://api.sambanova.ai/v1/chat/completions"
end

Fabricator(:ollama_model, from: :llm_model) do
  display_name "Ollama llama 3.1"
  name "llama-3.1"
  provider "ollama"
  api_key "ABC"
  tokenizer "DiscourseAi::Tokenizer::Llama3Tokenizer"
  url "http://api.ollama.ai/api/chat"
  provider_params { { enable_native_tool: true } }
end

Fabricator(:mistral_model, from: :llm_model) do
  display_name "Mistral Large"
  name "mistral-large-latest"
  provider "mistral"
  api_key "ABC"
  tokenizer "DiscourseAi::Tokenizer::MistralTokenizer"
  url "https://api.mistral.ai/v1/chat/completions"
  provider_params { { disable_native_tools: false } }
end

Fabricator(:seeded_model, from: :llm_model) do
  id "-2"
  display_name "CDCK Hosted Model"
  name "cdck-hosted"
  provider "fake"
  api_key "DSC"
  tokenizer "DiscourseAi::Tokenizer::OpenAiTokenizer"
  url "https://cdck.test/"
  enabled_chat_bot true
end
