# frozen_string_literal: true

Fabricator(:embedding_definition) do
  display_name "Multilingual E5 Large"
  provider "hugging_face"
  tokenizer_class "DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer"
  api_key "123"
  url "https://test.com/embeddings"
  provider_params nil
  pg_function "<=>"
  max_sequence_length 512
  dimensions 1024
end

Fabricator(:cloudflare_embedding_def, from: :embedding_definition) do
  display_name "BGE Large EN"
  provider "cloudflare"
  pg_function "<#>"
  tokenizer_class "DiscourseAi::Tokenizer::BgeLargeEnTokenizer"
  provider_params nil
end

Fabricator(:open_ai_embedding_def, from: :embedding_definition) do
  display_name "ADA 002"
  provider "open_ai"
  url "https://api.openai.com/v1/embeddings"
  tokenizer_class "DiscourseAi::Tokenizer::OpenAiTokenizer"
  provider_params { { model_name: "text-embedding-ada-002" } }
  max_sequence_length 8191
  dimensions 1536
end

Fabricator(:gemini_embedding_def, from: :embedding_definition) do
  display_name "Gemini's embedding-001"
  provider "google"
  dimensions 768
  max_sequence_length 1536
  tokenizer_class "DiscourseAi::Tokenizer::OpenAiTokenizer"
  url "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent"
end
