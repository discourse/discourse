# frozen_string_literal: true

module DiscourseAi
  class AiCreditsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    CREDIT_STATUS_CACHE_TTL = 5.seconds

    def status
      CreditStatusChecker.call(params: status_params) do |result|
        on_success do
          expires_in CREDIT_STATUS_CACHE_TTL, public: false
          render json: {
                   personas: result[:personas],
                   features: result[:features],
                   llm_models: result[:llm_models],
                 }.compact
        end
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.join(", "))
        end
      end
    end

    private

    def status_params
      params.permit(persona_ids: [], features: [], llm_model_ids: [])
    end
  end
end
