# frozen_string_literal: true

class DirectoryItem < ActiveRecord::Base
  belongs_to :user
  has_one :user_stat, foreign_key: :user_id, primary_key: :user_id

  @@plugin_queries = []

  def self.period_types
    @types ||= Enum.new(all: 1, yearly: 2, monthly: 3, weekly: 4, daily: 5, quarterly: 6)
  end

  def self.refresh!
    period_types.each_key { |p| refresh_period!(p) }
  end

  def self.last_updated_at(period_type)
    val = Discourse.redis.get("directory_#{period_type}")
    return nil if val.nil?

    Time.zone.at(val.to_i)
  end

  def self.add_plugin_query(details)
    @@plugin_queries << details
  end

  def self.clear_plugin_queries
    @@plugin_queries = []
  end

  def self.refresh_period!(period_type, force: false)
    DiscourseEvent.trigger("before_directory_refresh")
    Discourse.redis.set("directory_#{period_types[period_type]}", Time.zone.now.to_i)

    # Don't calculate it if the user directory is disabled
    return unless SiteSetting.enable_user_directory? || force

    since =
      case period_type
      when :daily
        1.day.ago
      when :weekly
        1.week.ago
      when :monthly
        1.month.ago
      when :quarterly
        3.months.ago
      when :yearly
        1.year.ago
      else
        1000.years.ago
      end

    ActiveRecord::Base.transaction do
      # Delete records that belonged to users who have been deleted
      DB.exec(
        "DELETE FROM directory_items
                USING directory_items di
                LEFT JOIN users u ON (u.id = user_id AND u.active AND u.silenced_till IS NULL AND u.id > 0)
                WHERE di.id = directory_items.id AND
                      u.id IS NULL AND
                      di.period_type = :period_type",
        period_type: period_types[period_type],
      )

      add_missing_users(period_type)

      # Calculate new values and update records
      #
      #
      # TODO
      # WARNING: post_count is a wrong name, it should be reply_count (excluding topic post)
      #
      #
      query_args = {
        period_type: period_types[period_type],
        since: since,
        like_type: UserAction::LIKE,
        was_liked_type: UserAction::WAS_LIKED,
        new_topic_type: UserAction::NEW_TOPIC,
        reply_type: UserAction::REPLY,
        regular_post_type: Post.types[:regular],
      }

      DB.exec(
        "WITH x AS (SELECT
                    u.id user_id,
                    SUM(CASE WHEN p.id IS NOT NULL AND t.id IS NOT NULL AND ua.action_type = :was_liked_type THEN 1 ELSE 0 END) likes_received,
                    SUM(CASE WHEN p.id IS NOT NULL AND t.id IS NOT NULL AND ua.action_type = :like_type THEN 1 ELSE 0 END) likes_given,
                    COALESCE((SELECT COUNT(topic_id) FROM topic_views AS v WHERE v.user_id = u.id AND v.viewed_at > :since), 0) topics_entered,
                    COALESCE((SELECT COUNT(id) FROM user_visits AS uv WHERE uv.user_id = u.id AND uv.visited_at > :since), 0) days_visited,
                    COALESCE((SELECT SUM(posts_read) FROM user_visits AS uv2 WHERE uv2.user_id = u.id AND uv2.visited_at > :since), 0) posts_read,
                    SUM(CASE WHEN t2.id IS NOT NULL AND ua.action_type = :new_topic_type THEN 1 ELSE 0 END) topic_count,
                    SUM(CASE WHEN p.id IS NOT NULL AND t.id IS NOT NULL AND ua.action_type = :reply_type THEN 1 ELSE 0 END) post_count
                  FROM users AS u
                  LEFT OUTER JOIN user_actions AS ua ON ua.user_id = u.id AND COALESCE(ua.created_at, :since) > :since
                  LEFT OUTER JOIN posts AS p ON ua.target_post_id = p.id AND p.deleted_at IS NULL AND p.post_type = :regular_post_type AND NOT p.hidden
                  LEFT OUTER JOIN topics AS t ON p.topic_id = t.id AND t.archetype = 'regular' AND t.deleted_at IS NULL AND t.visible
                  LEFT OUTER JOIN topics AS t2 ON t2.id = ua.target_topic_id AND t2.archetype = 'regular' AND t2.deleted_at IS NULL AND t2.visible
                  LEFT OUTER JOIN categories AS c ON t.category_id = c.id
                  WHERE u.active
                    AND u.silenced_till IS NULL
                    AND u.id > 0
                  GROUP BY u.id)
      UPDATE directory_items di SET
               likes_received = x.likes_received,
               likes_given = x.likes_given,
               topics_entered = x.topics_entered,
               days_visited = x.days_visited,
               posts_read = x.posts_read,
               topic_count = x.topic_count,
               post_count = x.post_count
      FROM x
      WHERE
        x.user_id = di.user_id AND
        di.period_type = :period_type AND (
        di.likes_received <> x.likes_received OR
        di.likes_given <> x.likes_given OR
        di.topics_entered <> x.topics_entered OR
        di.days_visited <> x.days_visited OR
        di.posts_read <> x.posts_read OR
        di.topic_count <> x.topic_count OR
        di.post_count <> x.post_count )

              ",
        query_args,
      )

      @@plugin_queries.each { |plugin_query| DB.exec(plugin_query, query_args) }

      DB.exec <<~SQL if period_type == :all
          UPDATE user_stats s
          SET likes_given         = d.likes_given,
              likes_received      = d.likes_received,
              topic_count         = d.topic_count,
              post_count          = d.post_count

          FROM directory_items d
          WHERE s.user_id = d.user_id AND
                d.period_type = 1 AND
            ( s.likes_given         <> d.likes_given OR
              s.likes_received      <> d.likes_received OR
              s.topic_count         <> d.topic_count OR
              s.post_count          <> d.post_count
            )
        SQL
    end
  end

  def self.add_missing_users_all_periods
    period_types.each_key { |p| add_missing_users(p) }
  end

  def self.add_missing_users(period_type)
    column_names = DirectoryColumn.automatic_column_names + DirectoryColumn.plugin_directory_columns
    DB.exec(
      "INSERT INTO directory_items(period_type, user_id, #{column_names.map(&:to_s).join(", ")})
              SELECT
                  :period_type,
                  u.id,
                  #{Array.new(column_names.count, 0).join(", ")}
              FROM users u
              LEFT JOIN directory_items di ON di.user_id = u.id AND di.period_type = :period_type
              WHERE di.id IS NULL AND u.id > 0 AND u.silenced_till IS NULL AND u.active AND NOT EXISTS(
                SELECT 1
                FROM anonymous_users
                WHERE anonymous_users.user_id = u.id
              )
              #{SiteSetting.must_approve_users ? "AND u.approved" : ""}
            ",
      period_type: period_types[period_type],
    )
  end
end

# == Schema Information
#
# Table name: directory_items
#
#  id             :integer          not null, primary key
#  days_visited   :integer          default(0), not null
#  likes_given    :integer          not null
#  likes_received :integer          not null
#  period_type    :integer          not null
#  post_count     :integer          not null
#  posts_read     :integer          default(0), not null
#  topic_count    :integer          not null
#  topics_entered :integer          not null
#  created_at     :datetime
#  updated_at     :datetime
#  user_id        :integer          not null
#
# Indexes
#
#  index_directory_items_on_days_visited             (days_visited)
#  index_directory_items_on_likes_given              (likes_given)
#  index_directory_items_on_likes_received           (likes_received)
#  index_directory_items_on_period_type_and_user_id  (period_type,user_id) UNIQUE
#  index_directory_items_on_post_count               (post_count)
#  index_directory_items_on_posts_read               (posts_read)
#  index_directory_items_on_topic_count              (topic_count)
#  index_directory_items_on_topics_entered           (topics_entered)
#
