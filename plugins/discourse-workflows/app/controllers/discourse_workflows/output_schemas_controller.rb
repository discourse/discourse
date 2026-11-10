# frozen_string_literal: true

module DiscourseWorkflows
  class OutputSchemasController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    RATE_LIMIT = 240
    RATE_PERIOD = 60

    before_action :rate_limit_resolution, only: :create

    def create
      Workflow::ResolveOutputSchemas.call(service_params) do
        on_success { |output_schemas:| render json: { output_schemas: } }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_exceptions(Schema::GraphResolver::NotConverged) do
          render(json: failed_json, status: :unprocessable_entity)
        end
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
      end
    end

    private

    def rate_limit_resolution
      RateLimiter.new(
        current_user,
        "workflow-output-schemas",
        RATE_LIMIT,
        RATE_PERIOD,
        apply_limit_to_staff: true,
      ).performed!
    end
  end
end
