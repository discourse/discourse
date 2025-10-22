# frozen_string_literal: true

module Jobs
  class RemindUser < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      user = User.find_by(id: args[:user_id])
      raise Discourse::InvalidParameters.new(:user_id) if user.nil?

      PendingAssignsReminder.new.remind(user)
    end
  end
end
