# frozen_string_literal: true

module Live
  class Statistics
    def self.about_users
      return {} unless SiteSetting.live_enabled && SiteSetting.live_analytics_enabled

      { "7_days": Live::Session.where("joined_at > ?", 7.days.ago).distinct.count(:user_id) }
    end
  end
end
