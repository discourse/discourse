# frozen_string_literal: true

module Jobs
  class SendPushNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      PushNotificationPusher.push(user, args[:payload]) if user
    end
  end
end
