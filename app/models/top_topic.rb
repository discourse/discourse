# frozen_string_literal: true

class TopTopic < ActiveRecord::Base
  belongs_to :topic

  # The top topics we want to refresh often
  def self.refresh_daily!
    DistributedMutex.synchronize("update_top_topics", validity: 5.minutes) do
      transaction do
        remove_invisible_topics
        add_new_visible_topics

        update_counts_and_compute_scores_for(:daily)
      end
    end
  end

  # We don't have to refresh these as often
  def self.refresh_older!
    DistributedMutex.synchronize("update_top_topics", validity: 5.minutes) do
      older_periods = periods - %i[daily all]

      transaction { older_periods.each { |period| update_counts_and_compute_scores_for(period) } }

      compute_top_score_for(:all)
    end
  end

  def self.refresh!
    refresh_daily!
    refresh_older!
  end

  def self.periods
    @@periods ||= %i[all yearly quarterly monthly weekly daily].freeze
  end

  def self.sorted_periods
    ascending_periods ||= Enum.new(daily: 1, weekly: 2, monthly: 3, quarterly: 4, yearly: 5, all: 6)
  end

  def self.score_column_for_period(period)
    TopTopic.validate_period(period)
    "#{period}_score"
  end

  def self.validate_period(period)
    @invalid_period_error ||=
      Discourse::InvalidParameters.new("Invalid period. Valid periods are #{periods.join(", ")}")

    raise @invalid_period_error if period.blank? || !periods.include?(period.to_sym)
  rescue NoMethodError
    raise @invalid_period_error
  end

  private

  def self.sort_orders
    @@sort_orders ||= %i[posts views likes op_likes].freeze
  end

  def self.update_counts_and_compute_scores_for(period)
    sort_orders.each { |sort| TopTopic.public_send("update_#{sort}_count_for", period) }
    compute_top_score_for(period)
  end

  def self.remove_invisible_topics
    DB.exec(
      "WITH category_definition_topic_ids AS (
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
      private_message: Archetype.private_message,
    )
  end

  def self.add_new_visible_topics
    DB.exec(
      "WITH category_definition_topic_ids AS (
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
      private_message: Archetype.private_message,
    )
  end

  def self.update_posts_count_for(period)
    sql =
      "SELECT topic_id, GREATEST(COUNT(*), 1) AS count
             FROM posts
             WHERE created_at >= :from
               AND deleted_at IS NULL
               AND NOT hidden
               AND post_type = #{Post.types[:regular]}
               AND user_id <> #{Discourse.system_user.id}
             GROUP BY topic_id"

    update_top_topics(period, "posts", sql)
  end

  def self.update_views_count_for(period)
    sql =
      "SELECT topic_id, COUNT(*) AS count
             FROM topic_views
             WHERE viewed_at >= :from
             GROUP BY topic_id"

    update_top_topics(period, "views", sql)
  end

  def self.update_likes_count_for(period)
    sql =
      "SELECT topic_id, SUM(like_count) AS count
             FROM posts
             WHERE created_at >= :from
               AND deleted_at IS NULL
               AND NOT hidden
               AND post_type = #{Post.types[:regular]}
             GROUP BY topic_id"

    update_top_topics(period, "likes", sql)
  end

  def self.update_op_likes_count_for(period)
    sql =
      "SELECT topic_id, like_count AS count
             FROM posts
             WHERE created_at >= :from
               AND post_number = 1
               AND deleted_at IS NULL
               AND NOT hidden
               AND post_type = #{Post.types[:regular]}"

    update_top_topics(period, "op_likes", sql)
  end

  def self.compute_top_score_for(period)
    log_views_multiplier = SiteSetting.top_topics_formula_log_views_multiplier.to_f
    log_views_multiplier = 2 if log_views_multiplier == 0

    first_post_likes_multiplier = SiteSetting.top_topics_formula_first_post_likes_multiplier.to_f
    first_post_likes_multiplier = 0.5 if first_post_likes_multiplier == 0

    least_likes_per_post_multiplier =
      SiteSetting.top_topics_formula_least_likes_per_post_multiplier.to_f
    least_likes_per_post_multiplier = 3 if least_likes_per_post_multiplier == 0

    if period == :all
      top_topics =
        "(
        SELECT t.like_count all_likes_count,
               t.id topic_id,
               t.posts_count all_posts_count,
               p.like_count all_op_likes_count,
               t.views all_views_count
        FROM topics t
        JOIN posts p ON p.topic_id = t.id AND p.post_number = 1
      ) as top_topics"
      time_filter = "false"
    else
      top_topics = "top_topics"
      time_filter = "topics.created_at < :from"
    end

    sql = <<~SQL
        WITH top AS (
          SELECT CASE
                   WHEN #{time_filter} THEN 0
                   ELSE log(GREATEST(#{period}_views_count, 1)) * #{log_views_multiplier} +
                        #{period}_op_likes_count * #{first_post_likes_multiplier} +
                        CASE WHEN #{period}_likes_count > 0 AND #{period}_posts_count > 0
                           THEN
                            LEAST(#{period}_likes_count / #{period}_posts_count, #{least_likes_per_post_multiplier})
                           ELSE 0
                        END +
                        CASE WHEN topics.posts_count < 10 THEN
                           0 - ((10 - topics.posts_count) / 20) * #{period}_op_likes_count
                        ELSE
                           10
                        END +
                        log(GREATEST(#{period}_posts_count, 1))
                 END AS score,
                 topic_id
          FROM #{top_topics}
          LEFT JOIN topics ON topics.id = top_topics.topic_id AND
                              topics.deleted_at IS NULL
        )
        UPDATE top_topics
        SET #{period}_score = top.score
        FROM top
        WHERE top_topics.topic_id = top.topic_id
          AND #{period}_score <> top.score
    SQL

    DB.exec(sql, from: start_of(period))

    DiscourseEvent.trigger(:top_score_computed, period: period)
  end

  def self.start_of(period)
    case period
    when :yearly
      1.year.ago
    when :monthly
      1.month.ago
    when :quarterly
      3.months.ago
    when :weekly
      1.week.ago
    when :daily
      1.day.ago
    end
  end

  def self.update_top_topics(period, sort, inner_join)
    DB.exec(
      "UPDATE top_topics
                SET #{period}_#{sort}_count = c.count
                FROM top_topics tt
                INNER JOIN (#{inner_join}) c ON tt.topic_id = c.topic_id
                WHERE tt.topic_id = top_topics.topic_id
                  AND tt.#{period}_#{sort}_count <> c.count",
      from: start_of(period),
    )
  end
end

# == Schema Information
#
# Table name: top_topics
#
#  id                       :integer          not null, primary key
#  topic_id                 :integer
#  yearly_posts_count       :integer          default(0), not null
#  yearly_views_count       :integer          default(0), not null
#  yearly_likes_count       :integer          default(0), not null
#  monthly_posts_count      :integer          default(0), not null
#  monthly_views_count      :integer          default(0), not null
#  monthly_likes_count      :integer          default(0), not null
#  weekly_posts_count       :integer          default(0), not null
#  weekly_views_count       :integer          default(0), not null
#  weekly_likes_count       :integer          default(0), not null
#  daily_posts_count        :integer          default(0), not null
#  daily_views_count        :integer          default(0), not null
#  daily_likes_count        :integer          default(0), not null
#  daily_score              :float            default(0.0)
#  weekly_score             :float            default(0.0)
#  monthly_score            :float            default(0.0)
#  yearly_score             :float            default(0.0)
#  all_score                :float            default(0.0)
#  daily_op_likes_count     :integer          default(0), not null
#  weekly_op_likes_count    :integer          default(0), not null
#  monthly_op_likes_count   :integer          default(0), not null
#  yearly_op_likes_count    :integer          default(0), not null
#  quarterly_posts_count    :integer          default(0), not null
#  quarterly_views_count    :integer          default(0), not null
#  quarterly_likes_count    :integer          default(0), not null
#  quarterly_score          :float            default(0.0)
#  quarterly_op_likes_count :integer          default(0), not null
#
# Indexes
#
#  index_top_topics_on_all_score                 (all_score)
#  index_top_topics_on_daily_likes_count         (daily_likes_count)
#  index_top_topics_on_daily_op_likes_count      (daily_op_likes_count)
#  index_top_topics_on_daily_posts_count         (daily_posts_count)
#  index_top_topics_on_daily_score               (daily_score)
#  index_top_topics_on_daily_views_count         (daily_views_count)
#  index_top_topics_on_monthly_likes_count       (monthly_likes_count)
#  index_top_topics_on_monthly_op_likes_count    (monthly_op_likes_count)
#  index_top_topics_on_monthly_posts_count       (monthly_posts_count)
#  index_top_topics_on_monthly_score             (monthly_score)
#  index_top_topics_on_monthly_views_count       (monthly_views_count)
#  index_top_topics_on_quarterly_likes_count     (quarterly_likes_count)
#  index_top_topics_on_quarterly_op_likes_count  (quarterly_op_likes_count)
#  index_top_topics_on_quarterly_posts_count     (quarterly_posts_count)
#  index_top_topics_on_quarterly_views_count     (quarterly_views_count)
#  index_top_topics_on_topic_id                  (topic_id) UNIQUE
#  index_top_topics_on_weekly_likes_count        (weekly_likes_count)
#  index_top_topics_on_weekly_op_likes_count     (weekly_op_likes_count)
#  index_top_topics_on_weekly_posts_count        (weekly_posts_count)
#  index_top_topics_on_weekly_score              (weekly_score)
#  index_top_topics_on_weekly_views_count        (weekly_views_count)
#  index_top_topics_on_yearly_likes_count        (yearly_likes_count)
#  index_top_topics_on_yearly_op_likes_count     (yearly_op_likes_count)
#  index_top_topics_on_yearly_posts_count        (yearly_posts_count)
#  index_top_topics_on_yearly_score              (yearly_score)
#  index_top_topics_on_yearly_views_count        (yearly_views_count)
#
