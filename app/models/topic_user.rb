class TopicUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic

  scope :starred_since, lambda { |sinceDaysAgo| where('starred_at > ?', sinceDaysAgo.days.ago) }
  scope :by_date_starred, -> { group('date(starred_at)').order('date(starred_at)') }

  scope :tracking, lambda { |topic_id|
    where(topic_id: topic_id)
        .where("COALESCE(topic_users.notification_level, :regular) >= :tracking",
                regular: TopicUser.notification_levels[:regular], tracking: TopicUser.notification_levels[:tracking])
  }

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
      topic_id = topic_id.id if topic_id.is_a?(::Topic)
      user_id = user_id.id if user_id.is_a?(::User)

      topic_id = topic_id.to_i
      user_id = user_id.to_i

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
        rows = TopicUser.where(topic_id: topic_id, user_id: user_id).update_all([attrs_sql, *vals])

        if rows == 0
          now = DateTime.now
          auto_track_after = User.select(:auto_track_topics_after_msecs).where(id: user_id).first.auto_track_topics_after_msecs
          auto_track_after ||= SiteSetting.auto_track_topics_after

          if auto_track_after >= 0 && auto_track_after <= (attrs[:total_msecs_viewed] || 0)
            attrs[:notification_level] ||= notification_levels[:tracking]
          end

          TopicUser.create(attrs.merge!(user_id: user_id, topic_id: topic_id, first_visited_at: now ,last_visited_at: now))
        else
          observe_after_save_callbacks_for topic_id, user_id
        end
      end
    rescue ActiveRecord::RecordNotUnique
      # In case of a race condition to insert, do nothing
    end

    def track_visit!(topic,user)
      topic_id = Topic === topic ? topic.id : topic
      user_id = User === user ? user.id : topic

      now = DateTime.now
      rows = TopicUser.where({topic_id: topic_id, user_id: user_id}).update_all({last_visited_at: now})
      if rows == 0
        TopicUser.create(topic_id: topic_id, user_id: user_id, last_visited_at: now, first_visited_at: now)
      else
        observe_after_save_callbacks_for topic_id, user_id
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

      # In case anyone seens "seen_post_count" and gets confused, like I do.
      # seen_post_count represents the highest_post_number of the topic when
      # the user visited it. It may be out of alignement with last_read, meaning
      # ... user visited the topic but did not read the posts
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
                                    topic_users.notification_level, tu.notification_level old_level, tu.last_read_post_number
                                ",
                                args).values

      if rows.length == 1
        before = rows[0][1].to_i
        after = rows[0][0].to_i

        before_last_read = rows[0][2].to_i

        if before_last_read < post_number
          TopicTrackingState.publish_read(topic_id, post_number, user.id)
        end

        if before != after
          MessageBus.publish("/topic/#{topic_id}", {notification_level_change: after}, user_ids: [user.id])
        end
      end

      if rows.length == 0
        TopicTrackingState.publish_read(topic_id, post_number, user.id)

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

    def observe_after_save_callbacks_for(topic_id, user_id)
      TopicUser.where(topic_id: topic_id, user_id: user_id).each do |topic_user|
        UserActionObserver.instance.after_save topic_user
      end
    end
  end

  def self.ensure_consistency!(topic_id=nil)
    builder = SqlBuilder.new <<SQL
UPDATE topic_users t
  SET
    last_read_post_number = last_read,
    seen_post_count = LEAST(max_post_number,GREATEST(t.seen_post_count, last_read))
FROM (
  SELECT topic_id, user_id, MAX(post_number) last_read
  FROM post_timings
  GROUP BY topic_id, user_id
) as X
JOIN (
  SELECT p.topic_id, MAX(p.post_number) max_post_number from posts p
  GROUP BY p.topic_id
) as Y on Y.topic_id = X.topic_id
/*where*/
SQL

    builder.where <<SQL
X.topic_id = t.topic_id AND
X.user_id = t.user_id AND
(
  last_read_post_number <> last_read OR
  seen_post_count <> LEAST(max_post_number,GREATEST(t.seen_post_count, last_read))
)
SQL

    if topic_id
      builder.where("t.topic_id = :topic_id", topic_id: topic_id)
    end

    builder.exec
  end

end

# == Schema Information
#
# Table name: topic_users
#
#  user_id                  :integer          not null
#  topic_id                 :integer          not null
#  starred                  :boolean          default(FALSE), not null
#  posted                   :boolean          default(FALSE), not null
#  last_read_post_number    :integer
#  seen_post_count          :integer
#  starred_at               :datetime
#  last_visited_at          :datetime
#  first_visited_at         :datetime
#  notification_level       :integer          default(1), not null
#  notifications_changed_at :datetime
#  notifications_reason_id  :integer
#  total_msecs_viewed       :integer          default(0), not null
#  cleared_pinned_at        :datetime
#  unstarred_at             :datetime
#  id                       :integer          not null, primary key
#
# Indexes
#
#  index_forum_thread_users_on_forum_thread_id_and_user_id  (topic_id,user_id) UNIQUE
#

