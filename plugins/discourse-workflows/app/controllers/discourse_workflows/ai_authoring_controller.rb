# frozen_string_literal: true

module DiscourseWorkflows
  class AiAuthoringController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    MODES = %w[create edit explain debug].freeze

    def create
      raise Discourse::NotFound if !DiscourseWorkflows::AiAuthoringEnqueuer.enabled?

      rate_limit!

      message = params.require(:message).to_s.strip
      if message.blank?
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_workflows.ai.error_message_required"),
              )
      end
      if message.length > SiteSetting.discourse_workflows_ai_authoring_max_prompt_length
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_workflows.ai.error_message_too_long"),
              )
      end

      mode = params[:mode].presence || default_mode
      if MODES.exclude?(mode)
        raise Discourse::InvalidParameters.new(I18n.t("discourse_workflows.ai.error_invalid_mode"))
      end

      session = find_or_create_session!(mode:, message:)
      generation_id = SecureRandom.hex

      DiscourseWorkflows::AiAuthoringEnqueuer.enqueue(
        session: session,
        generation_id: generation_id,
        user: current_user,
      )

      render json: { session_id: session.id, generation_id: generation_id, status: "generating" }
    end

    def apply
      raise Discourse::NotFound if !DiscourseWorkflows::AiAuthoringEnqueuer.enabled?

      session =
        DiscourseWorkflows::AiAuthoringSession.find_by!(
          id: params.require(:session_id),
          user_id: current_user.id,
          workflow_id: params.require(:workflow_id),
        )
      if session.status != "proposal_ready"
        render(
          json:
            failed_json.merge(errors: [I18n.t("discourse_workflows.ai.error_proposal_not_ready")]),
          status: :unprocessable_entity,
        )
        return
      end

      workflow = session.workflow || raise(Discourse::NotFound)
      proposal = session.proposed_patch || {}
      operations = proposal["operations"] || proposal[:operations]
      if operations.blank?
        raise Discourse::InvalidParameters.new(I18n.t("discourse_workflows.ai.error_no_operations"))
      end

      return if stale_proposal?(session, workflow)

      result =
        DiscourseWorkflows::Workflow::Action::ApplyPatch.call(
          workflow: workflow,
          operations: operations,
          persist: true,
          user: current_user,
        )

      if !result[:valid]
        render json: failed_json.merge(errors: result[:errors]), status: :unprocessable_entity
        return
      end

      session.update!(status: "applied", applied_at: Time.current)
      log_ai_patch_applied(workflow, session, result)

      render_serialized(workflow.reload, DiscourseWorkflows::WorkflowSerializer, root: "workflow")
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

    def default_mode
      workflow_id.present? ? "edit" : "create"
    end

    def workflow_id
      params[:workflow_id].presence || params[:id].presence
    end

    def find_or_create_session!(mode:, message:)
      session = existing_session || new_session
      refresh_session_base_graph!(session)
      session.latest_request = message
      session.append_message!(type: :user, content: build_user_message(mode:, message:))
      session
    end

    def existing_session
      return nil if params[:session_id].blank?

      session =
        DiscourseWorkflows::AiAuthoringSession.find_by!(
          id: params[:session_id],
          user_id: current_user.id,
        )

      if workflow_id.present?
        raise Discourse::NotFound if session.workflow_id.to_s != workflow_id.to_s
      elsif session.workflow_id.present?
        raise Discourse::NotFound
      end

      session
    end

    def new_session
      workflow = nil
      if workflow_id.present?
        workflow = DiscourseWorkflows::Workflow.find_by(id: workflow_id)
        raise Discourse::NotFound if workflow.blank?
      end

      DiscourseWorkflows::AiAuthoringSession.create!(
        workflow: workflow,
        user: current_user,
        status: "drafting",
        messages: [],
        base_workflow_version_id: workflow&.version_id,
        base_graph_digest: workflow ? DiscourseWorkflows::Ai::GraphDigest.call(workflow) : nil,
      )
    end

    def refresh_session_base_graph!(session)
      return if session.workflow.blank?

      session.base_workflow_version_id = session.workflow.version_id
      session.base_graph_digest = DiscourseWorkflows::Ai::GraphDigest.call(session.workflow)
    end

    def build_user_message(mode:, message:)
      payload = { mode: mode, message: message, workflow_id: workflow_id }.compact

      JSON.pretty_generate(payload)
    end

    def stale_proposal?(session, workflow)
      return false if session.base_graph_digest.blank?

      current_digest = DiscourseWorkflows::Ai::GraphDigest.call(workflow)
      return false if current_digest == session.base_graph_digest

      render(
        json: failed_json.merge(errors: [I18n.t("discourse_workflows.ai.error_stale_proposal")]),
        status: :conflict,
      )
      true
    end

    def log_ai_patch_applied(workflow, session, result)
      created_ai_agent_count =
        Array.wrap(result[:created_resources]).count { |resource| resource["type"] == "ai_agent" }

      StaffActionLogger.new(current_user).log_custom(
        "discourse_workflows_ai_proposal_applied",
        subject: workflow.name,
        workflow_id: workflow.id,
        ai_authoring_session_id: session.id,
        risk_level: session.risk_level,
        operation_count: result.dig(:diff, :operation_count),
        created_ai_agent_count: created_ai_agent_count,
      )
    end
  end
end
