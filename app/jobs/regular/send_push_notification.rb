# frozen_string_literal: true

module Jobs
  class SendPushNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      return if (user.last_seen_at.present? && user.last_seen_at > SiteSetting.email_time_window_mins.minutes.ago)

      PushNotificationPusher.push(user, args[:payload]) if user
    end
  end
end
