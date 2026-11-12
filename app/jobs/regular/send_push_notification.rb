# frozen_string_literal: true

module Jobs
  # @deprecated Use Jobs::DeliverPushNotification instead.
  # Kept for backward compatibility with in-flight Sidekiq jobs.
  class SendPushNotification < ::Jobs::Base
    def execute(args)
      Jobs::DeliverPushNotification.new.execute(args)
    end
  end
end
