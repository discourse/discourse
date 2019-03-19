module Jobs

  class CleanUpInactiveUsers < Jobs::Scheduled
    every 1.day

    def execute(args)
      return if SiteSetting.clean_up_inactive_users_after_days <= 0

      destroyer = UserDestroyer.new(Discourse.system_user)

      User.joins("LEFT JOIN posts ON posts.user_id = users.id")
        .where(last_posted_at: nil, trust_level: TrustLevel.levels[:newuser])
        .where(
          "posts.user_id IS NULL AND users.last_seen_at < ?",
          SiteSetting.clean_up_inactive_users_after_days.days.ago
        )
        .find_each do |user|

        begin
          destroyer.destroy(user, context: I18n.t("user.destroy_reasons.inactive_user"))
        rescue => e
          Discourse.handle_job_exception(e,
            message: "Cleaning up inactive users",
            extra: { user_id: user.id }
          )
        end
      end
    end
  end
end
