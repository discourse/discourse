module Jobs

  class CleanUpUnusedStagedUsers < Jobs::Scheduled
    every 1.day

    def execute(args)
      destroyer = UserDestroyer.new(Discourse.system_user)

      User.joins(:user_stat)
          .where(staged: true)
          .where("users.created_at < ?", 1.year.ago)
          .where("user_stats.post_count = 0")
          .find_each { |user| destroyer.destroy(user) }
    end

  end

end
