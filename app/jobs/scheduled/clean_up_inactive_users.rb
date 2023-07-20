# frozen_string_literal: true

module Jobs
  class CleanUpInactiveUsers < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return if SiteSetting.clean_up_inactive_users_after_days <= 0

      User
        .where(
          last_posted_at: nil,
          trust_level: TrustLevel.levels[:newuser],
          admin: false,
          moderator: false,
        )
        .where("users.created_at < ?", SiteSetting.clean_up_inactive_users_after_days.days.ago)
        .where(
          "users.last_seen_at < ? OR users.last_seen_at IS NULL",
          SiteSetting.clean_up_inactive_users_after_days.days.ago,
        )
        .where
        .missing(:posts, :topics)
        .limit(1000)
        .pluck(:id)
        .each_slice(50) { |slice| destroy(slice) }
    end

    private

    def destroy(ids)
      destroyer = UserDestroyer.new(Discourse.system_user)

      User.transaction do
        ids.each do |id|
          begin
            user = User.find_by(id: id)
            next unless user
            destroyer.destroy(
              user,
              transaction: false,
              context: I18n.t("user.destroy_reasons.inactive_user"),
            )
          rescue => e
            Discourse.handle_job_exception(
              e,
              message: "Cleaning up inactive users",
              extra: {
                user_id: id,
              },
            )
            raise e
          end
        end
      end
    end
  end
end
