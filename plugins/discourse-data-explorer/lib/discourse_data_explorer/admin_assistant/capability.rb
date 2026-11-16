# frozen_string_literal: true

module DiscourseDataExplorer
  module AdminAssistant
    class Capability
      FEATURE = :data_explorer_query_authoring

      def self.status(user:, phase:)
        access(user:, phase:).allowed ? public_status : :restricted
      end

      def self.visible?(user)
        user&.admin? && status(user:, phase: :visibility) == :available
      end

      def self.public_status
        unless SiteSetting.discourse_ai_enabled && SiteSetting.data_explorer_enabled
          return :disabled
        end
        return :generation_disabled unless SiteSetting.data_explorer_ai_queries_enabled

        agent_id =
          DiscourseAi::Agents::Agent.external_agent_id(DiscourseDataExplorer::AiQueryGenerator)
        agent = AiAgent.find_by(id: agent_id)
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
        I18n.t("discourse_data_explorer.admin_assistant.availability.#{key}")
      end

      def self.access(user:, phase:)
        DiscourseAi::Agents::AdminAssistantAccess.check(feature: FEATURE, user:, phase:)
      end
      private_class_method :access
    end
  end
end
