require_dependency 'avatar_detector'

module Jobs

  class DetectAvatars < Jobs::Scheduled
    recurrence { daily.hour_of_day(8) }

    def execute(args)
      return unless SiteSetting.detect_custom_avatars?

      # Find a random sampling of users of trust level 1 or higher who don't have a custom avatar.
      user_stats = UserStat.where('user_stats.has_custom_avatar = false AND users.trust_level > 0')
                           .includes(:user)
                           .order("random()")
                           .limit(SiteSetting.max_daily_gravatar_crawls)

      if user_stats.present?
        user_stats.each do |us|
          us.update_column(:has_custom_avatar, true) if AvatarDetector.new(us.user).has_custom_avatar?
          UserHistory.create!(
            action: UserHistory.actions[:checked_for_custom_avatar],
            target_user_id: us.user_id
          )
        end
      end
    end

  end

end