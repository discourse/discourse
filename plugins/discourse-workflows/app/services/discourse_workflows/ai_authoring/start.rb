# frozen_string_literal: true

module DiscourseWorkflows
  module AiAuthoring
    class Start
      include Service::Base

      MODES = %w[create edit explain debug].freeze

      policy :ai_authoring_enabled

      params do
        attribute :message, :string
        attribute :mode, :string
        attribute :workflow_id, :integer
        attribute :session_id, :integer

        before_validation :normalize_message

        validate :message_is_present
        validate :message_length_is_valid
        validate :mode_is_supported

        def effective_mode
          mode.presence || (workflow_id.present? ? "edit" : "create")
        end

        def user_message
          JSON.pretty_generate(
            { mode: effective_mode, message: message, workflow_id: workflow_id }.compact,
          )
        end

        private

        def normalize_message
          self.message = message.to_s.strip
        end

        def message_is_present
          if message.blank?
            errors.add(:base, I18n.t("discourse_workflows.ai.error_message_required"))
          end
        end

        def message_length_is_valid
          return if message.length <= SiteSetting.discourse_workflows_ai_authoring_max_prompt_length

          errors.add(:base, I18n.t("discourse_workflows.ai.error_message_too_long"))
        end

        def mode_is_supported
          return if DiscourseWorkflows::AiAuthoring::Start::MODES.include?(effective_mode)

          errors.add(:base, I18n.t("discourse_workflows.ai.error_invalid_mode"))
        end
      end

      policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
      model :workflow, optional: true
      policy :workflow_exists_when_requested

      only_if(:existing_session_requested) { model :session, :find_existing_session }
      only_if(:new_session_requested) { model :session, :create_session }
      only_if(:session_has_workflow) { step :refresh_session_base_graph }
      step :record_authoring_request

      model :generation_id, :generate_generation_id
      step :enqueue_authoring

      private

      def ai_authoring_enabled
        DiscourseWorkflows::AiAuthoringEnqueuer.enabled?
      end

      def fetch_workflow(params:)
        DiscourseWorkflows::Workflow.find_by(id: params.workflow_id) if params.workflow_id.present?
      end

      def workflow_exists_when_requested(params:, workflow:)
        params.workflow_id.blank? || workflow.present?
      end

      def existing_session_requested(params:)
        params.session_id.present?
      end

      def new_session_requested(params:)
        params.session_id.blank?
      end

      def find_existing_session(params:, guardian:)
        DiscourseWorkflows::AiAuthoringSession.find_by(
          id: params.session_id,
          user_id: guardian.user.id,
          workflow_id: params.workflow_id,
        )
      end

      def create_session(guardian:, workflow:)
        DiscourseWorkflows::AiAuthoringSession.create(
          workflow: workflow,
          user: guardian.user,
          status: "drafting",
          messages: [],
          base_workflow_version_id: workflow&.version_id,
          base_graph_digest: workflow ? DiscourseWorkflows::Ai::GraphDigest.call(workflow) : nil,
        )
      end

      def session_has_workflow(session:)
        session.workflow.present?
      end

      def refresh_session_base_graph(session:)
        session.base_workflow_version_id = session.workflow.version_id
        session.base_graph_digest = DiscourseWorkflows::Ai::GraphDigest.call(session.workflow)
      end

      def record_authoring_request(session:, params:)
        session.latest_request = params.message
        session.append_message!(type: :user, content: params.user_message)
      end

      def generate_generation_id
        SecureRandom.hex
      end

      def enqueue_authoring(session:, generation_id:, guardian:)
        DiscourseWorkflows::AiAuthoringEnqueuer.enqueue(
          session: session,
          generation_id: generation_id,
          user: guardian.user,
        )
      end
    end
  end
end
