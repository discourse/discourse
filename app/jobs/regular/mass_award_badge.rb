# frozen_string_literal: true

module Jobs
  class MassAwardBadge < ::Jobs::Base
    def execute(args)
      return unless mode = args[:mode]
      badge = Badge.find_by(id: args[:badge_id])

      users = User.select(:id, :username, :locale)

      if mode == 'email'
        users = users.with_email(args[:users_batch])
      else
        users = users.where(username_lower: args[:users_batch].map!(&:downcase))
      end

      return if users.empty? || badge.nil?

      BadgeGranter.mass_grant(badge, users)
    end
  end
end
