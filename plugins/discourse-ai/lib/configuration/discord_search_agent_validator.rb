# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class DiscordSearchAgentValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if !agent_mode_enabled?(val)

        agent = AiAgent.find_by(id: selected_agent_id(val))
        agent&.user_id.present?
      end

      def error_message
        I18n.t("discourse_ai.discord.configuration.agent_user_required")
      end

      private

      def agent_mode_enabled?(val)
        enabled_value = value_for(:ai_discord_search_enabled, val)
        mode_value = value_for(:ai_discord_search_mode, val)

        truthy?(enabled_value) && mode_value == "agent"
      end

      def selected_agent_id(val)
        value_for(:ai_discord_search_agent, val).to_i
      end

      def value_for(setting_name, val)
        @opts[:name] == setting_name ? val : SiteSetting.public_send(setting_name)
      end

      def truthy?(val)
        val == true || val == "t" || val == "true"
      end
    end
  end
end
