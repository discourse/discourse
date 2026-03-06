# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class AgentEnumerator < ::EnumSiteSetting
      def self.valid_value?(val)
        true
      end

      def self.values
        AiAgent
          .all_agents(enabled_only: false)
          .map { |agent| { name: agent.name, value: agent.id } }
      end
    end
  end
end
