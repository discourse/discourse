# frozen_string_literal: true

class OnboardingPopup
  def self.types
    @types ||= Enum.new(
      first_notification: 1,
      topic_timeline: 2,
    )
  end
end
