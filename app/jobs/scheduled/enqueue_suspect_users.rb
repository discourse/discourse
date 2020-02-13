# frozen_string_literal: true

module Jobs
  class EnqueueSuspectUsers < ::Jobs::Scheduled
    every 2.hours

    def execute(_args)
      return unless SiteSetting.approve_suspect_users

      users = AdminUserIndexQuery.new
        .suspect_users
        .joins("LEFT OUTER JOIN reviewables r ON r.target_id = users.id AND r.target_type = 'User'")
        .where('r.id IS NULL')
        .limit(10)

      users.each do |user|
        user_profile = user.user_profile

        reviewable = ReviewableUser.needs_review!(
          target: user,
          created_by: Discourse.system_user,
          reviewable_by_moderator: true,
          payload: {
            username: user.username,
            name: user.name,
            email: user.email,
            bio: user_profile.bio_raw,
            website: user_profile.website,
          }
        )

        if reviewable.created_new
          reviewable.add_score(
            Discourse.system_user,
            ReviewableScore.types[:needs_approval],
            reason: :suspect_user,
            force_review: true
          )
        end
      end
    end
  end
end
