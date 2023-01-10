# frozen_string_literal: true

module Jobs
  class EnqueueSuspectUsers < ::Jobs::Scheduled
    every 2.hours

    def execute(_args)
      return unless SiteSetting.approve_suspect_users
      return if SiteSetting.must_approve_users

      users =
        User
          .distinct
          .activated
          .human_users
          .where(approved: false)
          .joins(:user_profile, :user_stat)
          .where("users.created_at <= ? AND users.created_at >= ?", 1.day.ago, 6.months.ago)
          .where("LENGTH(COALESCE(user_profiles.bio_raw, user_profiles.website, '')) > 0")
          .where(
            "user_stats.posts_read_count <= 1 OR user_stats.topics_entered <= 1 OR user_stats.time_read < ?",
            1.minute.to_i,
          )
          .joins(
            "LEFT OUTER JOIN reviewables r ON r.target_id = users.id AND r.target_type = 'User'",
          )
          .where("r.id IS NULL")
          .joins(<<~SQL)
            LEFT OUTER JOIN (
              SELECT user_id
              FROM user_custom_fields
              WHERE user_custom_fields.name = 'import_id'
            ) AS ucf ON ucf.user_id = users.id
          SQL
          .where("ucf.user_id IS NULL")
          .limit(10)

      users.each do |user|
        user_profile = user.user_profile

        reviewable =
          ReviewableUser.needs_review!(
            target: user,
            created_by: Discourse.system_user,
            reviewable_by_moderator: true,
            payload: {
              username: user.username,
              name: user.name,
              email: user.email,
              bio: user_profile.bio_raw,
              website: user_profile.website,
            },
          )

        if reviewable.created_new
          reviewable.add_score(
            Discourse.system_user,
            ReviewableScore.types[:needs_approval],
            reason: :suspect_user,
            force_review: true,
          )
        end
      end
    end
  end
end
