class TopicUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic

  # Class methods
  class << self

    # Enums
    def notification_levels
      @notification_levels ||= Enum.new(:muted, :regular, :tracking, :watching, start: 0)
    end

    def notification_reasons
      @notification_reasons ||= Enum.new(:created_topic, :user_changed, :user_interacted, :created_post)
    end

    def auto_track(user_id, topic_id, reason)
      if TopicUser.where(user_id: user_id, topic_id: topic_id, notifications_reason_id: nil).exists?
        change(user_id, topic_id,
          notification_level: notification_levels[:tracking],
          notifications_reason_id: reason
        )

        MessageBus.publish("/topic/#{topic_id}", {
          notification_level_change: notification_levels[:tracking],
          notifications_reason_id: reason
        }, user_ids: [user_id])
      end
    end

    # Find the information specific to a user in a forum topic
    def lookup_for(user, topics)
      # If the user isn't logged in, there's no last read posts
      return {} if user.blank? || topics.blank?

      topic_ids = topics.map(&:id)
      create_lookup(TopicUser.where(topic_id: topic_ids, user_id: user.id))
    end

    def create_lookup(topic_users)
      topic_users = topic_users.to_a

      result = {}
      return result if topic_users.blank?

      topic_users.each do |ftu|
        result[ftu.topic_id] = ftu
      end
      result
    end

    def get(topic,user)
      topic = topic.id if Topic === topic
      user = user.id if User === user
      TopicUser.where('topic_id = ? and user_id = ?', topic, user).first
    end

    # Change attributes for a user (creates a record when none is present). First it tries an update
    # since there's more likely to be an existing record than not. If the update returns 0 rows affected
    # it then creates the row instead.
    def change(user_id, topic_id, attrs)
      # Sometimes people pass objs instead of the ids. We can handle that.
      topic_id = topic_id.id if topic_id.is_a?(Topic)
      user_id = user_id.id if user_id.is_a?(User)

      TopicUser.transaction do
        attrs = attrs.dup
        attrs[:starred_at] = DateTime.now if attrs[:starred_at].nil? && attrs[:starred]

        if attrs[:notification_level]
          attrs[:notifications_changed_at] ||= DateTime.now
          attrs[:notifications_reason_id] ||= TopicUser.notification_reasons[:user_changed]
        end
        attrs_array = attrs.to_a

        attrs_sql = attrs_array.map { |t| "#{t[0]} = ?" }.join(", ")
        vals = attrs_array.map { |t| t[1] }
        rows = TopicUser.update_all([attrs_sql, *vals], topic_id: topic_id.to_i, user_id: user_id)

        if rows == 0
          now = DateTime.now
          auto_track_after = User.select(:auto_track_topics_after_msecs).where(id: user_id).first.auto_track_topics_after_msecs
          auto_track_after ||= SiteSetting.auto_track_topics_after

          if auto_track_after >= 0 && auto_track_after <= (attrs[:total_msecs_viewed] || 0)
            attrs[:notification_level] ||= notification_levels[:tracking]
          end

          TopicUser.create(attrs.merge!(user_id: user_id, topic_id: topic_id.to_i, first_visited_at: now ,last_visited_at: now))
        end
      end
    rescue ActiveRecord::RecordNotUnique
      # In case of a race condition to insert, do nothing
    end

    def track_visit!(topic,user)
      now = DateTime.now
      rows = TopicUser.update_all({last_visited_at: now}, {topic_id: topic.id, user_id: user.id})
      if rows == 0
        TopicUser.create(topic_id: topic.id, user_id: user.id, last_visited_at: now, first_visited_at: now)
      end
    end

    # Update the last read and the last seen post count, but only if it doesn't exist.
    # This would be a lot easier if psql supported some kind of upsert
    def update_last_read(user, topic_id, post_number, msecs)
      return if post_number.blank?
      msecs = 0 if msecs.to_i < 0

      args = {
        user_id: user.id,
        topic_id: topic_id,
        post_number: post_number,
        now: DateTime.now,
        msecs: msecs,
        tracking: notification_levels[:tracking],
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
        args[:tracking] = notification_levels[:tracking]
        args[:regular] = notification_levels[:regular]
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

end
