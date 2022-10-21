# frozen_string_literal: true

class OnboardingPopup
  def self.types
    @types ||= Enum.new(
      first_notification: 1,
      topic_timeline: 2,
      topic_notification_levels: 5,
      topic_menu: 6,
      suggested_topics: 7,
    )
  end
end
