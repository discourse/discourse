# frozen_string_literal: true

module DiscourseAi
  module Admin
    module AiLogSerializerHelpers
      PROVIDER_NAMES = {
        AiApiAuditLog::Provider::OpenAI => "OpenAI",
        AiApiAuditLog::Provider::Anthropic => "Anthropic",
        AiApiAuditLog::Provider::HuggingFaceTextGeneration => "Hugging Face",
        AiApiAuditLog::Provider::Gemini => "Gemini",
        AiApiAuditLog::Provider::Vllm => "vLLM",
        AiApiAuditLog::Provider::Cohere => "Cohere",
        AiApiAuditLog::Provider::Ollama => "Ollama",
        AiApiAuditLog::Provider::SambaNova => "SambaNova",
        AiApiAuditLog::Provider::Mistral => "Mistral",
        AiApiAuditLog::Provider::OpenRouter => "OpenRouter",
        AiApiAuditLog::Provider::BedrockConverse => "Amazon Bedrock",
      }.freeze

      class << self
        def provider_name(provider_id)
          PROVIDER_NAMES[provider_id]
        end
      end
    end
  end
end
