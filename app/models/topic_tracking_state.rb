# this class is used to mirror unread and new status back to end users
# in JavaScript there is a mirror class that is kept in-sync using the mssage bus
# the allows end users to always know which topics have unread posts in them
# and which topics are new

class TopicTrackingState

  include ActiveModel::SerializerSupport

  CHANNEL = "/user-tracking"

  attr_accessor :user_id,
                :topic_id,
                :highest_post_number,
                :last_read_post_number,
                :created_at,
                :category_id,
                :notification_level

  def self.publish_new(topic)

    message = {
      topic_id: topic.id,
      message_type: "new_topic",
      payload: {
        last_read_post_number: nil,
        highest_post_number: 1,
        created_at: topic.created_at,
        topic_id: topic.id,
        category_id: topic.category_id,
        archetype: topic.archetype
      }
    }

    group_ids = topic.category && topic.category.secure_group_ids

    MessageBus.publish("/new", message.as_json, group_ids: group_ids)
    publish_read(topic.id, 1, topic.user_id)
  end

  def self.publish_latest(topic)
    return unless topic.archetype == "regular"

    message = {
      topic_id: topic.id,
      message_type: "latest",
      payload: {
        bumped_at: topic.bumped_at,
        topic_id: topic.id,
        category_id: topic.category_id,
        archetype: topic.archetype
      }
    }

    group_ids = topic.category && topic.category.secure_group_ids
    MessageBus.publish("/latest", message.as_json, group_ids: group_ids)
  end

  def self.publish_unread(post)
    # TODO at high scale we are going to have to defer this,
    #   perhaps cut down to users that are around in the last 7 days as well
    #
    group_ids = post.topic.category && post.topic.category.secure_group_ids

    TopicUser
        .tracking(post.topic_id)
        .select([:user_id,:last_read_post_number, :notification_level])
        .each do |tu|

      message = {
        topic_id: post.topic_id,
        message_type: "unread",
        payload: {
          last_read_post_number: tu.last_read_post_number,
          highest_post_number: post.post_number,
          created_at: post.created_at,
          topic_id: post.topic_id,
          category_id: post.topic.category_id,
          notification_level: tu.notification_level,
          archetype: post.topic.archetype
        }
      }

      MessageBus.publish("/unread/#{tu.user_id}", message.as_json, group_ids: group_ids)
    end

  end

  def self.publish_recover(topic)
    group_ids = topic.category && topic.category.secure_group_ids

    message = {
      topic_id: topic.id,
      message_type: "recover",
      payload: {
        topic_id: topic.id,
      }
    }

    MessageBus.publish("/recover", message.as_json, group_ids: group_ids)

  end

  def self.publish_delete(topic)
    group_ids = topic.category && topic.category.secure_group_ids

    message = {
      topic_id: topic.id,
      message_type: "delete",
      payload: {
        topic_id: topic.id,
      }
    }

    MessageBus.publish("/delete", message.as_json, group_ids: group_ids)
  end

  def self.publish_read(topic_id, last_read_post_number, user_id, notification_level=nil)

    highest_post_number = Topic.where(id: topic_id).pluck(:highest_post_number).first

    message = {
      topic_id: topic_id,
      message_type: "read",
      payload: {
        last_read_post_number: last_read_post_number,
        highest_post_number: highest_post_number,
        topic_id: topic_id,
        notification_level: notification_level
      }
    }

    MessageBus.publish("/unread/#{user_id}", message.as_json, user_ids: [user_id])

  end

  def self.treat_as_new_topic_clause
    User.where("GREATEST(CASE
                  WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :always THEN u.created_at
                  WHEN COALESCE(uo.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(u.previous_visit_at,u.created_at)
                  ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(uo.new_topic_duration_minutes, :default_duration))
               END, us.new_since, :min_date)",
                now: DateTime.now,
                last_visit: User::NewTopicDuration::LAST_VISIT,
                always: User::NewTopicDuration::ALWAYS,
                default_duration: SiteSetting.default_other_new_topic_duration_minutes,
                min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime
              ).where_values[0]
  end

  def self.report(user_id, topic_id = nil)

    # Sam: this is a hairy report, in particular I need custom joins and fancy conditions
    #  Dropping to sql_builder so I can make sense of it.
    #
    # Keep in mind, we need to be able to filter on a GROUP of users, and zero in on topic
    #  all our existing scope work does not do this
    #
    # This code needs to be VERY efficient as it is triggered via the message bus and may steal
    #  cycles from usual requests
    #
    #
    sql = report_raw_sql(topic_id: topic_id, skip_unread: true, skip_order: true)
    sql << "\nUNION ALL\n\n"
    sql << report_raw_sql(topic_id: topic_id, skip_new: true, skip_order: true)

    SqlBuilder.new(sql)
      .map_exec(TopicTrackingState, user_id: user_id, topic_id: topic_id)

  end


  def self.report_raw_sql(opts=nil)

    unread =
      if opts && opts[:skip_unread]
        "1=0"
      else
        TopicQuery.unread_filter(Topic).where_values.join(" AND ")
      end

    new =
      if opts && opts[:skip_new]
        "1=0"
      else
        TopicQuery.new_filter(Topic, "xxx").where_values.join(" AND ").gsub!("'xxx'", treat_as_new_topic_clause)
      end

    select = (opts && opts[:select]) || "
           u.id AS user_id,
           topics.id AS topic_id,
           topics.created_at,
           highest_post_number,
           last_read_post_number,
           c.id AS category_id,
           tu.notification_level"


    sql = <<SQL
    SELECT #{select}
    FROM topics
    JOIN users u on u.id = :user_id
    JOIN user_stats AS us ON us.user_id = u.id
    JOIN user_options AS uo ON uo.user_id = u.id
    JOIN categories c ON c.id = topics.category_id
    LEFT JOIN topic_users tu ON tu.topic_id = topics.id AND tu.user_id = u.id
    WHERE u.id = :user_id AND
          topics.archetype <> 'private_message' AND
          ((#{unread}) OR (#{new})) AND
          (topics.visible OR u.admin OR u.moderator) AND
          topics.deleted_at IS NULL AND
          ( NOT c.read_restricted OR u.admin OR category_id IN (
              SELECT c2.id FROM categories c2
              JOIN category_groups cg ON cg.category_id = c2.id
              JOIN group_users gu ON gu.user_id = :user_id AND cg.group_id = gu.group_id
              WHERE c2.read_restricted )
          )
          AND NOT EXISTS( SELECT 1 FROM category_users cu
                          WHERE last_read_post_number IS NULL AND
                               cu.user_id = :user_id AND
                               cu.category_id = topics.category_id AND
                               cu.notification_level = #{CategoryUser.notification_levels[:muted]})

SQL

    if opts && opts[:topic_id]
      sql << " AND topics.id = :topic_id"
    end

    unless opts && opts[:skip_order]
      sql << " ORDER BY topics.bumped_at DESC"
    end

    sql
  end

end
