# frozen_string_literal: true

module DiscourseWorkflows
  module AdminAssistant
    class Capability
      FEATURE = :workflow_authoring

      def self.status(user:, phase:)
        access(user:, phase:).allowed ? public_status : :restricted
      end

      def self.authorized?(user)
        user&.admin? && user.guardian.can_manage_workflows?
      end

      def self.visible?(user)
        authorized?(user) && status(user:, phase: :visibility) == :available
      end

      def self.public_status
        return :disabled unless SiteSetting.discourse_ai_enabled && AiAuthoringEnqueuer.enabled?

        agent = authoring_agent
        return :unconfigured if !agent&.enabled?

        model_id = agent.default_llm_id || SiteSetting.ai_default_llm_model.presence
        model = LlmModel.find_by(id: model_id)
        return :unconfigured if !model&.valid?

        :available
      end
      private_class_method :public_status

      def self.message(user:, phase:)
        access = access(user:, phase:)
        return access.message if !access.allowed && access.message.present?

        key = access.allowed ? public_status : :restricted
        I18n.t("discourse_workflows.admin_assistant.availability.#{key}")
      end

      def self.access(user:, phase:)
        DiscourseAi::Agents::AdminAssistantAccess.check(feature: FEATURE, user:, phase:)
      end
      private_class_method :access

      def self.authoring_agent
        configured_id = SiteSetting.discourse_workflows_workflow_authoring_agent.to_i
        default_id =
          DiscourseAi::Agents::Agent.external_agent_id(DiscourseWorkflows::AiWorkflowAuthor)
        AiAgent.find_by(id: configured_id) || AiAgent.find_by(id: default_id)
      end
      private_class_method :authoring_agent
    end
  end
end
