# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class AgentEnumerator < ::EnumSiteSetting
      class << self
        def valid_value?(val)
          true
        end

        def values
          AiAgent
            .all_agents(enabled_only: false)
            .map { |agent| { name: agent.name, value: agent.id } }
        end
      end
    end
  end
end
