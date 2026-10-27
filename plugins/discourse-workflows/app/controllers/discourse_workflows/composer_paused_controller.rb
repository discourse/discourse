# frozen_string_literal: true

module DiscourseWorkflows
  class ComposerPausedController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :check_rate_limit

    def create
      DiscourseWorkflows::Workflow::TriggerComposerPaused.call(service_params) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:published_trigger) { raise Discourse::NotFound }
        on_failed_policy(:can_fire_trigger) { raise Discourse::InvalidAccess }
        on_failed_policy(:matches_phrases) do
          render(json: failed_json, status: :unprocessable_entity)
        end
        on_failed_policy(:has_new_phrases) do
          render(json: failed_json, status: :unprocessable_entity)
        end
      end
    end

    private

    def check_rate_limit
      ComposerPausedClaims.rate_limiter(current_user).performed!
    end
  end
end
