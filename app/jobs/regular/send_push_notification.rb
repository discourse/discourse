# frozen_string_literal: true

module Jobs
  class SendPushNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      if !user || user.seen_since?(SiteSetting.push_notification_time_window_mins.minutes.ago)
        return
      end

      PushNotificationPusher.push(user, args[:payload])
    end
  end
end
