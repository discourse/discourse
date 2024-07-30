# frozen_string_literal: true

module Jobs
  class SendPushNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      return if !user

      PushNotificationPusher.push(user, args[:payload])
    end
  end
end
