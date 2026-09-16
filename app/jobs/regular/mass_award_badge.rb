# frozen_string_literal: true

module Jobs
  class MassAwardBadge < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user])
      return if user.blank?
      badge = Badge.available.find_by(id: args[:badge])
      return if badge.blank?

      BadgeGranter.mass_grant(badge, user, count: args[:count])
    end
  end
end
