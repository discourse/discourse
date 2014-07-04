module Jobs
  class UpdateBadges < Jobs::Base

    def execute(args)
      self.send(args[:action], args)
    end

    def trust_level_change(args)
      user = User.find(args[:user_id])
      trust_level = user.trust_level
      Badge.trust_level_badge_ids.each do |badge_id|
        user_badge = UserBadge.find_by(user_id: user.id, badge_id: badge_id)
        if user_badge
          # Revoke the badge if trust level was lowered.
          BadgeGranter.revoke(user_badge) if trust_level < badge_id
        else
          # Grant the badge if trust level was increased.
          badge = Badge.find(badge_id)
          BadgeGranter.grant(badge, user) if trust_level >= badge_id
        end
      end
    end

    def post_like(args)
      post = Post.find(args[:post_id])
      user = post.user

      # Grant "Welcome" badge to the user if they do not already have it.
      BadgeGranter.grant(Badge.find(Badge::Welcome), user)

      Badge.like_badge_counts.each do |badge_id, count|
        if post.like_count >= count
          BadgeGranter.grant(Badge.find(badge_id), user, post_id: post.id)
        else
          user_badge = UserBadge.find_by(badge_id: badge_id, user_id: user.id, post_id: post.id)
          user_badge && BadgeGranter.revoke(user_badge)
        end
      end
    end

  end
end
