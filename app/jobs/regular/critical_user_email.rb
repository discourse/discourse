# frozen_string_literal: true

module Jobs
  class CriticalUserEmail < UserEmail
    sidekiq_options queue: "critical"

    def execute(args)
      unless args[:recipient_email].present? && args[:notification_context] &&
               %w[account_deleted signup_after_reject].include?(args[:type].to_s)
        return super
      end

      message =
        if args[:type].to_s == "account_deleted"
          UserNotifications.account_deleted(
            args[:recipient_email],
            nil,
            notification_context: args[:notification_context],
          )
        else
          UserNotifications.signup_after_reject(
            nil,
            recipient_email: args[:recipient_email],
            reject_reason: args[:reject_reason],
            notification_context: args[:notification_context],
          )
        end
      Email::Sender.new(message, args[:type]).send
    end

    def quit_email_early?
      false
    end
  end
end
