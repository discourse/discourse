# frozen_string_literal: true

class OnboardingPopup
  def self.types
    @types ||= Enum.new(
      first_notification: 1,
      topic_timeline: 2,
      user_card: 4,
    )
  end
end
