# frozen_string_literal: true

module DiscourseAutomation
  class UserBadgeGrantedHandler
    def self.handle(automation, badge_id, user_id)
      tracked_badge_id = automation.trigger_field('badge')['value']
      if tracked_badge_id != badge_id
        return
      end

      badge = Badge.find(badge_id)

      only_first_grant = automation.trigger_field('only_first_grant')['value']
      if only_first_grant && badge.grant_count > 1
        return
      end

      user = User.find(user_id)

      automation.trigger!(
        'kind' => DiscourseAutomation::Triggerable::USER_BADGE_GRANTED,
        'usernames' => [user.username],
        'badge' => badge,
        'placeholders' => {
          'badge_name' => badge.name,
          'grant_count' => badge.grant_count
        }
      )
    end
  end
end
