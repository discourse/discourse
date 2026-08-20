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
    page_views = human_page_views_expr

    builder = DB.build(<<~SQL)
      SELECT
        c.id,
        c.name,
        c.color,
        c.slug,
        COALESCE(SUM(r.topics) FILTER (WHERE r.date >= :current_start), 0)::bigint AS topics_current,
        COALESCE(SUM(r.posts) FILTER (WHERE r.date >= :current_start), 0)::bigint AS posts_current,
        COALESCE(SUM(#{page_views}) FILTER (WHERE r.date >= :current_start), 0)::bigint AS page_views_current,
        COALESCE(SUM(r.topics) FILTER (WHERE r.date < :current_start), 0)::bigint AS topics_prior,
        COALESCE(SUM(r.posts) FILTER (WHERE r.date < :current_start), 0)::bigint AS posts_prior,
        COALESCE(SUM(#{page_views}) FILTER (WHERE r.date < :current_start), 0)::bigint AS page_views_prior
      FROM category_activity_daily_rollups r
      INNER JOIN categories c ON c.id = r.category_id
      /*where*/
      GROUP BY c.id, c.name, c.color, c.slug
      HAVING SUM(r.topics + r.posts + #{page_views}) > 0
    SQL

    builder.where("r.date >= :prev_start AND r.date <= :current_end")
    builder.where("c.id IN (:category_ids)", category_ids: category_ids) if category_ids.present?
    builder.secure_category(secure_category_ids) unless secure_category_ids.nil?

    builder.query(prev_start: prev_start, current_start: current_start, current_end: current_end)
  end

  def self.human_page_views_expr
    return "r.page_views" if !CrawlerScorer.enabled?

    "GREATEST(r.page_views - r.likely_crawler_page_views, 0)"
  end
  private_class_method :human_page_views_expr

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
      ), crawler_view_counts AS (
        SELECT bpe.created_at::date AS date,
          topics.category_id,
          COUNT(DISTINCT (
            bpe.topic_id,
            COALESCE(bpe.user_id::text, 'ip-' || bpe.ip_address::text)
          )) AS likely_crawler_page_views
        FROM browser_pageview_events bpe
        INNER JOIN topics ON topics.id = bpe.topic_id
        WHERE bpe.created_at >= :start_date
          AND bpe.created_at < :end_date
          AND #{CrawlerScorer.likely_crawler_condition(table: "bpe")}
          AND #{BrowserPageviewEvent.rollup_source_condition(table: "bpe")}
          AND #{ELIGIBLE_TOPICS}
        GROUP BY 1, 2
      )
      SELECT combined.date,
        combined.category_id,
        SUM(combined.topics)::int AS topics,
        SUM(combined.posts)::int AS posts,
        SUM(combined.page_views)::bigint AS page_views,
        COALESCE(MAX(crawler_view_counts.likely_crawler_page_views), 0)::bigint
          AS likely_crawler_page_views
      FROM (
        SELECT date, category_id, topics, 0 AS posts, 0 AS page_views FROM topic_counts
        UNION ALL
        SELECT date, category_id, 0, posts, 0 FROM post_counts
        UNION ALL
        SELECT date, category_id, 0, 0, page_views FROM view_counts
      ) combined
      LEFT JOIN crawler_view_counts
        ON crawler_view_counts.date = combined.date
        AND crawler_view_counts.category_id = combined.category_id
      GROUP BY combined.date, combined.category_id
    SQL
      start_date: start_date,
      end_date: end_date + 1.day,
      regular_post_type: Post.types[:regular],
    )
  end
  private_class_method :daily_counts

  def self.replace!(start_date:, end_date:, rows:)
    if rows.empty?
      where(date: start_date..end_date).delete_all
      return
    end

    preserved = crawler_page_views_without_events(start_date, end_date)
    where(date: start_date..end_date).delete_all

    insert_all!(
      rows.map do |row|
        {
          date: row.date,
          category_id: row.category_id,
          topics: row.topics,
          posts: row.posts,
          page_views: row.page_views,
          likely_crawler_page_views:
            preserved.fetch([row.date, row.category_id], row.likely_crawler_page_views),
        }
      end,
    )
  end
  private_class_method :replace!

  def self.crawler_page_views_without_events(start_date, end_date)
    dates_with_events =
      DB.query_single(<<~SQL, start_date: start_date, end_date: end_date.to_date + 1)
        SELECT DISTINCT created_at::date
        FROM browser_pageview_events
        WHERE created_at >= :start_date
          AND created_at < :end_date
          AND #{BrowserPageviewEvent.rollup_source_condition}
      SQL

    scope = where(date: start_date..end_date).where("likely_crawler_page_views > 0")
    scope = scope.where.not(date: dates_with_events) if dates_with_events.present?

    scope
      .pluck(:date, :category_id, :likely_crawler_page_views)
      .to_h { |date, category_id, count| [[date, category_id], count] }
  end
  private_class_method :crawler_page_views_without_events
end

# == Schema Information
#
# Table name: category_activity_daily_rollups
#
#  id                        :bigint           not null, primary key
#  date                      :date             not null
#  likely_crawler_page_views :bigint           default(0), not null
#  page_views                :bigint           default(0), not null
#  posts                     :integer          default(0), not null
#  topics                    :integer          default(0), not null
#  category_id               :integer          not null
#
# Indexes
#
#  index_category_activity_daily_rollups_on_date_and_category_id  (date,category_id) UNIQUE
#
