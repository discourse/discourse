# frozen_string_literal: true

module DiscourseWorkflows
  class ExpressionsController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    RATE_LIMIT = 30
    RATE_PERIOD = 60

    before_action :rate_limit_evaluation, only: :evaluate

    def evaluate
      Expression::Evaluate.call(service_params) do |result|
        on_success { |segments:| render json: { segments: } }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def rate_limit_evaluation
      RateLimiter.new(
        current_user,
        "expression-evaluate",
        RATE_LIMIT,
        RATE_PERIOD,
        apply_limit_to_staff: true,
      ).performed!
    end
  end
end
