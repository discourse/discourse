# frozen_string_literal: true

module DiscourseWorkflows
  class ModalDismissalsController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :check_rate_limit

    def create
      DiscourseWorkflows::Modal::Dismiss.call(service_params) do
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

    def check_rate_limit
      RateLimiter.new(
        current_user,
        "workflow_modal_dismiss:#{request.remote_ip}",
        10,
        60,
      ).performed!
    end
  end
end
