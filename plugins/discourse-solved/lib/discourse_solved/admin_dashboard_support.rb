# frozen_string_literal: true

module DiscourseSolved
  # Builds the data for the "Support" section of the redesigned admin dashboard
  # (registered via `register_admin_dashboard_section`). All metrics are scoped
  # to "support categories" — categories where accepted answers are enabled — for
  # the selected period, optionally narrowed to a single category.
  class AdminDashboardSupport
    DEFAULT_RANGE_DAYS = 30
    AVAILABILITY_CACHE_KEY = "solved_admin_dashboard_support_available"

    # Response-time buckets, in seconds. Open-ended final bucket uses nil.
    RESPONSE_TIME_BUCKETS = [
      { key: "lt_1h", max: 1.hour.to_i },
      { key: "1_4h", max: 4.hours.to_i },
      { key: "4_24h", max: 24.hours.to_i },
      { key: "gt_24h", max: nil },
    ].freeze

    def self.available?
      return false if !SiteSetting.solved_enabled
      return true if SiteSetting.allow_solved_on_all_topics

      Discourse
        .cache
        .fetch(AVAILABILITY_CACHE_KEY, expires_in: 5.minutes) do
          DiscourseSolved::Categories::Types::Support.find_matches.exists?
        end
    end

    def self.build(start_date:, end_date:, current_user: nil, category_id: nil)
      new(
        start_date: start_date,
        end_date: end_date,
        current_user: current_user,
        category_id: category_id,
      ).build
    end

    def initialize(start_date:, end_date:, current_user: nil, category_id: nil)
      @start_date = parse_date(start_date) || DEFAULT_RANGE_DAYS.days.ago.beginning_of_day
      @end_date = parse_date(end_date)&.end_of_day || Time.zone.now.end_of_day
      @current_user = current_user
      @category_id = category_id.presence&.to_i
    end

    def build
      {
        category_options: category_options,
        kpis: build_kpis,
        headline: build_headline,
        topic_outcomes: topic_outcomes,
        whos_answering: whos_answering,
        response_time_distribution: response_time_distribution,
      }
    end

    private

    attr_reader :start_date, :end_date, :current_user, :category_id

    def parse_date(value)
      return nil if value.blank?
      Time.zone.parse(value.to_s)&.beginning_of_day
    rescue ArgumentError, TypeError
      nil
    end

    # Length-matched window immediately preceding the selected period.
    def prev_start_date
      start_date - (end_date - start_date)
    end

    def prev_end_date
      start_date
    end

    def guardian
      @guardian ||= current_user&.guardian || Guardian.new
    end

    def support_categories
      scope =
        if SiteSetting.allow_solved_on_all_topics
          Category.all
        else
          DiscourseSolved::Categories::Types::Support.find_matches
        end
      scope.secured(guardian)
    end

    def all_support_category_ids
      @all_support_category_ids ||= support_categories.pluck(:id)
    end

    def selected_category_id
      category_id if category_id && all_support_category_ids.include?(category_id)
    end

    def effective_category_ids
      selected_category_id ? [selected_category_id] : all_support_category_ids
    end

    def category_options
      support_categories.order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } }
    end

    def build_kpis
      current = outcomes_for(start_date, end_date)
      previous = outcomes_for(prev_start_date, prev_end_date)

      {
        resolution_rate: {
          value: resolution_rate(current),
          previous_value: resolution_rate(previous),
          report_type: "accepted_solutions",
          report_query: resolution_report_query,
        },
        staff_involvement: {
          value: staff_involvement(start_date, end_date),
          previous_value: staff_involvement(prev_start_date, prev_end_date),
        },
        avg_first_reply: {
          value: avg_first_reply_seconds(start_date, end_date),
          previous_value: avg_first_reply_seconds(prev_start_date, prev_end_date),
        },
      }
    end

    def resolution_report_query
      query = { start_date: start_date.to_date.iso8601, end_date: end_date.to_date.iso8601 }
      query[:filters] = { category: selected_category_id } if selected_category_id
      query
    end

    def build_headline
      outcomes = topic_outcomes
      total = outcomes.values.sum
      rate = resolution_rate(outcomes)

      key =
        if total.zero?
          "no_data"
        elsif rate >= 60
          "healthy"
        elsif rate < 40
          "struggling"
        else
          "mixed"
        end

      { key: key, resolution_rate: rate.round, unanswered_count: outcomes[:unanswered] }
    end

    # Mutually-exclusive status counts for topics created in the window:
    # resolved (has an accepted answer), else in_progress (has at least one
    # reply), else unanswered.
    def topic_outcomes
      outcomes_for(start_date, end_date)
    end

    def outcomes_for(from, to)
      (@outcomes_cache ||= {})[[from, to]] ||= compute_outcomes(from, to)
    end

    def compute_outcomes(from, to)
      return { resolved: 0, in_progress: 0, unanswered: 0 } if effective_category_ids.empty?

      row = DB.query(<<~SQL, params_for(from, to)).first
          SELECT
            COUNT(*) FILTER (WHERE solved) AS resolved,
            COUNT(*) FILTER (WHERE NOT solved AND has_reply) AS in_progress,
            COUNT(*) FILTER (WHERE NOT solved AND NOT has_reply) AS unanswered
          FROM (
            SELECT
              (st.topic_id IS NOT NULL) AS solved,
              EXISTS (
                SELECT 1
                FROM posts p
                WHERE p.topic_id = t.id
                  AND p.post_number > 1
                  AND p.post_type = :post_type
                  AND p.deleted_at IS NULL
              ) AS has_reply
            FROM topics t
            LEFT JOIN discourse_solved_solved_topics st ON st.topic_id = t.id
            WHERE t.category_id IN (:category_ids)
              AND t.archetype = :archetype
              AND t.deleted_at IS NULL
              AND t.created_at >= :from
              AND t.created_at <= :to
          ) topics_with_state
        SQL

      {
        resolved: row.resolved.to_i,
        in_progress: row.in_progress.to_i,
        unanswered: row.unanswered.to_i,
      }
    end

    def resolution_rate(outcomes)
      total = outcomes.values.sum
      return 0.0 if total.zero?
      (outcomes[:resolved].to_f / total * 100).round(1)
    end

    # Percentage of topics in the window whose first reply was authored by staff.
    def staff_involvement(from, to)
      return 0.0 if effective_category_ids.empty?

      total = outcomes_for(from, to).values.sum
      return 0.0 if total.zero?

      staff_first = DB.query_single(<<~SQL, params_for(from, to)).first.to_i
          SELECT COUNT(*)
          FROM (
            SELECT DISTINCT ON (p.topic_id) p.user_id
            FROM posts p
            JOIN topics t ON t.id = p.topic_id
            WHERE t.category_id IN (:category_ids)
              AND t.archetype = :archetype
              AND t.deleted_at IS NULL
              AND t.created_at >= :from
              AND t.created_at <= :to
              AND p.post_number > 1
              AND p.post_type = :post_type
              AND p.deleted_at IS NULL
              AND p.user_id <> t.user_id
            ORDER BY p.topic_id, p.created_at ASC
          ) first_replies
          JOIN users u ON u.id = first_replies.user_id
          WHERE u.admin OR u.moderator
        SQL

      (staff_first.to_f / total * 100).round(1)
    end

    def first_reply_seconds(from, to)
      (@first_reply_cache ||= {})[[from, to]] ||= compute_first_reply_seconds(from, to)
    end

    def compute_first_reply_seconds(from, to)
      return [] if effective_category_ids.empty?

      DB.query_single(<<~SQL, params_for(from, to))
        SELECT EXTRACT(EPOCH FROM MIN(p.created_at) - t.created_at)::int AS seconds
        FROM topics t
        JOIN posts p ON p.topic_id = t.id
        WHERE t.category_id IN (:category_ids)
          AND t.archetype = :archetype
          AND t.deleted_at IS NULL
          AND t.created_at >= :from
          AND t.created_at <= :to
          AND p.post_number > 1
          AND p.post_type = :post_type
          AND p.deleted_at IS NULL
          AND p.user_id <> t.user_id
        GROUP BY t.id
        HAVING EXTRACT(EPOCH FROM MIN(p.created_at) - t.created_at) > 0
      SQL
    end

    def avg_first_reply_seconds(from, to)
      seconds = first_reply_seconds(from, to)
      return nil if seconds.empty?
      (seconds.sum.to_f / seconds.size).round
    end

    def response_time_distribution
      seconds = first_reply_seconds(start_date, end_date)
      total = seconds.size

      buckets =
        RESPONSE_TIME_BUCKETS.map do |bucket|
          min = previous_bucket_max(bucket)
          count = seconds.count { |s| s >= min && (bucket[:max].nil? || s < bucket[:max]) }
          {
            key: bucket[:key],
            count: count,
            share: total.zero? ? 0.0 : (count.to_f / total * 100).round,
          }
        end

      avg_now = avg_first_reply_seconds(start_date, end_date)
      avg_prev = avg_first_reply_seconds(prev_start_date, prev_end_date)

      trend =
        if avg_now && avg_prev
          { direction: time_direction(avg_now, avg_prev), seconds: (avg_now - avg_prev).abs }
        else
          { direction: "flat", seconds: 0 }
        end

      { buckets: buckets, trend: trend }
    end

    def previous_bucket_max(bucket)
      index = RESPONSE_TIME_BUCKETS.index(bucket)
      index.zero? ? 0 : RESPONSE_TIME_BUCKETS[index - 1][:max]
    end

    # Share of replies in the window by author group (staff, then trust level).
    def whos_answering
      return { rows: [], total: 0 } if effective_category_ids.empty?

      rows = DB.query(<<~SQL, params_for(start_date, end_date))
          SELECT
            CASE
              WHEN u.admin OR u.moderator THEN 'staff'
              WHEN u.trust_level >= 4 THEN 'leader'
              WHEN u.trust_level = 3 THEN 'regular'
              WHEN u.trust_level = 2 THEN 'member'
              ELSE 'basic'
            END AS bucket,
            COUNT(*) AS count
          FROM posts p
          JOIN topics t ON t.id = p.topic_id
          JOIN users u ON u.id = p.user_id
          WHERE t.category_id IN (:category_ids)
            AND t.archetype = :archetype
            AND t.deleted_at IS NULL
            AND p.created_at >= :from
            AND p.created_at <= :to
            AND p.post_number > 1
            AND p.post_type = :post_type
            AND p.deleted_at IS NULL
            AND p.user_id <> t.user_id
            AND u.id > 0
          GROUP BY bucket
        SQL

      total = rows.sum(&:count)
      {
        rows:
          rows.map do |row|
            {
              type: row.bucket,
              count: row.count,
              share: total.zero? ? 0.0 : (row.count.to_f / total * 100).round,
            }
          end,
        total: total,
      }
    end

    def params_for(from, to)
      {
        category_ids: effective_category_ids,
        archetype: Archetype.default,
        post_type: Post.types[:regular],
        from: from,
        to: to,
      }
    end

    # For durations, lower is better, so "faster"/"slower" rather than up/down.
    def time_direction(current, previous)
      return "flat" if current.nil? || previous.nil? || current == previous
      current < previous ? "faster" : "slower"
    end
  end
end
