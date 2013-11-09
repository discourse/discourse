class TrackedTopicsUpdater

  def initialize(user_id, threshold)
    @id = user_id
    @threshold = threshold
  end

  def call
    topic_users = TopicUser.where(notifications_reason_id: nil, user_id: @id)
    if @threshold < 0
      topic_users.update_all({notification_level: TopicUser.notification_levels[:regular]})
    else
      topic_users.update_all(["notification_level = CASE WHEN total_msecs_viewed < ? THEN ? ELSE ? END",
                            @threshold, TopicUser.notification_levels[:regular], TopicUser.notification_levels[:tracking]])
    end
  end
end

