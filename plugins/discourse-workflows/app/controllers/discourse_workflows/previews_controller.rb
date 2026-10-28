# frozen_string_literal: true

module DiscourseWorkflows
  class PreviewsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    before_action :enforce_simulation_quota

    def create
      DiscourseWorkflows::Workflow::Preview.call(service_params) do |result|
        on_success do |execution:|
          render json: {
                   execution: {
                     id: execution.id,
                     workflow_id: execution.workflow_id,
                   },
                 },
                 status: :created
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_tests_enabled) { raise Discourse::NotFound }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:trigger_node) { raise Discourse::NotFound }
        on_model_not_found(:trigger_payload) do
          render(
            json:
              failed_json.merge(
                errors: [I18n.t("discourse_workflows.tests.errors.no_sample_input")],
              ),
            status: :unprocessable_entity,
          )
        end
      end
    end

    private

    def enforce_simulation_quota
      RateLimiter.new(
        current_user,
        "discourse-workflows-simulations",
        SiteSetting.discourse_workflows_max_simulations_per_hour,
        1.hour,
        apply_limit_to_staff: true,
      ).performed!
    end
  end
end
