class TopicUser < ActiveRecord::Base
  
  belongs_to :user
  belongs_to :topic
  
  module NotificationLevel
    WATCHING = 3
    TRACKING = 2
    REGULAR = 1
    MUTED = 0
  end

  module NotificationReasons
    CREATED_TOPIC = 1
    USER_CHANGED = 2
    USER_INTERACTED = 3
    CREATED_POST = 4
  end
  
  def self.auto_track(user_id, topic_id, reason)
    if exec_sql("select 1 from topic_users where user_id = ? and topic_id = ? and notifications_reason_id is null", user_id, topic_id).count == 1
      self.change(user_id, topic_id, 
          notification_level: NotificationLevel::TRACKING, 
          notifications_reason_id: reason
      )

      MessageBus.publish("/topic/#{topic_id}", {
        notification_level_change: NotificationLevel::TRACKING,
        notifications_reason_id: reason
      }, user_ids: [user_id])
    end
  end


  # Find the information specific to a user in a forum topic
  def self.lookup_for(user, topics)

    # If the user isn't logged in, there's no last read posts
    return {} if user.blank?
    return {} if topics.blank?

    topic_ids = topics.map {|ft| ft.id}
    create_lookup(TopicUser.where(topic_id: topic_ids, user_id: user.id))
  end

  def self.create_lookup(topic_users)
    topic_users = topic_users.to_a

    result = {}
    return result if topic_users.blank?

    topic_users.each do |ftu|
      result[ftu.topic_id] = ftu
    end
    result
  end

  def self.get(topic,user)
    if Topic === topic
      topic = topic.id
    end
    if User === user
      user = user.id
    end

    TopicUser.where('topic_id = ? and user_id = ?', topic, user).first
  end

  # Change attributes for a user (creates a record when none is present). First it tries an update
  # since there's more likely to be an existing record than not. If the update returns 0 rows affected
  # it then creates the row instead.
  def self.change(user_id, topic_id, attrs)

    # Sometimes people pass objs instead of the ids. We can handle that.
    topic_id = topic_id.id if topic_id.is_a?(Topic)
    user_id = user_id.id if user_id.is_a?(User)
    
    TopicUser.transaction do
      attrs = attrs.dup
      attrs[:starred_at] = DateTime.now if attrs[:starred_at].nil? && attrs[:starred]

      if attrs[:notification_level]
        attrs[:notifications_changed_at] ||= DateTime.now 
        attrs[:notifications_reason_id] ||= TopicUser::NotificationReasons::USER_CHANGED
      end
      attrs_array = attrs.to_a

      attrs_sql = attrs_array.map {|t| "#{t[0]} = ?"}.join(", ")
      vals = attrs_array.map {|t| t[1]}
      rows = TopicUser.update_all([attrs_sql, *vals], ["topic_id = ? and user_id = ?", topic_id.to_i, user_id])
      
      if rows == 0
        now = DateTime.now
        auto_track_after = self.exec_sql("select auto_track_topics_after_msecs from users where id = ?", user_id).values[0][0]
        auto_track_after ||= SiteSetting.auto_track_topics_after
        auto_track_after = auto_track_after.to_i

        if auto_track_after >= 0 && auto_track_after <= (attrs[:total_msecs_viewed] || 0)
          attrs[:notification_level] ||= TopicUser::NotificationLevel::TRACKING
        end

        TopicUser.create(attrs.merge!(user_id: user_id, topic_id: topic_id.to_i, first_visited_at: now ,last_visited_at: now))
      end

    end
  rescue ActiveRecord::RecordNotUnique
    # In case of a race condition to insert, do nothing
  end

  def self.track_visit!(topic,user)
    now = DateTime.now
    rows = exec_sql_row_count(
      "update topic_users set last_visited_at=? where topic_id=? and user_id=?", 
      now, topic.id, user.id
    )

    if rows == 0 
      exec_sql('insert into topic_users(topic_id, user_id, last_visited_at, first_visited_at)
               values(?,?,?,?)',
               topic.id, user.id, now, now)
    end

  end

  # Update the last read and the last seen post count, but only if it doesn't exist.
  # This would be a lot easier if psql supported some kind of upsert
  def self.update_last_read(user, topic_id, post_number, msecs)
    return if post_number.blank?
    msecs = 0 if msecs.to_i < 0

    args = {
      user_id: user.id,
      topic_id: topic_id,
      post_number: post_number,
      now: DateTime.now,
      msecs: msecs, 
      tracking: TopicUser::NotificationLevel::TRACKING, 
      threshold: SiteSetting.auto_track_topics_after
    }

    rows = exec_sql("UPDATE topic_users
                                  SET 
                                    last_read_post_number = greatest(:post_number, tu.last_read_post_number), 
                                    seen_post_count = t.highest_post_number, 
                                    total_msecs_viewed = tu.total_msecs_viewed + :msecs,
                                    notification_level = 
                                       case when tu.notifications_reason_id is null and (tu.total_msecs_viewed + :msecs) > 
                                          coalesce(u.auto_track_topics_after_msecs,:threshold) and 
                                          coalesce(u.auto_track_topics_after_msecs, :threshold) >= 0 then 
                                            :tracking 
                                       else 
                                          tu.notification_level
                                       end
                                FROM topic_users tu
                                join topics t on t.id = tu.topic_id
                                join users u on u.id = :user_id
                                WHERE
                                     tu.topic_id = topic_users.topic_id AND
                                     tu.user_id = topic_users.user_id AND
                                     tu.topic_id = :topic_id AND 
                                     tu.user_id = :user_id
                                RETURNING
                                  topic_users.notification_level, tu.notification_level old_level
                              ",
                              args).values
    
    if rows.length == 1 
      before = rows[0][1].to_i
      after = rows[0][0].to_i

      if before != after 
        MessageBus.publish("/topic/#{topic_id}", {notification_level_change: after}, user_ids: [user.id])
      end
    end

    if rows.length == 0
      
      self

      args[:tracking] = TopicUser::NotificationLevel::TRACKING
      args[:regular] = TopicUser::NotificationLevel::REGULAR
      args[:site_setting] = SiteSetting.auto_track_topics_after
      exec_sql("INSERT INTO topic_users (user_id, topic_id, last_read_post_number, seen_post_count, last_visited_at, first_visited_at, notification_level)
                SELECT :user_id, :topic_id, :post_number, ft.highest_post_number, :now, :now, 
                  case when coalesce(u.auto_track_topics_after_msecs, :site_setting) = 0 then :tracking else :regular end
                FROM topics AS ft
                JOIN users u on u.id = :user_id
                WHERE ft.id = :topic_id
                  AND NOT EXISTS(SELECT 1 
                                 FROM topic_users AS ftu 
                                 WHERE ftu.user_id = :user_id and ftu.topic_id = :topic_id)", 
                args)
    end
  end


end
