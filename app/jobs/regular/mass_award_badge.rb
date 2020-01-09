# frozen_string_literal: true

module Jobs
  class MassAwardBadge < ::Jobs::Base
    def execute(args)
      badge = Badge.find_by(id: args[:badge_id])
      users = User.select(:id, :username, :locale).with_email(args[:user_emails])

      return if users.empty? || badge.nil?

      BadgeGranter.mass_grant(badge, users)
    end
  end
end
