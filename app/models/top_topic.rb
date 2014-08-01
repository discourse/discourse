class TopTopic < ActiveRecord::Base

  belongs_to :topic

  def self.periods
    @periods ||= [:yearly, :monthly, :weekly, :daily]
  end

  def self.sort_orders
    @sort_orders ||= [:posts, :views, :likes]
  end

  # The top topics we want to refresh often
  def self.refresh_daily!
    transaction do
      remove_invisible_topics
      add_new_visible_topics

      TopTopic.sort_orders.each do |sort|
        TopTopic.send("update_#{sort}_count_for", :daily)
      end
      TopTopic.compute_top_score_for(:daily)
    end
  end

  # We don't have to refresh these as often
  def self.refresh_older!
    older = TopTopic.periods - [:daily]

    transaction do
      older.each do |period|
        TopTopic.sort_orders.each do |sort|
          TopTopic.send("update_#{sort}_count_for", :daily)
        end
        TopTopic.compute_top_score_for(:daily)
      end
    end
  end

  def self.refresh!
    TopTopic.refresh_daily!
    TopTopic.refresh_older!
  end

  def self.remove_invisible_topics
    exec_sql("WITH category_definition_topic_ids AS (
                SELECT COALESCE(topic_id, 0) AS id FROM categories
              ), invisible_topic_ids AS (
                SELECT id
                FROM topics
                WHERE deleted_at IS NOT NULL
                   OR NOT visible
                   OR archetype = :private_message
                   OR archived
                   OR id IN (SELECT id FROM category_definition_topic_ids)
              )
              DELETE FROM top_topics
              WHERE topic_id IN (SELECT id FROM invisible_topic_ids)",
              private_message: Archetype::private_message)
  end

  def self.add_new_visible_topics
    exec_sql("WITH category_definition_topic_ids AS (
                SELECT COALESCE(topic_id, 0) AS id FROM categories
              ), visible_topics AS (
              SELECT t.id
              FROM topics t
              LEFT JOIN top_topics tt ON t.id = tt.topic_id
              WHERE t.deleted_at IS NULL
                AND t.visible
                AND t.archetype <> :private_message
                AND NOT t.archived
                AND t.id NOT IN (SELECT id FROM category_definition_topic_ids)
                AND tt.topic_id IS NULL
            )
            INSERT INTO top_topics (topic_id)
            SELECT id FROM visible_topics",
            private_message: Archetype::private_message)
  end

  def self.update_posts_count_for(period)
    sql = "SELECT topic_id, GREATEST(COUNT(*), 1) AS count
           FROM posts
           WHERE created_at >= :from
             AND deleted_at IS NULL
             AND NOT hidden
             AND post_type = #{Post.types[:regular]}
             AND user_id <> #{Discourse.system_user.id}
           GROUP BY topic_id"

    TopTopic.update_top_topics(period, "posts", sql)
  end

  def self.update_views_count_for(period)
    sql = "SELECT parent_id as topic_id, COUNT(*) AS count
           FROM views
           WHERE viewed_at >= :from
           GROUP BY topic_id"

    TopTopic.update_top_topics(period, "views", sql)
  end

  def self.update_likes_count_for(period)
    sql = "SELECT topic_id, GREATEST(SUM(like_count), 1) AS count
           FROM posts
           WHERE created_at >= :from
             AND deleted_at IS NULL
             AND NOT hidden
             AND post_type = #{Post.types[:regular]}
           GROUP BY topic_id"

    TopTopic.update_top_topics(period, "likes", sql)
  end

  def self.compute_top_score_for(period)
    sql = <<-SQL
      WITH top AS (
        SELECT CASE
                 WHEN topics.created_at < :from THEN 0
                 ELSE log(greatest(#{period}_views_count, 1)) + #{period}_likes_count + #{period}_posts_count * 2
               END AS score,
               topic_id
        FROM top_topics
        LEFT JOIN topics ON topics.id = top_topics.topic_id
      )
      UPDATE top_topics
      SET #{period}_score = top.score
      FROM top
      WHERE top_topics.topic_id = top.topic_id
        AND #{period}_score <> top.score
    SQL

    exec_sql(sql, from: start_of(period))
  end

  def self.start_of(period)
    case period
      when :yearly  then 1.year.ago
      when :monthly then 1.month.ago
      when :weekly  then 1.week.ago
      when :daily   then 1.day.ago
    end
  end

  def self.update_top_topics(period, sort, inner_join)
    exec_sql("UPDATE top_topics
              SET #{period}_#{sort}_count = c.count
              FROM top_topics tt
              INNER JOIN (#{inner_join}) c ON tt.topic_id = c.topic_id
              WHERE tt.topic_id = top_topics.topic_id
                AND tt.#{period}_#{sort}_count <> c.count",
              from: start_of(period))
  end

end

# == Schema Information
#
# Table name: top_topics
#
#  id                  :integer          not null, primary key
#  topic_id            :integer
#  yearly_posts_count  :integer          default(0), not null
#  yearly_views_count  :integer          default(0), not null
#  yearly_likes_count  :integer          default(0), not null
#  monthly_posts_count :integer          default(0), not null
#  monthly_views_count :integer          default(0), not null
#  monthly_likes_count :integer          default(0), not null
#  weekly_posts_count  :integer          default(0), not null
#  weekly_views_count  :integer          default(0), not null
#  weekly_likes_count  :integer          default(0), not null
#  daily_posts_count   :integer          default(0), not null
#  daily_views_count   :integer          default(0), not null
#  daily_likes_count   :integer          default(0), not null
#  yearly_score        :float            default(0.0)
#  monthly_score       :float            default(0.0)
#  weekly_score        :float            default(0.0)
#  daily_score         :float            default(0.0)
#
# Indexes
#
#  index_top_topics_on_daily_likes_count    (daily_likes_count)
#  index_top_topics_on_daily_posts_count    (daily_posts_count)
#  index_top_topics_on_daily_views_count    (daily_views_count)
#  index_top_topics_on_monthly_likes_count  (monthly_likes_count)
#  index_top_topics_on_monthly_posts_count  (monthly_posts_count)
#  index_top_topics_on_monthly_views_count  (monthly_views_count)
#  index_top_topics_on_topic_id             (topic_id) UNIQUE
#  index_top_topics_on_weekly_likes_count   (weekly_likes_count)
#  index_top_topics_on_weekly_posts_count   (weekly_posts_count)
#  index_top_topics_on_weekly_views_count   (weekly_views_count)
#  index_top_topics_on_yearly_likes_count   (yearly_likes_count)
#  index_top_topics_on_yearly_posts_count   (yearly_posts_count)
#  index_top_topics_on_yearly_views_count   (yearly_views_count)
#
