module Jobs

  class Tl3Promotions < Jobs::Scheduled
    daily at: 4.hours

    def execute(args)
      # Demotions
      demoted_user_ids = []
      User.real.where(
        trust_level: TrustLevel[3],
        manual_locked_trust_level: nil,
        group_locked_trust_level: nil
      ).find_each do |u|
        # Don't demote too soon after being promoted
        next if u.on_tl3_grace_period?

        if Promotion.tl3_lost?(u)
          demoted_user_ids << u.id
          Promotion.new(u).change_trust_level!(TrustLevel[2])
        end
      end

      # Promotions
      User.real.not_suspended.where(
          trust_level: TrustLevel[2],
          manual_locked_trust_level: nil,
          group_locked_trust_level: nil
        ).where.not(id: demoted_user_ids)
        .joins(:user_stat)
        .where("user_stats.days_visited >= ?", SiteSetting.tl3_requires_days_visited)
        .where("user_stats.topic_reply_count >= ?", SiteSetting.tl3_requires_topics_replied_to)
        .where("user_stats.topics_entered >= ?", SiteSetting.tl3_requires_topics_viewed_all_time)
        .where("user_stats.posts_read_count >= ?", SiteSetting.tl3_requires_posts_read_all_time)
        .where("user_stats.likes_given >= ?", SiteSetting.tl3_requires_likes_given)
        .where("user_stats.likes_received >= ?", SiteSetting.tl3_requires_likes_received)
        .find_each do |u|
        Promotion.new(u).review_tl2
      end

    end
  end

end
