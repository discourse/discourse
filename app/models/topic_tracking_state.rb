# this class is used to mirror unread and new status back to end users
# in JavaScript there is a mirror class that is kept in-sync using the mssage bus
# the allows end users to always know which topics have unread posts in them
# and which topics are new

class TopicTrackingState

  include ActiveModel::SerializerSupport

  CHANNEL = "/user-tracking"

  attr_accessor :user_id, :topic_id, :highest_post_number, :last_read_post_number, :created_at, :category_name

  def self.publish_new(topic)

    message = {
      topic_id: topic.id,
      message_type: "new_topic",
      payload: {
        last_read_post_number: nil,
        highest_post_number: 1,
        created_at: topic.created_at,
        topic_id: topic.id
      }
    }

    group_ids = topic.category && topic.category.secure_group_ids

    MessageBus.publish("/new", message.as_json, group_ids: group_ids)
    publish_read(topic.id, 1, topic.user_id)
  end

  def self.publish_unread(post)
    # TODO at high scale we are going to have to defer this,
    #   perhaps cut down to users that are around in the last 7 days as well
    #
    group_ids = post.topic.category && post.topic.category.secure_group_ids

    TopicUser
        .tracking(post.topic_id)
        .select([:user_id,:last_read_post_number])
        .each do |tu|

      message = {
        topic_id: post.topic_id,
        message_type: "unread",
        payload: {
          last_read_post_number: tu.last_read_post_number,
          highest_post_number: post.post_number,
          created_at: post.created_at,
          topic_id: post.topic_id
        }
      }

      MessageBus.publish("/unread/#{tu.user_id}", message.as_json, group_ids: group_ids)

    end
  end

  def self.publish_read(topic_id, last_read_post_number, user_id)

      highest_post_number = Topic.where(id: topic_id).pluck(:highest_post_number).first

      message = {
        topic_id: topic_id,
        message_type: "read",
        payload: {
          last_read_post_number: last_read_post_number,
          highest_post_number: highest_post_number,
          topic_id: topic_id
        }
      }

      MessageBus.publish("/unread/#{user_id}", message.as_json, user_ids: [user_id])
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
    SELECT u.id AS user_id, topics.id AS topic_id, topics.created_at, highest_post_number, last_read_post_number, c.name AS category_name
    FROM users u
    FULL OUTER JOIN topics ON 1=1
    LEFT JOIN topic_users tu ON tu.topic_id = topics.id AND tu.user_id = u.id
    LEFT JOIN categories c ON c.id = topics.category_id
    WHERE u.id IN (:user_ids) AND
          topics.archetype <> 'private_message' AND
          ((#{unread}) OR (#{new})) AND
          (topics.visible OR u.admin OR u.moderator) AND
          topics.deleted_at IS NULL AND
          ( category_id IS NULL OR NOT c.read_restricted OR category_id IN (
              SELECT c2.id FROM categories c2
              JOIN category_groups cg ON cg.category_id = c2.id
              JOIN group_users gu ON gu.user_id = u.id AND cg.group_id = gu.group_id
              WHERE c2.read_restricted )
          )

SQL

    if topic_id
      sql << " AND topics.id = :topic_id"
    end

    SqlBuilder.new(sql)
      .map_exec(TopicTrackingState, user_ids: user_ids, topic_id: topic_id)

  end

end
