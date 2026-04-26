# frozen_string_literal: true

require "enum_site_setting"

module DiscourseDataExplorer
  class AiAgentEnumerator < ::EnumSiteSetting
    def self.valid_value?(val)
      true
    end

    def self.values
      return [] unless defined?(::AiAgent)
      ::AiAgent
        .all_agents(enabled_only: false)
        .map { |agent| { name: agent.name, value: agent.id } }
    end
  end
end
