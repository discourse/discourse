# this class is used to mirror unread and new status back to end users
# in JavaScript there is a mirror class that is kept in-sync using the mssage bus
# the allows end users to always know which topics have unread posts in them
# and which topics are new

class UserTrackingState

  CHANNEL = "/user-tracking"

  attr_accessor :user_id, :topic_id, :highest_post_number, :last_read_post_number, :created_at

  MessageBus.client_filter(CHANNEL) do |user_id, message|
    if user_id
      UserTrackingState.new(User.find(user_id)).filter(message)
    else
      nil
    end
  end

  def self.trigger_change(topic_id, post_number, user_id=nil)
    MessageBus.publish(CHANNEL, "CHANGE", user_ids: [user_id].compact)
  end

  def self.treat_as_new_topic_clause
    User.where("CASE
                  WHEN COALESCE(u.new_topic_duration_minutes, :default_duration) = :always THEN u.created_at
                  WHEN COALESCE(u.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(u.previous_visit_at,u.created_at)
                  ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(u.new_topic_duration_minutes, :default_duration))
               END",
                now: DateTime.now,
                last_visit: User::NewTopicDuration::LAST_VISIT,
                always: User::NewTopicDuration::ALWAYS,
                default_duration: SiteSetting.new_topic_duration_minutes
              ).where_values[0]
  end

  def self.report(user_ids, topic_id = nil)

    # Sam: this is a hairy report, in particular I need custom joins and fancy conditions
    #  Dropping to sql_builder so I can make sense of it.
    #
    # Keep in mind, we need to be able to filter on a GROUP of users, and zero in on topic
    #  all our existing scope work does not do this
    #
    # This code needs to be VERY efficient as it is triggered via the message bus and may steal
    #  cycles from usual requests
    #

    unread = TopicQuery.unread_filter(Topic).where_values.join(" AND ")
    new = TopicQuery.new_filter(Topic, "xxx").where_values.join(" AND ").gsub!("'xxx'", treat_as_new_topic_clause)

    sql = <<SQL
    SELECT u.id AS user_id, topics.id AS topic_id, topics.created_at, highest_post_number, last_read_post_number
    FROM users u
    FULL OUTER JOIN topics ON 1=1
    LEFT JOIN topic_users tu ON tu.topic_id = topics.id AND tu.user_id = u.id
    LEFT JOIN categories c ON c.id = topics.id
    WHERE u.id IN (:user_ids) AND
          topics.archetype <> 'private_message' AND
          ((#{unread}) OR (#{new})) AND
          (topics.visible OR u.admin OR u.moderator) AND
          topics.deleted_at IS NULL AND
          ( category_id IS NULL OR NOT c.secure OR category_id IN (
              SELECT c2.id FROM categories c2
              JOIN category_groups cg ON cg.category_id = c2.id
              JOIN group_users gu ON gu.user_id = u.id AND cg.group_id = gu.group_id
              WHERE c2.secure )
          )

SQL

    if topic_id
      sql << " AND topics.id = :topic_id"
    end

    SqlBuilder.new(sql)
      .map_exec(UserTrackingState, user_ids: user_ids, topic_id: topic_id)

  end

end
