# frozen_string_literal: true

module Jobs
  class MassAwardBadge < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user])
      return if user.blank?
      badge = Badge.find_by(enabled: true, id: args[:badge])
      return if badge.blank?

      grant_existing_holders = args[:grant_existing_holders]
      count = args[:count]
      count = 1 if !grant_existing_holders
      BadgeGranter.mass_grant(badge, user, count: count, allow_multiple_grants: grant_existing_holders)
    end
  end
end
