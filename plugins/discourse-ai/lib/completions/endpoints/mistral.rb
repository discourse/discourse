# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Mistral < OpenAi
        class << self
          def can_contact?(llm_model)
            llm_model.provider == "mistral"
          end
        end

        def provider_id
          AiApiAuditLog::Provider::Mistral
        end
      end
    end
  end
end
