# frozen_string_literal: true

module Voice
  class Statistics
    def self.about_users
      return {} unless SiteSetting.voice_enabled && SiteSetting.voice_analytics_enabled

      { "7_days": Voice::Session.where("joined_at > ?", 7.days.ago).distinct.count(:user_id) }
    end
  end
end
