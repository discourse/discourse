# frozen_string_literal: true

module Jobs
  class Tl3Promotions < ::Jobs::Scheduled
    daily at: 4.hours

    def execute(args)
      if SiteSetting.default_trust_level < 3
        # Demotions
        demoted_user_ids = []
        User
          .real
          .joins(
            "LEFT JOIN (SELECT gu.user_id, MAX(g.grant_trust_level) AS group_granted_trust_level FROM groups g, group_users gu WHERE g.id = gu.group_id GROUP BY gu.user_id) tl ON users.id = tl.user_id",
          )
          .where(trust_level: TrustLevel[3], manual_locked_trust_level: nil)
          .where(
            "group_granted_trust_level IS NULL OR group_granted_trust_level < ?",
            TrustLevel[3],
          )
          .find_each do |u|
            # Don't demote too soon after being promoted
            next if u.on_tl3_grace_period?

            modifier_applied, demoted_user_id =
              DiscoursePluginRegistry.apply_modifier(
                :tl3_custom_demotions,
                false,
                u,
                demoted_user_ids,
              )

            if modifier_applied
              demoted_user_ids << demoted_user_id
              next
            end

            if Promotion.tl3_lost?(u)
              demoted_user_ids << u.id
              Promotion.new(u).change_trust_level!(TrustLevel[2])
            end
          end
      end

      override =
        DiscoursePluginRegistry.apply_modifier(:tl3_custom_promotions, false, demoted_user_ids)
      return override if override

      # Promotions
      User
        .real
        .not_suspended
        .where(trust_level: TrustLevel[2], manual_locked_trust_level: nil)
        .where.not(id: demoted_user_ids)
        .joins(:user_stat)
        .where("user_stats.days_visited >= ?", SiteSetting.tl3_requires_days_visited)
        .where("user_stats.topics_entered >= ?", SiteSetting.tl3_requires_topics_viewed_all_time)
        .where("user_stats.posts_read_count >= ?", SiteSetting.tl3_requires_posts_read_all_time)
        .where("user_stats.likes_given >= ?", SiteSetting.tl3_requires_likes_given)
        .where("user_stats.likes_received >= ?", SiteSetting.tl3_requires_likes_received)
        .find_each { |u| Promotion.new(u).review_tl2 }
    end
  end
end
