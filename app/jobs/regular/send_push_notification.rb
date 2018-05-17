module Jobs
  class SendPushNotification < Jobs::Base
    def execute(args)
      user = User.find(args[:user_id])
      PushNotificationPusher.push(user, args[:payload])
    end
  end
end
