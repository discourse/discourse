# frozen_string_literal: true

module Jobs
  class CleanUpInactiveUsers < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return if SiteSetting.clean_up_inactive_users_after_days <= 0

      inactive_days = SiteSetting.clean_up_inactive_users_after_days.days.ago

      users_to_clean =
        User
          .where(
            last_posted_at: nil,
            trust_level: TrustLevel.levels[:newuser],
            admin: false,
            moderator: false,
          )
          .where("users.created_at < ?", inactive_days)
          .where("users.last_seen_at < ? OR users.last_seen_at IS NULL", inactive_days)
          .where
          .missing(:posts, :topics, :bookmarks)
          .where(
            "NOT EXISTS (
              SELECT 1 FROM post_actions pa
              INNER JOIN posts p ON p.id = pa.post_id
              WHERE pa.user_id = users.id
                AND pa.post_action_type_id = #{PostActionType::LIKE_POST_ACTION_ID}
                AND pa.deleted_at IS NULL
                AND p.deleted_at IS NULL
            )",
          )

      users_to_clean =
        DiscoursePluginRegistry.apply_modifier(:clean_up_inactive_users_query, users_to_clean)

      users_to_clean.limit(1000).pluck(:id).each_slice(50) { |slice| destroy(slice) }
    end

    private

    def destroy(ids)
      destroyer = UserDestroyer.new(Discourse.system_user)

      User.transaction do
        ids.each do |id|
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
