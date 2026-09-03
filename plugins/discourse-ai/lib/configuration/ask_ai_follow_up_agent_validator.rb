# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class AskAiFollowUpAgentValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(value)
        agent = AiAgent.find_by(id: value.to_i)
        return invalid(:agent_missing) if agent.blank?
        return invalid(:agent_disabled) if !agent.enabled?
        return invalid(:personal_messages_disabled) if !agent.allow_personal_messages
        return invalid(:allowed_groups_missing) if agent.allowed_group_ids.blank?

        true
      end

      def error_message
        I18n.t("discourse_ai.ask_ai.configuration.#{@error_key}")
      end

      private

      def invalid(error_key)
        @error_key = error_key
        false
      end
    end
  end
end
