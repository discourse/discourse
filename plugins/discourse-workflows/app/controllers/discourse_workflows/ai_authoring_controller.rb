# frozen_string_literal: true

module DiscourseWorkflows
  class AiAuthoringController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
      rate_limit! if DiscourseWorkflows::AiAuthoringEnqueuer.enabled?

      DiscourseWorkflows::AiAuthoring::Start.call(ai_authoring_service_params) do |result|
        on_success do |session:, generation_id:|
          render json: {
                   session_id: session.id,
                   generation_id: generation_id,
                   status: "generating",
                 }
        end
        on_failed_contract { |contract| render_failed_contract(contract) }
        on_failed_policy(:ai_authoring_enabled) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_exists_when_requested) { raise Discourse::NotFound }
        on_model_not_found(:session) { raise Discourse::NotFound }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def apply
      DiscourseWorkflows::AiAuthoring::Apply.call(ai_authoring_service_params) do |result|
        on_success do |workflow:|
          render_serialized(
            workflow.reload,
            DiscourseWorkflows::WorkflowSerializer,
            root: "workflow",
          )
        end
        on_failed_contract { |contract| render_failed_contract(contract) }
        on_failed_policy(:ai_authoring_enabled) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:proposal_ready) do
          render(
            json:
              failed_json.merge(
                errors: [I18n.t("discourse_workflows.ai.error_proposal_not_ready")],
              ),
            status: :unprocessable_entity,
          )
        end
        on_failed_policy(:proposal_current) do
          render(
            json:
              failed_json.merge(errors: [I18n.t("discourse_workflows.ai.error_stale_proposal")]),
            status: :conflict,
          )
        end
        on_failed_policy(:patch_valid) do |_policy, patch_result:|
          render json: failed_json.merge(errors: patch_result[:errors]),
                 status: :unprocessable_entity
        end
        on_model_not_found(:session) { raise Discourse::NotFound }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:operations) do
          raise Discourse::InvalidParameters.new(
                  I18n.t("discourse_workflows.ai.error_no_operations"),
                )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def rate_limit!
      RateLimiter.new(
        current_user,
        "discourse-workflows-ai-authoring",
        SiteSetting.discourse_workflows_ai_authoring_rate_limit_per_minute,
        1.minute,
        apply_limit_to_staff: true,
      ).performed!
    end

    def workflow_id
      params[:workflow_id].presence || params[:id].presence
    end

    def ai_authoring_service_params
      service_params.deep_merge(params: { workflow_id: workflow_id })
    end

    def render_failed_contract(contract)
      render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
    end
  end
end
