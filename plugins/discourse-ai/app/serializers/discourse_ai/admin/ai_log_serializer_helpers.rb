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
        AiApiAuditLog::Provider::SystemOne => "System One",
        AiApiAuditLog::Provider::OpenAiDecisions => "OpenAI Decisions",
      }.freeze

      def self.outcome(log)
        successful =
          if log.response_status.nil?
            log.response_tokens.to_i > 0
          else
            log.response_status.between?(200, 299)
          end
        return "failed" if !successful

        case log.completion_state
        when AiApiAuditLog::CompletionState::EMPTY
          "empty"
        when AiApiAuditLog::CompletionState::TRUNCATED
          "truncated"
        else
          "successful"
        end
      end

      def self.provider_name(provider_id)
        PROVIDER_NAMES[provider_id]
      end
    end
  end
end
