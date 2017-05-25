module Jobs
  class UpdateFirstTopicUnreadAt < Jobs::Scheduled
    every 1.day

    def execute(args)
      UserStat.update_first_topic_unread_at!
    end
  end
end
