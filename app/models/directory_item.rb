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

  def self.period_directory_data(period_type)
    query =
      with_prepare_refresh_period_cte do |cte|
        "SELECT * FROM #{cte} ORDER BY likes_received DESC, likes_given DESC, topic_count DESC, post_count DESC"
      end
    DB.query(query, period_query_args(period_type))
  end

  def self.refresh_period!(period_type, force: false)
    DiscourseEvent.trigger("before_directory_refresh")
    Discourse.redis.set("directory_#{period_types[period_type]}", Time.zone.now.to_i)

    # Don't calculate it if the user directory is disabled
    return unless SiteSetting.enable_user_directory? || force

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

      # Create user records for newer users who don't yet have a directory item
      add_missing_users(period_type)
      query_args = period_query_args(period_type)

      # Calculate new values and update records
      #
      # TODO
      # WARNING: post_count is a wrong name, it should be reply_count (excluding topic post)
      update_query = with_prepare_refresh_period_cte { |cte| <<~SQL }
          UPDATE directory_items di
          SET
            likes_received = #{cte}.likes_received,
            likes_given    = #{cte}.likes_given,
            topics_entered = #{cte}.topics_entered,
            days_visited   = #{cte}.days_visited,
            posts_read     = #{cte}.posts_read,
            topic_count    = #{cte}.topic_count,
            post_count     = #{cte}.post_count
          FROM #{cte}
        WHERE
          #{cte}.user_id = di.user_id AND
          di.period_type = :period_type AND (
            di.likes_received <> #{cte}.likes_received OR
            di.likes_given <> #{cte}.likes_given OR
            di.topics_entered <> #{cte}.topics_entered OR
            di.days_visited <> #{cte}.days_visited OR
            di.posts_read <> #{cte}.posts_read OR
            di.topic_count <> #{cte}.topic_count OR
            di.post_count <> #{cte}.post_count
          )
        SQL
      DB.exec(update_query, query_args)

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

  # Passes the name of the CTE to be used in the final query,
  # then the caller returns what the _bottom_ part of the query should be,
  # using the CTE name provided.
  def self.with_prepare_refresh_period_cte
    cte_name = "directory_cte"
    final_query = yield cte_name
    <<~SQL
      WITH eligible_users AS (
        SELECT id
        FROM users
        WHERE id > 0 AND active AND silenced_till IS NULL
      ),
      recent_user_actions AS (
        #{recent_user_actions_subquery}
      ),
      viewed_topics AS (
        SELECT user_id, COUNT(*) AS topics_entered
        FROM topic_views
        WHERE topic_views.viewed_at > :since
        GROUP BY topic_views.user_id
      ),
      visited_topics AS (
        SELECT user_visits.user_id, COUNT(*) AS days_visited, COALESCE(SUM(user_visits.posts_read),0) AS posts_read
        FROM user_visits
        WHERE user_visits.visited_at > :since
        GROUP BY user_visits.user_id
      ),
      #{cte_name} AS (
        SELECT
          h.id AS user_id,
          COALESCE(rua.likes_received, 0) AS likes_received,
          COALESCE(rua.likes_given,   0)  AS likes_given,
          COALESCE(tv.topics_entered,  0)  AS topics_entered,
          COALESCE(vi.days_visited,   0)  AS days_visited,
          COALESCE(vi.posts_read,     0)  AS posts_read,
          COALESCE(rua.topic_count,   0)  AS topic_count,
          COALESCE(rua.post_count,    0)  AS post_count
        FROM eligible_users h
        LEFT JOIN recent_user_actions rua ON rua.user_id = h.id
        LEFT JOIN viewed_topics    tv    ON tv.user_id   = h.id
        LEFT JOIN visited_topics   vi   ON vi.user_id  = h.id
      )
      #{final_query}
    SQL
  end

  def self.period_query_args(period_type)
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

    {
      period_type: period_types[period_type],
      since: since,
      like_type: UserAction::LIKE,
      was_liked_type: UserAction::WAS_LIKED,
      new_topic_type: UserAction::NEW_TOPIC,
      reply_type: UserAction::REPLY,
      regular_post_type: Post.types[:regular],
    }
  end

  def self.recent_user_actions_subquery
    <<~SQL
      WITH visible_topics AS (
        SELECT t.id
        FROM topics t
        WHERE t.deleted_at IS NULL
          AND t.visible
          AND t.archetype = 'regular'
      ),
      visible_posts AS (
        SELECT p.id
        FROM posts p
        JOIN visible_topics vt ON vt.id = p.topic_id
        WHERE p.deleted_at IS NULL
          AND p.post_type = :regular_post_type
          AND NOT p.hidden
      )
      SELECT
        ua.user_id,
        SUM(CASE WHEN ua.action_type = 2 AND vp.id IS NOT NULL THEN 1 ELSE 0 END) AS likes_received,
        SUM(CASE WHEN ua.action_type = 1 AND vp.id IS NOT NULL THEN 1 ELSE 0 END) AS likes_given,
        SUM(CASE WHEN ua.action_type = 5 AND vp.id IS NOT NULL THEN 1 ELSE 0 END) AS post_count,
        SUM(CASE WHEN ua.action_type = 4 AND vt.id IS NOT NULL THEN 1 ELSE 0 END) AS topic_count
      FROM user_actions ua
      LEFT JOIN visible_posts vp ON vp.id = ua.target_post_id
      LEFT JOIN visible_topics vt ON vt.id = ua.target_topic_id
      WHERE ua.created_at > :since
      GROUP BY ua.user_id
    SQL
  end

  def self.add_missing_users_all_periods
    period_types.each_key { |p| add_missing_users(p) }
  end

  def self.add_missing_users(period_type)
    column_names = DirectoryColumn.automatic_column_names + DirectoryColumn.plugin_directory_columns
    DB.exec(
      "INSERT INTO directory_items(period_type, user_id, #{column_names.map(&:to_s).join(", ")})
              SELECT :period_type, u.id, #{Array.new(column_names.count, 0).join(", ")}
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
