# frozen_string_literal: true

module DiscourseAi
  module AdminDashboard
    def self.enabled?
      SiteSetting.ai_admin_dashboard_enabled
    end

    def self.highlights_enabled?
      highlights_feature.enabled?
    end

    def self.highlights_agent_id
      SiteSetting.ai_admin_dashboard_highlights_agent.to_i
    end

    def self.highlights_agent
      return nil if highlights_agent_id == 0

      agent = AiAgent.find_by_id_from_cache(highlights_agent_id)
      agent if agent&.enabled?
    end

    def self.highlights_agent_instance
      highlights_agent&.class_instance&.new
    end

    def self.highlights_feature
      DiscourseAi::Configuration::Feature.admin_dashboard_features.find do |feature|
        feature.name == "highlights"
      end
    end
  end
end
