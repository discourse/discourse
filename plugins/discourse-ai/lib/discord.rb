# frozen_string_literal: true

module DiscourseAi
  module Discord
    # @return [Array<String>] what must be configured before Discord can search the forum
    def self.missing_setup
      missing = []
      missing << "app_id" if SiteSetting.ai_discord_app_id.blank?
      missing << "public_key" if SiteSetting.ai_discord_app_public_key.blank?
      missing << "allowed_servers" if SiteSetting.ai_discord_allowed_guilds.blank?
      missing << "agent" if agent_mode? && !agent_ready?
      missing
    end

    def self.agent_mode?
      SiteSetting.ai_discord_search_mode == "agent"
    end

    def self.agent_ready?
      AiAgent.where(id: SiteSetting.ai_discord_search_agent.to_i).where.not(user_id: nil).exists?
    end

    # @return [Hash, nil] the admin features list status, nil for the generic status
    def self.admin_status
      missing = missing_setup
      { state: "setup", note_key: "missing", missing: } if missing.present?
    end
  end
end
