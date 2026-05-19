# frozen_string_literal: true

module DiscourseGamification
  module GuardianExtension
    def can_see_leaderboard?(leaderboard)
      return true if leaderboard.visible_to_groups_ids.empty?
      return true if is_admin?
      return true if user && !(leaderboard.visible_to_groups_ids & user.group_ids).empty?

      false
    end
  end
end
