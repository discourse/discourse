# frozen_string_literal: true

module Jobs
  class UserSuspensionExpired < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      return if user.nil?

      UserSuspender.expire(
        user,
        suspended_at: Time.iso8601(args[:suspended_at]),
        suspended_till: Time.iso8601(args[:suspended_till]),
      )
    end
  end
end
