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
      end
    end

    private

    # Only fired workflows count against the limit, so this turns away users who have none left.
    def check_rate_limit
      rate_limiter = ComposerPausedClaims.rate_limiter(current_user)
      if !rate_limiter.can_perform?
        raise RateLimiter::LimitExceeded.new(rate_limiter.seconds_to_wait)
      end
    end
  end
end
