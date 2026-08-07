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

      current_period, prior_period =
        period_data(
          report.prev_start_date,
          report.start_date,
          report.end_date,
          requested_ids,
          secure_category_ids,
        )

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

    def period_data(prev_start, current_start, current_end, requested_ids, secure_category_ids)
      current_period = {}
      prior_period = {}

      CategoryActivityDailyRollup
        .period_totals(
          prev_start: prev_start.to_date,
          current_start: current_start.to_date,
          current_end: current_end.to_date,
          category_ids: requested_ids,
          secure_category_ids: secure_category_ids,
        )
        .each do |row|
          if row.topics_current + row.posts_current + row.page_views_current > 0
            current_period[row.id] = {
              name: row.name,
              color: row.color,
              slug: row.slug,
              topics: row.topics_current,
              posts: row.posts_current,
              page_views: row.page_views_current,
            }
          end

          if row.topics_prior + row.posts_prior + row.page_views_prior > 0
            prior_period[row.id] = {
              topics: row.topics_prior,
              posts: row.posts_prior,
              page_views: row.page_views_prior,
            }
          end
        end

      [current_period, prior_period]
    end
  end
end
