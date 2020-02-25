# frozen_string_literal: true

module Jobs

  class CleanUpUnusedStagedUsers < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      destroyer = UserDestroyer.new(Discourse.system_user)

      User.joins("LEFT JOIN posts ON posts.user_id = users.id")
        .where("posts.user_id IS NULL")
        .where(staged: true, admin: false, moderator: false)
        .where("users.created_at < ?", 1.year.ago)
        .find_each do |user|

        begin
          destroyer.destroy(user, context: I18n.t("user.destroy_reasons.unused_staged_user"))
        rescue => e
          Discourse.handle_job_exception(e,
            message: "Cleaning up unused staged user",
            extra: { user_id: user.id }
          )
        end
      end
    end

  end

end
