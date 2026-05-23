# frozen_string_literal: true

module Reports::ActivityByCategory
  extend ActiveSupport::Concern

  DEFAULT_TOP_N = 6
  MAX_CATEGORY_IDS = 50

  class_methods do
    def report_activity_by_category(report)
      report.modes = [Report::MODES[:table]]
      report.labels = [
        { property: :name, title: I18n.t("reports.activity_by_category.labels.category") },
        {
          property: :topics,
          type: :number,
          title: I18n.t("reports.activity_by_category.labels.topics"),
        },
        {
          property: :posts,
          type: :number,
          title: I18n.t("reports.activity_by_category.labels.posts"),
        },
        {
          property: :page_views,
          type: :number,
          title: I18n.t("reports.activity_by_category.labels.page_views"),
        },
        { property: :share_formatted, title: I18n.t("reports.activity_by_category.labels.share") },
        {
          property: :share_change_formatted,
          title: I18n.t("reports.activity_by_category.labels.vs_prior"),
        },
      ]

      raw_ids = report.filters[:category_ids]
      filter_requested = raw_ids.present?
      requested_ids =
        if filter_requested
          Array(raw_ids.is_a?(String) ? raw_ids.split(",") : raw_ids)
            .map(&:to_i)
            .reject(&:zero?)
            .uniq
            .first(MAX_CATEGORY_IDS)
        else
          nil
        end
      report.add_filter("category_ids", type: "category_list", default: requested_ids)

      if filter_requested && (requested_ids.nil? || requested_ids.empty?)
        report.total = 0
        report.data = []
        return
      end

      secure_category_ids =
        report.current_user&.admin? ? nil : Guardian.new(report.current_user).secure_category_ids

      current_period =
        period_data(report.start_date, report.end_date, requested_ids, secure_category_ids)

      prior_start = report.start_date - (report.end_date - report.start_date)
      prior_period = period_data(prior_start, report.start_date, requested_ids, secure_category_ids)

      total_current =
        current_period.values.sum { |row| row[:topics] + row[:posts] + row[:page_views] }
      total_prior = prior_period.values.sum { |row| row[:topics] + row[:posts] + row[:page_views] }

      rows =
        current_period.map do |category_id, current|
          activity = current[:topics] + current[:posts] + current[:page_views]
          share = total_current.zero? ? 0.0 : (activity.to_f / total_current * 100).round(2)

          prior = prior_period[category_id]
          prior_activity = prior ? prior[:topics] + prior[:posts] + prior[:page_views] : 0
          prior_share = total_prior.zero? ? 0.0 : (prior_activity.to_f / total_prior * 100).round(2)
          share_change = (share - prior_share).round(2)

          {
            category_id: category_id,
            name: current[:name],
            color: current[:color],
            slug: current[:slug],
            topics: current[:topics],
            posts: current[:posts],
            page_views: current[:page_views],
            share: share,
            share_change: share_change,
            share_formatted: "#{share}%",
            share_change_formatted: format_share_change(share_change),
          }
        end

      rows = rows.sort_by { |r| -(r[:topics] + r[:posts] + r[:page_views]) }
      rows = rows.first(DEFAULT_TOP_N) if requested_ids.nil?

      report.total = total_current
      report.data = rows
    end

    private

    def format_share_change(change)
      return "0%" if change.zero?
      sign = change.positive? ? "+" : ""
      "#{sign}#{change}%"
    end

    def period_data(period_start, period_end, requested_ids, secure_category_ids)
      builder = DB.build <<~SQL
        SELECT
          c.id,
          c.name,
          c.color,
          c.slug,
          COALESCE(t.topics, 0) AS topics,
          COALESCE(p.posts, 0) AS posts,
          COALESCE(v.page_views, 0) AS page_views
        FROM categories c
        LEFT JOIN (
          SELECT category_id, COUNT(*) AS topics
          FROM topics
          WHERE created_at >= :period_start
            AND created_at <= :period_end
            AND deleted_at IS NULL
            AND archetype = 'regular'
          GROUP BY category_id
        ) t ON t.category_id = c.id
        LEFT JOIN (
          SELECT topics.category_id, COUNT(*) AS posts
          FROM posts
          INNER JOIN topics ON topics.id = posts.topic_id
          WHERE posts.created_at >= :period_start
            AND posts.created_at <= :period_end
            AND posts.deleted_at IS NULL
            AND posts.post_type = :regular_post_type
            AND topics.deleted_at IS NULL
            AND topics.archetype = 'regular'
          GROUP BY topics.category_id
        ) p ON p.category_id = c.id
        LEFT JOIN (
          SELECT topics.category_id,
            COALESCE(SUM(tvs.anonymous_views + tvs.logged_in_views), 0) AS page_views
          FROM topic_view_stats tvs
          INNER JOIN topics ON topics.id = tvs.topic_id
          WHERE tvs.viewed_at >= :period_start
            AND tvs.viewed_at <= :period_end
            AND topics.deleted_at IS NULL
            AND topics.archetype = 'regular'
          GROUP BY topics.category_id
        ) v ON v.category_id = c.id
        /*where*/
      SQL

      builder.where(
        "(COALESCE(t.topics, 0) + COALESCE(p.posts, 0) + COALESCE(v.page_views, 0)) > 0",
      )

      if requested_ids.present?
        builder.where("c.id IN (:requested_ids)", requested_ids: requested_ids)
      end

      builder.secure_category(secure_category_ids) unless secure_category_ids.nil?

      result = {}
      builder
        .query(
          period_start: period_start,
          period_end: period_end,
          regular_post_type: Post.types[:regular],
        )
        .each do |row|
          result[row.id] = {
            name: row.name,
            color: row.color,
            slug: row.slug,
            topics: row.topics,
            posts: row.posts,
            page_views: row.page_views,
          }
        end
      result
    end
  end
end
