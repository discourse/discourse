# frozen_string_literal: true

class DiscourseEvents::Livestream::ResumeNotifications
  include Service::Base

  params do
    attribute :pause_key, :string

    validates :pause_key, presence: true, format: { with: /\A[0-9a-f-]{36}\z/ }
  end

  step :end_pause

  private

  def end_pause(params:, guardian:)
    UserNotificationPause.new(user: guardian.user).end(source: "livestream", key: params.pause_key)
  end
end
