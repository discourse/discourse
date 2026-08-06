# frozen_string_literal: true

class CategoryActivityDailyRollup < ActiveRecord::Base
  belongs_to :category

  AGGREGATION_CHUNK_DAYS = 90
  AGGREGATE_LOCK_KEY = "category_activity_daily_rollup_aggregate"
  AGGREGATE_LOCK_VALIDITY = 15.minutes

  ELIGIBLE_TOPICS = <<~SQL
    topics.deleted_at IS NULL
    AND topics.archetype = 'regular'
    AND topics.category_id IS NOT NULL
  SQL

  def self.period_totals(
    prev_start:,
    current_start:,
    current_end:,
    category_ids: nil,
    secure_category_ids: nil
  )
    builder = DB.build(<<~SQL)
      SELECT
        c.id,
        c.name,
        c.color,
        c.slug,
        COALESCE(SUM(r.topics) FILTER (WHERE r.date >= :current_start), 0)::bigint AS topics_current,
        COALESCE(SUM(r.posts) FILTER (WHERE r.date >= :current_start), 0)::bigint AS posts_current,
        COALESCE(SUM(r.page_views) FILTER (WHERE r.date >= :current_start), 0)::bigint AS page_views_current,
        COALESCE(SUM(r.topics) FILTER (WHERE r.date < :current_start), 0)::bigint AS topics_prior,
        COALESCE(SUM(r.posts) FILTER (WHERE r.date < :current_start), 0)::bigint AS posts_prior,
        COALESCE(SUM(r.page_views) FILTER (WHERE r.date < :current_start), 0)::bigint AS page_views_prior
      FROM category_activity_daily_rollups r
      INNER JOIN categories c ON c.id = r.category_id
      /*where*/
      GROUP BY c.id, c.name, c.color, c.slug
      HAVING SUM(r.topics + r.posts + r.page_views) > 0
    SQL

    builder.where("r.date >= :prev_start AND r.date <= :current_end")
    builder.where("c.id IN (:category_ids)", category_ids: category_ids) if category_ids.present?
    builder.secure_category(secure_category_ids) unless secure_category_ids.nil?

    builder.query(prev_start: prev_start, current_start: current_start, current_end: current_end)
  end

  def self.earliest_activity_date
    Topic.where(ELIGIBLE_TOPICS).minimum(:created_at)&.to_date
  end

  def self.rebuild!
    start_date = [earliest_activity_date, minimum(:date)].compact.min
    return if start_date.nil?

    aggregate(start_date: start_date, end_date: Time.zone.today)
  end

  def self.aggregate(start_date:, end_date:)
    start_date = start_date.to_date
    end_date = end_date.to_date

    while start_date <= end_date
      chunk_end = [start_date + AGGREGATION_CHUNK_DAYS - 1, end_date].min

      DistributedMutex.synchronize(AGGREGATE_LOCK_KEY, validity: AGGREGATE_LOCK_VALIDITY) do
        rows = daily_counts(start_date, chunk_end)
        transaction { replace!(start_date: start_date, end_date: chunk_end, rows: rows) }
      end

      start_date = chunk_end + 1.day
    end

    nil
  end

  def self.daily_counts(start_date, end_date)
    DB.query(
      <<~SQL,
      WITH topic_counts AS (
        SELECT topics.created_at::date AS date, topics.category_id, COUNT(*) AS topics
        FROM topics
        WHERE topics.created_at >= :start_date
          AND topics.created_at < :end_date
          AND #{ELIGIBLE_TOPICS}
        GROUP BY 1, 2
      ), post_counts AS (
        SELECT posts.created_at::date AS date, topics.category_id, COUNT(*) AS posts
        FROM posts
        INNER JOIN topics ON topics.id = posts.topic_id
        WHERE posts.created_at >= :start_date
          AND posts.created_at < :end_date
          AND posts.deleted_at IS NULL
          AND posts.post_type = :regular_post_type
          AND #{ELIGIBLE_TOPICS}
        GROUP BY 1, 2
      ), view_counts AS (
        SELECT tvs.viewed_at AS date,
          topics.category_id,
          SUM(tvs.anonymous_views + tvs.logged_in_views) AS page_views
        FROM topic_view_stats tvs
        INNER JOIN topics ON topics.id = tvs.topic_id
        WHERE tvs.viewed_at >= :start_date
          AND tvs.viewed_at < :end_date
          AND #{ELIGIBLE_TOPICS}
        GROUP BY 1, 2
      )
      SELECT date,
        category_id,
        SUM(topics)::int AS topics,
        SUM(posts)::int AS posts,
        SUM(page_views)::bigint AS page_views
      FROM (
        SELECT date, category_id, topics, 0 AS posts, 0 AS page_views FROM topic_counts
        UNION ALL
        SELECT date, category_id, 0, posts, 0 FROM post_counts
        UNION ALL
        SELECT date, category_id, 0, 0, page_views FROM view_counts
      ) combined
      GROUP BY date, category_id
    SQL
      start_date: start_date,
      end_date: end_date + 1.day,
      regular_post_type: Post.types[:regular],
    )
  end
  private_class_method :daily_counts

  def self.replace!(start_date:, end_date:, rows:)
    where(date: start_date..end_date).delete_all
    return if rows.empty?

    insert_all!(
      rows.map do |row|
        {
          date: row.date,
          category_id: row.category_id,
          topics: row.topics,
          posts: row.posts,
          page_views: row.page_views,
        }
      end,
    )
  end
  private_class_method :replace!
end

# == Schema Information
#
# Table name: category_activity_daily_rollups
#
#  id          :bigint           not null, primary key
#  date        :date             not null
#  page_views  :bigint           default(0), not null
#  posts       :integer          default(0), not null
#  topics      :integer          default(0), not null
#  category_id :integer          not null
#
# Indexes
#
#  index_category_activity_daily_rollups_on_date_and_category_id  (date,category_id) UNIQUE
#
