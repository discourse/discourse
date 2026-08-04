# frozen_string_literal: true

module DiscourseWorkflows
  class NodePreviewsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    RATE_LIMIT = 60
    RATE_PERIOD = 60

    before_action :rate_limit_preview, only: :create

    def create
      Workflow::PreviewNode.call(service_params) do |result|
        on_success { |output:| render json: output }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:node_type_previewable) { head :unprocessable_entity }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:node) { raise Discourse::NotFound }
        on_model_not_found(:node_type_class) { raise Discourse::NotFound }
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

    def rate_limit_preview
      RateLimiter.new(
        current_user,
        "workflow-node-preview",
        RATE_LIMIT,
        RATE_PERIOD,
        apply_limit_to_staff: true,
      ).performed!
    end
  end
end
