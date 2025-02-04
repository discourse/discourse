# frozen_string_literal: true

module Jobs
  class SendPushNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      push_window = SiteSetting.push_notification_time_window_mins
      return if !user || (push_window > 0 && user.seen_since?(push_window.minutes.ago))

      PushNotificationPusher.push(user, args[:payload])
    end
  end
end
