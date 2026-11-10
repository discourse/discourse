# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class DsaClassificationsController < ::ApplicationController
      SUGGESTIONS_PER_MINUTE = 20

      requires_plugin PLUGIN_NAME
      requires_login

      before_action :ensure_can_see_review_queue
      before_action :rate_limit_suggestions

      def suggest
        SuggestDsaClassification.call(service_params) do
          on_success { |suggestion:| render json: suggestion.to_h }
          on_failed_contract { raise Discourse::InvalidParameters.new(:reviewable_id) }
          on_failed_policy(:classification_enabled) { raise Discourse::InvalidAccess }
          on_model_not_found(:decision_model) { raise Discourse::InvalidAccess }
          on_model_not_found(:reviewable) { raise Discourse::NotFound }
          on_model_not_found(:suggestion) { |step| render_decision_error(step.exception) }
        end
      end

      private

      def ensure_can_see_review_queue
        raise Discourse::InvalidAccess if !guardian.can_see_review_queue?
      end

      def rate_limit_suggestions
        RateLimiter.new(
          current_user,
          "ai_dsa_classification_suggestions",
          SUGGESTIONS_PER_MINUTE,
          1.minute,
          apply_limit_to_staff: true,
        ).performed!
      end

      def render_decision_error(exception)
        raise exception if !exception.is_a?(DiscourseAi::Decisions::Error)

        if exception.is_a?(DiscourseAi::Decisions::CreditLimitExceeded)
          return(
            render_json_error(
              I18n.t("discourse_ai.dsa_classification.credit_limit_exceeded"),
              status: :too_many_requests,
            )
          )
        end

        Rails.logger.warn(
          "Discourse AI: DSA classification suggestion failed: #{exception.class} #{exception.message}",
        )
        render_json_error(
          I18n.t("discourse_ai.dsa_classification.suggestion_failed"),
          status: :unprocessable_entity,
        )
      end
    end
  end
end
