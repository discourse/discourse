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
        on_failed_step(:fire_triggers) { rate_limited! }
      end
    end

    private

    # The run limit only counts fired workflows, so this just turns away users who have none left.
    def check_rate_limit
      ComposerPausedClaims.attempt_rate_limiter(current_user).performed!
      rate_limited! if !ComposerPausedClaims.rate_limiter(current_user).can_perform?
    end

    def rate_limited!
      raise RateLimiter::LimitExceeded.new(
              ComposerPausedClaims.rate_limiter(current_user).seconds_to_wait,
            )
    end
  end
end
