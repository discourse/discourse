# frozen_string_literal: true

module DiscourseAutomation
  class UserBadgeGrantedHandler
    def self.handle(automation, badge_id, user_id)
      tracked_badge_id = automation.trigger_field("badge")["value"]
      return if tracked_badge_id != badge_id

      badge = Badge.find(badge_id)

      only_first_grant = automation.trigger_field("only_first_grant")["value"]

      return if only_first_grant && UserBadge.where(user_id: user_id, badge_id: badge_id).count > 1

      user = User.find(user_id)

      automation.trigger!(
        "kind" => DiscourseAutomation::Triggers::USER_BADGE_GRANTED,
        "usernames" => [user.username],
        "badge" => badge,
        "placeholders" => {
          "badge_name" => badge.name,
          "grant_count" => badge.grant_count,
        },
      )
    end
  end
end
